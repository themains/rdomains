release_html <- function() {
  text <- paste(rep("Independent reporting about markets and technology.", 50), collapse = " ")
  paste0("<html><body>", text, "</body></html>")
}

test_that("substantive articles about parking companies are content", {
  html <- sub("</body>", " Our reporting covers sedo.com and dan.com.</body>", release_html())
  expect_identical(page_signals(html)$page_state, "content")
  expect_identical(page_signals("<p>This domain is for sale at sedo.com</p>")$page_state, "parked")
})

test_that("archive requests preserve the exact resource", {
  requested <- NULL
  local_mocked_bindings(archive_fetch = function(domain, ...) {
    requested <<- domain
    list(error_code = "no_archive_snapshot", http_status = 200L)
  })
  input <- "https://example.com/News/story?id=7"
  collect_content(input, archive_date = "20200101")
  expect_identical(requested, input)
})

test_that("malformed cache records are misses and retain batch rows", {
  cache <- withr::local_tempdir()
  cache_put(cache, "https://example.com/a", release_html(), list(
    fetched_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    http_status = c(200L, 201L), status = "ok", stage = "process",
    final_url = "https://example.com/a", content_bytes = 500L
  ))
  local_mocked_bindings(guarded_get = function(...) {
    list(response = NULL, error_code = "dns_error", stage = "fetch", robots_allowed = NA)
  })
  result <- collect_content(c("https://example.com/a", "https://example.org/b"), cache_dir = cache)
  expect_equal(nrow(result), 2L)
  expect_equal(result$error_code, rep("dns_error", 2))
  expect_false(any(result$from_cache))
})

test_that("archive outages retain a transient reason", {
  local_mocked_bindings(req_perform = function(...) {
    httr2::response(status_code = 503L, body = charToRaw("unavailable"))
  })
  result <- collect_content("https://example.com/a", archive_date = "20200101")
  expect_identical(result$error_code, "archive_unavailable")
  expect_true(result$retryable)
  expect_identical(result$http_status, 503L)
})

test_that("robots transport failures are distinct from disallow", {
  local_mocked_bindings(
    check_url = function(...) NULL,
    req_perform = function(...) stop("operation timed out")
  )
  result <- collect_content("https://robots-timeout.example/a", cache_dir = withr::local_tempdir())
  expect_identical(result$error_code, "robots_unavailable")
  expect_true(result$retryable)
})

test_that("not found pages are not marked transient", {
  local_mocked_bindings(guarded_get = function(...) {
    list(
      response = httr2::response(
        status_code = 404L, headers = list("content-type" = "text/html"),
        body = charToRaw(release_html()), url = "https://example.com/a"
      ),
      robots_allowed = TRUE
    )
  })
  result <- collect_content("https://example.com/a", cache_dir = withr::local_tempdir())
  expect_identical(result$error_code, "http_not_found")
  expect_false(result$retryable)
})

test_that("unresolved redirects are not successful pages", {
  local_mocked_bindings(guarded_get = function(...) {
    list(
      response = httr2::response(
        status_code = 302L, headers = list("content-type" = "text/html"),
        body = charToRaw(release_html()), url = "https://example.com/a"
      ),
      robots_allowed = TRUE
    )
  })
  result <- collect_content("https://example.com/a", cache_dir = withr::local_tempdir())
  expect_identical(result$status, "failed")
  expect_identical(result$error_code, "redirect_error")
  expect_false(result$retryable)
})

test_that("archive fallback reports capture processing and service failures", {
  requested <- NULL
  local_mocked_bindings(
    guarded_get = function(...) {
      list(
        response = httr2::response(
          status_code = 403L,
          headers = list("content-type" = "text/html"),
          body = charToRaw("<html><title>Just a moment...</title><body>cloudflare</body></html>"),
          url = "https://example.com/story?id=7"
        ), robots_allowed = TRUE
      )
    },
    archive_fetch = function(domain, ...) {
      requested <<- domain
      list(error_code = "archive_unavailable", http_status = 503L)
    }
  )
  input <- "https://example.com/story?id=7"
  result <- collect_content(input, archive_fallback = TRUE, cache_dir = withr::local_tempdir())
  expect_identical(requested, input)
  expect_identical(result$error_code, "archive_unavailable")
  expect_identical(result$http_status, 503L)
  expect_true(result$retryable)
  local_mocked_bindings(archive_fetch = function(...) {
    list(
      html = "<html><body>short</body></html>", timestamp = "20200101000000",
      url = "https://web.archive.org/web/20200101000000id_/https://example.com/story?id=7"
    )
  })
  result <- collect_content(input, archive_fallback = TRUE, cache_dir = withr::local_tempdir())
  expect_identical(result$error_code, "thin_content")
  expect_identical(result$archive_error_code, "thin_content")
  expect_identical(result$source, "archive")
})

test_that("robots outages expire quickly but explicit rules remain cached", {
  calls <- 0L
  local_mocked_bindings(guarded_get = function(...) {
    calls <<- calls + 1L
    list(response = NULL)
  })
  origin <- "https://robots-expiry.example"
  failed <- robots_for_origin(origin)
  expect_equal(failed$ttl, 60)
  key <- paste("robots", origin, "rdomains", rdomains_user_agent(), "", sep = ":")
  withr::defer(rm(list = key, envir = .rdomains_env))
  .rdomains_env[[key]]$fetched_at <- Sys.time() - 61
  local_mocked_bindings(guarded_get = function(...) {
    calls <<- calls + 1L
    list(response = httr2::response(
      status_code = 200L,
      body = charToRaw("User-agent: *\nDisallow: /private")
    ))
  })
  rules <- robots_for_origin(origin)
  expect_equal(calls, 2L)
  expect_false(robots_path_allowed(rules$rules, "/private"))
  .rdomains_env[[key]]$fetched_at <- Sys.time() - 61
  robots_for_origin(origin)
  expect_equal(calls, 2L)
})

test_that("malformed CDX responses differ from a valid empty history", {
  body <- "invalid JSON"
  local_mocked_bindings(req_perform = function(...) {
    httr2::response(status_code = 200L, body = charToRaw(body))
  })
  expect_identical(archive_snapshot("example.com")$error_code, "archive_invalid_response")
  body <- '[["wrong", "header"]]'
  expect_identical(archive_snapshot("example.com")$error_code, "archive_invalid_response")
  body <- '[["timestamp", "original"]]'
  expect_identical(archive_snapshot("example.com")$error_code, "no_archive_snapshot")
})

test_that("live, cache and archive apply the same content rules", {
  html <- release_html()
  local_mocked_bindings(
    guarded_get = function(...) {
      list(
        response = httr2::response(
          status_code = 200L,
          headers = list("content-type" = "text/html"),
          body = charToRaw(html), url = "https://example.com/article"
        ), robots_allowed = TRUE
      )
    },
    archive_fetch = function(...) {
      list(
        html = html, timestamp = "20200101000000",
        url = "https://web.archive.org/web/20200101000000id_/https://example.com/article"
      )
    }
  )
  cache <- withr::local_tempdir()
  live <- collect_content("https://example.com/article", cache_dir = cache)
  cached <- collect_content("https://example.com/article", cache_dir = cache)
  archived <- collect_content("https://example.com/article", archive_date = "20200101")
  fields <- c("status", "stage", "error_code", "retryable", "text", "page_state", "html")
  expect_identical(live[fields], cached[fields])
  expect_identical(live[fields], archived[fields])
  expect_true(cached$from_cache)
  expect_equal(as.numeric(live$fetched_at), as.numeric(cached$fetched_at), tolerance = 1)
})

test_that("archive fetch preserves permanent resource guard failures", {
  code <- "content_too_large"
  local_mocked_bindings(
    archive_snapshot = function(...) {
      list(
        url = "https://web.archive.org/web/20200101000000id_/https://example.com",
        timestamp = "20200101000000"
      )
    },
    guarded_get = function(...) list(response = NULL, error_code = code)
  )
  for (reason in c("content_too_large", "private_address", "too_many_redirects")) {
    code <- reason
    result <- collect_content("example.com", archive_date = "20200101")
    expect_identical(result$error_code, reason)
    expect_false(result$retryable)
  }
})
