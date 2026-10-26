test_that("lookups parse URL hosts independently of ports queries and fragments", {
  values <- c(
    "https://WWW.Example.COM:443/a?x=1#part", "example.com?x=1",
    "https://example.com#part", "example.com:443/", "example.com."
  )
  expect_equal(clean_domains(values), rep("example.com", length(values)))
  expect_equal(
    request_url("example.com/News?X=A"),
    "https://example.com/News?X=A"
  )
})

test_that("cache keys preserve resource case and query values", {
  expect_false(identical(cache_key("https://a.com/News"), cache_key("https://a.com/news")))
  expect_false(identical(cache_key("https://a.com/?q=A"), cache_key("https://a.com/?q=a")))
  expect_identical(cache_key("https://A.COM/News"), cache_key("https://a.com/News"))
})

test_that("local lookup files do not invent source publication dates", {
  path <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(data.frame(domain = "example.com", category = "news", usage = "black"),
    path,
    row.names = FALSE
  )
  expect_true(is.na(ut1_cat("example.com", path)$source_last_published))
  hosts <- withr::local_tempfile()
  writeLines("0.0.0.0 example.com", hosts)
  expect_true(is.na(stevenblack_cat("example.com", hosts)$source_last_published))
  expect_equal(stevenblack_cat("notlisted.com", hosts)$stevenblack, "not_listed")
})

test_that("CDX headers alone are not captures and historical selection looks backward", {
  queries <- list()
  local_mocked_bindings(req_perform = function(req) {
    queries[[length(queries) + 1L]] <<- httr2::url_parse(req$url)$query
    httr2::response(status_code = 200, body = charToRaw('[["timestamp","original"]]'))
  })
  expect_null(archive_snapshot("example.com"))
  expect_null(archive_snapshot("example.com", target = "20200102"))
  expect_equal(queries[[2]]$to, "20200102")
  expect_equal(queries[[2]]$limit, "-1")
  expect_null(queries[[2]]$from)
})

test_that("explicit VirusTotal credentials override and restore session credentials", {
  withr::local_envvar(c(VirustotalToken = "old-key", VIRUSTOTAL_API_KEY = "old-key"))
  used <- NULL
  local_mocked_bindings(domain_report = function(domain) {
    used <<- Sys.getenv("VirustotalToken")
    list(data = list(attributes = list(categories = list(vendor = "news"))))
  })
  res <- virustotal_cat("example.com", api_key = "new-key")
  expect_equal(res$vendor, "news")
  expect_equal(used, "new-key")
  expect_equal(Sys.getenv("VirustotalToken"), "old-key")
  expect_equal(Sys.getenv("VIRUSTOTAL_API_KEY"), "old-key")
})

test_that("LLMs reject responses outside the requested vocabulary", {
  local_mocked_bindings(req_perform = function(req) {
    body <- if (grepl("openai", req$url)) {
      '{"choices":[{"message":{"content":"wrong"},"finish_reason":"stop"}]}'
    } else {
      '{"content":[{"type":"text","text":"wrong"}],"stop_reason":"end_turn"}'
    }
    httr2::response(status_code = 200, body = charToRaw(body))
  })
  expect_warning(a <- openai_cat("a.com", "fixture", c("news", "sports")), "categor")
  expect_warning(b <- claude_cat("a.com", "fixture", c("news", "sports")), "categor")
  expect_true(is.na(a$openai_category))
  expect_true(is.na(b$claude_category))
})


test_that("CDX returns only valid captures no later than the requested day", {
  reply <- '[["timestamp","original"],["20200101120000","https://example.com/"]]'
  local_mocked_bindings(req_perform = function(req) {
    httr2::response(status_code = 200, body = charToRaw(reply))
  })
  capture <- archive_snapshot("example.com", target = "20200102")
  expect_equal(capture$timestamp, "20200101120000")
  expect_match(capture$url, "20200101120000id_/https://example.com/", fixed = TRUE)
  expect_null(archive_snapshot("example.com", target = "20190101"))
  reply <- '[["timestamp","original"],["invalid","https://example.com/"]]'
  expect_null(archive_snapshot("example.com"))
})
