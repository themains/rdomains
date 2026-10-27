test_that("a cache hit replays stored provenance rather than inventing it", {
  # The defect this cache exists to avoid: piedomains' collector synthesises a fresh
  # timestamp and fetch_success = TRUE on a hit, reporting a fetch that never happened at
  # a time it did not happen. A replayed row must say when it is really from.
  dir <- withr::local_tempdir()
  url <- "https://example.org"
  stored <- as.POSIXct("2020-01-02 03:04:05", tz = "UTC")

  cache_put(dir, url, "<html><body>hello world</body></html>", meta = list(
    requested_url = url, final_url = "https://example.org/", http_status = 200L,
    content_bytes = 42L, status = "ok", stage = "process", error_code = NULL,
    robots_allowed = TRUE,
    fetched_at = format(stored, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  ))

  hit <- cache_get(dir, url, ttl = 10 * 365 * 86400)
  expect_false(is.null(hit))
  # The exact bug: an ISO-8601 T/Z timestamp parsed without an explicit format silently
  # becomes midnight, so every hit would claim 00:00:00.
  expect_equal(format(hit$fetched_at, "%Y-%m-%d %H:%M:%S"), "2020-01-02 03:04:05")
  expect_equal(hit$meta$http_status, 200L)
  expect_equal(hit$meta$final_url, "https://example.org/")
})

test_that("entries expire", {
  dir <- withr::local_tempdir()
  cache_put(dir, "https://a.com", "<html>x</html>", meta = list(
    status = "ok", stage = "process", http_status = 200L,
    final_url = "https://a.com", content_bytes = 14L,
    fetched_at = format(Sys.time() - 3600, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  ))
  expect_false(is.null(cache_get(dir, "https://a.com", ttl = 7200)))
  expect_null(cache_get(dir, "https://a.com", ttl = 60))
})

test_that("a corrupt sidecar is a miss, not an error", {
  # The cache must never be the reason a run fails.
  dir <- withr::local_tempdir()
  cache_put(dir, "https://a.com", "<html>x</html>",
    meta = list(fetched_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  )
  paths <- cache_paths(dir, cache_key("https://a.com"))
  writeLines("{not valid json", paths$meta)
  expect_null(suppressWarnings(cache_get(dir, "https://a.com", ttl = 86400)))
})

test_that("keys are per URL, not per domain", {
  # piedomains keys on the domain, so example.com/a and example.com/b collide.
  expect_false(identical(cache_key("https://a.com/x"), cache_key("https://a.com/y")))
  expect_identical(cache_key("https://A.com "), cache_key("https://a.com"))
})

test_that("cache_clear empties the cache and reports what it removed", {
  dir <- withr::local_tempdir()
  for (u in c("https://a.com", "https://b.com")) {
    cache_put(dir, u, "<html>x</html>",
      meta = list(fetched_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
    )
  }
  expect_equal(cache_clear(dir), 2L)
  expect_null(cache_get(dir, "https://a.com", ttl = 86400))
})

test_that("rdomains_cache_dir does not create anything", {
  # CRAN forbids writing to a user's home space without consent, so persistence is opt-in.
  d <- rdomains_cache_dir()
  expect_type(d, "character")
  expect_false(dir.exists(file.path(d, "v1")))
})


test_that("cache budget includes metadata and a completed compressed file", {
  dir <- withr::local_tempdir()
  meta <- list(
    fetched_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    extra = paste(rep("metadata", 50), collapse = " ")
  )
  cache_put(dir, "https://example.com", "body", meta, max_size = 100)
  expect_null(cache_get(dir, "https://example.com", ttl = 60))
})

test_that("valid JSON with an invalid cache timestamp is a cache miss", {
  dir <- withr::local_tempdir()
  url <- "https://example.com"
  cache_put(dir, url, "body", list(fetched_at = "2026-10-26T00:00:00Z"))
  paths <- cache_paths(dir, cache_key(url))
  for (body in c(
    "1", "null", "[]", '{"fetched_at":[]}',
    '{"fetched_at":["2026-10-26T00:00:00Z","2026-10-25T00:00:00Z"]}'
  )) {
    writeLines(body, paths$meta)
    expect_null(cache_get(dir, url, ttl = 86400))
  }
})
