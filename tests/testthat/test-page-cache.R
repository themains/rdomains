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
    fetched_at = format(Sys.time() - 3600, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  ))
  expect_false(is.null(cache_get(dir, "https://a.com", ttl = 7200)))
  expect_null(cache_get(dir, "https://a.com", ttl = 60))
})

test_that("a corrupt sidecar is a miss, not an error", {
  # The cache must never be the reason a run fails.
  dir <- withr::local_tempdir()
  cache_put(dir, "https://a.com", "<html>x</html>",
            meta = list(fetched_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")))
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
              meta = list(fetched_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")))
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
