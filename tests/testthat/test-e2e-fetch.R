# End-to-end tests against a real HTTP server.
#
# These are the tests that matter, because the guards worth having are exactly the ones a
# mock cannot check. Asserting "the code returned private_address" against a stubbed
# response only proves the stub was configured; serving an actual 302 to an actual private
# address and watching the fetcher refuse it proves the guard.
#
# webfakes runs a real server on a loopback port, so these are local-socket tests rather
# than network tests -- no skip_on_cran() needed, only skip_if_not_installed().

skip_if_not_installed("webfakes")

`%||%` <- function(x, y) if (is.null(x)) y else x

# One app serving every case the fetcher has to get right.
test_app <- function() {
  app <- webfakes::new_app()

  app$locals$hits <- 0L

  app$get("/page", function(req, res) {
    res$app$locals$hits <- (res$app$locals$hits %||% 0L) + 1L
    res$set_header("content-type", "text/html")$send(paste0(
      "<html><head><title>Real Page</title></head><body>",
      paste(rep("substantive page content about a real subject", 40), collapse = " "),
      "</body></html>"
    ))
  })
  app$get("/hits", function(req, res) {
    res$send(as.character(res$app$locals$hits %||% 0L))
  })

  # A redirect to a private address. The fetcher must refuse the hop.
  app$get("/evil", function(req, res) {
    res$set_status(302L)$set_header("location", "http://10.0.0.1/secret")$send("")
  })
  # A two-hop chain that ends somewhere legitimate.
  app$get("/hop1", function(req, res) {
    res$set_status(302L)$set_header("location", "/hop2")$send("")
  })
  app$get("/hop2", function(req, res) {
    res$set_status(302L)$set_header("location", "/page")$send("")
  })
  # An endless loop.
  app$get("/loop", function(req, res) {
    res$set_status(302L)$set_header("location", "/loop")$send("")
  })

  app$get("/huge", function(req, res) {
    res$set_header("content-type", "text/html")$send(strrep("x", 300000L))
  })
  app$get("/pdf", function(req, res) {
    res$set_header("content-type", "application/pdf")$send("%PDF-1.4 not html")
  })
  app$get("/boom", function(req, res) {
    res$set_status(500L)$set_header("content-type", "text/html")$send("<html>err</html>")
  })
  # A bot wall: 403 plus an interstitial body, which must reach page_signals().
  app$get("/walled", function(req, res) {
    res$set_status(403L)$set_header("content-type", "text/html")$send(
      "<html><head><title>Just a moment...</title></head><body>cf_chl_opt</body></html>"
    )
  })

  app$get("/robots.txt", function(req, res) {
    res$set_header("content-type", "text/plain")$send("User-agent: *\nDisallow: /\n")
  })
  app
}

local_server <- function(env = parent.frame()) {
  srv <- webfakes::new_app_process(test_app())
  withr::defer(srv$stop(), envir = env)
  srv
}

fetch <- function(srv, path, ...) {
  collect_content(
    srv$url(path),
    obey_robots = FALSE,
    allow_hosts = "127.0.0.1",
    cache_dir = withr::local_tempdir(.local_envir = parent.frame()),
    ...
  )
}

test_that("a real page is fetched, extracted and classified as content", {
  srv <- local_server()
  res <- fetch(srv, "/page")
  expect_equal(res$status, "ok")
  expect_equal(res$http_status, 200L)
  expect_equal(res$title, "Real Page")
  expect_equal(res$page_state, "content")
  expect_gt(res$n_tokens, 30)
})

test_that("a redirect to a private address is REFUSED", {
  # The defect this session found: check_url() ran once on the entry URL while curl
  # followed redirects itself, so a host redirecting to 10.0.0.1 or 169.254.169.254 would
  # have been fetched. The docstring claimed otherwise. This is the test that proves it.
  srv <- local_server()
  res <- fetch(srv, "/evil")

  expect_equal(res$status, "failed")
  expect_true(res$error_code %in% c("private_address", "invalid_domain"))
  # And critically: nothing from behind the redirect came back.
  expect_true(is.na(res$text))
})

test_that("a legitimate redirect chain is followed to the end", {
  srv <- local_server()
  res <- fetch(srv, "/hop1")
  expect_equal(res$status, "ok")
  expect_match(res$final_url, "/page", fixed = TRUE)
  expect_equal(res$title, "Real Page")
})

test_that("a redirect loop is bounded", {
  srv <- local_server()
  res <- fetch(srv, "/loop", max_redirects = 3)
  expect_equal(res$status, "failed")
  expect_equal(res$error_code, "too_many_redirects")
})

test_that("an oversized body is refused", {
  srv <- local_server()
  res <- fetch(srv, "/huge", max_bytes = 1000)
  expect_equal(res$status, "failed")
  expect_equal(res$error_code, "content_too_large")
})

test_that("a non-HTML content type is refused", {
  srv <- local_server()
  res <- fetch(srv, "/pdf")
  expect_equal(res$status, "failed")
  expect_equal(res$error_code, "content_type_rejected")
})

test_that("a server error is reported as retryable", {
  srv <- local_server()
  res <- fetch(srv, "/boom")
  expect_equal(res$status, "failed")
  expect_equal(res$error_code, "http_error")
  expect_true(res$retryable)
})

test_that("a bot wall is detected rather than classified as content", {
  # req_error(is_error = FALSE) exists so the 403 body reaches page_signals() instead of
  # throwing. Without it this comes back as an http_error and the interstitial is invisible.
  srv <- local_server()
  res <- fetch(srv, "/walled")
  expect_equal(res$error_code, "bot_blocked")
  expect_equal(res$block_vendor, "cloudflare")
  expect_false(res$retryable)
})

test_that("robots.txt Disallow is honoured", {
  srv <- local_server()
  res <- collect_content(
    srv$url("/page"),
    obey_robots = TRUE,
    allow_hosts = "127.0.0.1",
    cache_dir = withr::local_tempdir()
  )
  expect_equal(res$status, "failed")
  expect_equal(res$error_code, "robots_blocked")
  expect_false(res$robots_allowed)
})

test_that("the cache actually prevents a second request", {
  # The real test of caching. Asserting from_cache == TRUE is the code agreeing with
  # itself; counting the server's own hits is what would have caught the bug where
  # nothing was being cached at all.
  srv <- local_server()
  dir <- withr::local_tempdir()
  hits <- function() {
    as.integer(httr2::resp_body_string(
      httr2::req_perform(httr2::request(srv$url("/hits")))
    ))
  }

  before <- hits()
  a <- collect_content(srv$url("/page"), obey_robots = FALSE,
                       allow_hosts = "127.0.0.1", cache_dir = dir)
  after_first <- hits()
  b <- collect_content(srv$url("/page"), obey_robots = FALSE,
                       allow_hosts = "127.0.0.1", cache_dir = dir)
  after_second <- hits()

  expect_equal(after_first - before, 1L)
  expect_equal(after_second - after_first, 0L)   # the second fetch never reached the server
  expect_false(a$from_cache)
  expect_true(b$from_cache)
  expect_equal(a$text, b$text)
})

test_that("an http:// input is honoured rather than forced to https", {
  # Forcing https meant http-only hosts were unreachable, and made the package
  # untestable against a local server.
  srv <- local_server()
  expect_match(srv$url("/page"), "^http://")
  expect_equal(fetch(srv, "/page")$status, "ok")
})

test_that("a blocked page is recovered from the archive, with its vintage visible", {
  # The honest response to a bot wall: ask an archive that was allowed in, and say so.
  # allrecipes.com serves a 403 interstitial to us and has recent captures.
  skip_on_cran()
  skip_if_offline()

  res <- collect_content("allrecipes.com", obey_robots = FALSE,
                         cache_dir = withr::local_tempdir())
  skip_if(is.na(res$source) || res$source != "archive",
          "no recent archive capture available right now")

  expect_equal(res$status, "ok")
  expect_equal(res$source, "archive")
  # The vintage is never hidden: a recovered row says when the capture is from.
  expect_true(nzchar(res$snapshot_timestamp))
  expect_gt(res$n_tokens, 30)
})

test_that("a dead domain is not resurrected from the archive", {
  # Deliberate: recovering a domain that no longer resolves would answer "what was this"
  # while looking like "what is this" -- the exact staleness source_vintage() exists to
  # surface. Blocks are recoverable; dead domains are not.
  skip_on_cran()
  skip_if_offline()

  res <- collect_content("no-such-domain-xyzzy-99999.invalid", obey_robots = FALSE,
                         cache_dir = withr::local_tempdir())
  expect_equal(res$status, "failed")
  expect_equal(res$error_code, "dns_error")
  expect_equal(res$source, "live")
})

test_that("archive_date fetches a domain as it was, not as it is", {
  # The instrument for measuring whether a label has gone stale: classify a domain as of
  # a past date and set it against a live run.
  skip_on_cran()
  skip_if_offline()

  res <- collect_content("cnn.com", archive_date = "20200101",
                         cache_dir = withr::local_tempdir())
  skip_if(!identical(res$source, "archive"),
          "archive.org CDX did not answer (it rate-limits)")

  expect_equal(res$status, "ok")
  # The realised capture, not the date asked for -- they are rarely identical.
  expect_match(res$snapshot_timestamp, "^2020")
  expect_gt(res$n_tokens, 30)
})

test_that("a date with no capture is reported, not silently fetched live", {
  skip_on_cran()
  skip_if_offline()

  res <- collect_content("no-such-domain-xyzzy-99999.invalid", archive_date = "20200101",
                         cache_dir = withr::local_tempdir())
  expect_equal(res$status, "failed")
  expect_equal(res$error_code, "no_archive_snapshot")
  # Critically: it did not quietly fall back to a live fetch of a different thing.
  expect_equal(res$source, "archive")
})
