test_that("robots restrictions apply to the requested path and redirect destination", {
  skip_if_not_installed("webfakes")
  app <- webfakes::new_app()
  app$locals$hits <- 0L
  app$get("/robots.txt", function(req, res) {
    res$send("User-agent: *\nDisallow: /private\n")
  })
  app$get("/private", function(req, res) {
    res$app$locals$hits <- res$app$locals$hits + 1L
    res$set_header("Content-Type", "text/html")$send("<html>private</html>")
  })
  app$get("/start", function(req, res) {
    res$set_status(302L)$set_header("Location", "/private")$send("")
  })
  app$get("/hits", function(req, res) res$send(as.character(res$app$locals$hits)))
  srv <- webfakes::new_app_process(app)
  withr::defer(srv$stop())
  for (path in c("/private", "/start")) {
    out <- collect_content(srv$url(path),
      allow_hosts = "127.0.0.1", delay = 0,
      cache_dir = withr::local_tempdir(), archive_fallback = FALSE
    )
    expect_equal(out$error_code, "robots_blocked")
    expect_false(out$robots_allowed)
  }
  hits <- httr2::request(srv$url("/hits")) |>
    httr2::req_perform() |>
    httr2::resp_body_string()
  expect_equal(hits, "0")
})

test_that("robots redirects cannot bypass address guards", {
  skip_if_not_installed("webfakes")
  app <- webfakes::new_app()
  app$get("/robots.txt", function(req, res) {
    res$set_status(302L)$set_header("Location", "http://10.0.0.1/robots.txt")$send("")
  })
  srv <- webfakes::new_app_process(app)
  withr::defer(srv$stop())
  rules <- robots_for_origin(sub("/$", "", srv$url()), allow_hosts = "127.0.0.1")
  expect_false(robots_path_allowed(rules$rules, "/"))
})

test_that("crawler validates numeric boundaries before network requests", {
  for (name in c(
    "delay", "timeout", "max_bytes", "max_crawl_delay", "max_redirects",
    "cache_ttl", "cache_max_size"
  )) {
    for (value in list(-1, NA_real_, Inf, NaN, numeric(), c(1, 2))) {
      args <- c(list(domains = "example.com"), stats::setNames(list(value), name))
      expect_error(do.call(collect_content, args), name)
    }
  }
  expect_error(collect_content("example.com", max_redirects = 0.5), "max_redirects")
  expect_error(collect_content("example.com", timeout = 0), "timeout")
  for (value in c("20200230", "20201301", "2020", "2020-01-01")) {
    expect_error(collect_content("example.com", archive_date = value), "archive_date")
  }
})

test_that("a robots redirect never sends an HTTP request to a rejected destination", {
  urls <- character()
  local_mocked_bindings(
    check_url = function(url, ...) {
      if (grepl("rejected", url)) "private_address" else NULL
    },
    req_perform = function(req) {
      urls <<- c(urls, req$url)
      if (grepl("rejected", req$url)) {
        return(httr2::response(status_code = 200, body = charToRaw("User-agent: *\nAllow: /")))
      }
      httr2::response(status_code = 302,
                      headers = list(location = "https://rejected.example/robots.txt"))
    }
  )
  rules <- robots_for_origin("https://redirect-test.example")
  expect_false(robots_path_allowed(rules$rules, "/"))
  expect_equal(urls, "https://redirect-test.example/robots.txt")
})
