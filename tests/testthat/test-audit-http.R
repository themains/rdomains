test_that("robots restrictions apply to the requested path and redirect destination", {
  skip_if_not_installed("webfakes")
  skip_on_cran()
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
  skip_on_cran()
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
      httr2::response(
        status_code = 302,
        headers = list(location = "https://rejected.example/robots.txt")
      )
    }
  )
  rules <- robots_for_origin("https://redirect-test.example")
  expect_false(robots_path_allowed(rules$rules, "/"))
  expect_equal(urls, "https://redirect-test.example/robots.txt")
})

test_that("transient failures are retried for content and robots requests", {
  skip_if_not_installed("webfakes")
  skip_on_cran()
  for (retry_path in c("robots", "page")) {
    app <- webfakes::new_app()
    app$locals$retry_path <- retry_path
    app$locals$robots_hits <- 0L
    app$locals$page_hits <- 0L
    app$get("/robots.txt", function(req, res) {
      res$app$locals$robots_hits <- res$app$locals$robots_hits + 1L
      if (res$app$locals$retry_path == "robots" && res$app$locals$robots_hits == 1L) {
        return(res$set_status(503L)$set_header("Retry-After", "0")$send("Unavailable"))
      }
      res$send("User-agent: *\nAllow: /\n")
    })
    app$get("/page", function(req, res) {
      res$app$locals$page_hits <- res$app$locals$page_hits + 1L
      if (res$app$locals$retry_path == "page" && res$app$locals$page_hits == 1L) {
        return(res$set_status(503L)$set_header("Retry-After", "0")$send("Unavailable"))
      }
      text <- paste(rep("Journalism reports local elections and government policy.", 20),
        collapse = " "
      )
      res$set_header("Content-Type", "text/html")$send(paste0("<html><p>", text, "</p></html>"))
    })
    app$get("/counts", function(req, res) {
      res$send(paste(res$app$locals$robots_hits, res$app$locals$page_hits))
    })
    srv <- webfakes::new_app_process(app)
    withr::defer(srv$stop())
    result <- collect_content(srv$url("/page"),
      allow_hosts = "127.0.0.1", delay = 0,
      cache_dir = withr::local_tempdir(), archive_fallback = FALSE
    )
    expect_equal(result$status, "ok")
    expect_equal(result$http_status, 200L)
    counts <- httr2::request(srv$url("/counts")) |>
      httr2::req_perform() |>
      httr2::resp_body_string()
    expect_equal(counts, if (retry_path == "robots") "2 1" else "1 2")
    srv$stop()
  }
})

test_that("an empty redirect location does not create a self-loop", {
  skip_if_not_installed("webfakes")
  skip_on_cran()
  app <- webfakes::new_app()
  app$locals$hits <- 0L
  app$get("/empty-location", function(req, res) {
    res$app$locals$hits <- res$app$locals$hits + 1L
    res$set_status(302L)$set_header("Location", "")
    res$set_header("Content-Type", "text/html")$send("")
  })
  app$get("/hits", function(req, res) res$send(as.character(res$app$locals$hits)))
  srv <- webfakes::new_app_process(app)
  withr::defer(srv$stop())
  result <- collect_content(srv$url("/empty-location"),
    allow_hosts = "127.0.0.1",
    obey_robots = FALSE, delay = 0, max_redirects = 2,
    cache_dir = withr::local_tempdir(), archive_fallback = FALSE
  )
  expect_equal(result$error_code, "redirect_error")
  expect_equal(result$http_status, 302L)
  hits <- httr2::request(srv$url("/hits")) |>
    httr2::req_perform() |>
    httr2::resp_body_string()
  expect_equal(hits, "1")
})

test_that("guarded robots failures are cached for the configured TTL", {
  calls <- 0L
  local_mocked_bindings(guarded_get = function(...) {
    calls <<- calls + 1L
    list(response = NULL, error_code = "private_address")
  })
  origin <- "https://robots-failure-cache.example"
  first <- robots_for_origin(origin, ttl = 86400)
  second <- robots_for_origin(origin, ttl = 86400)
  expect_false(robots_path_allowed(first$rules, "/"))
  expect_false(robots_path_allowed(second$rules, "/"))
  expect_equal(calls, 1L)
  robots_for_origin(origin, ttl = 0)
  expect_equal(calls, 2L)
})
