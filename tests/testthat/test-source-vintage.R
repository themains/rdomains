test_that("source_vintage lists every source", {
  v <- source_vintage()
  expect_s3_class(v, "data.frame")
  expect_setequal(v$key, c("shalla", "dmoz", "stevenblack", "uni"))
  expect_true(all(c("source", "last_published", "status", "note") %in% names(v)))
})

test_that("source_vintage names the two dead lists", {
  v <- source_vintage()
  dead <- v$key[v$status == "discontinued"]
  expect_setequal(dead, c("shalla", "dmoz"))
  expect_equal(source_vintage("dmoz")$last_published, "2017-03")
  expect_equal(source_vintage("shalla")$last_published, "2022-01")
})

test_that("source_vintage rejects an unknown source", {
  expect_error(source_vintage("curlie"), "Unknown source")
})

test_that("the staleness warning fires once per session, not once per call", {
  reset_vintage_warnings()
  expect_warning(warn_source_vintage("dmoz"), "no longer published")
  # Second call is silent: a warning on every lookup is one people learn to ignore.
  expect_silent(warn_source_vintage("dmoz"))
  expect_silent(warn_source_vintage("dmoz"))
})

test_that("maintained sources never warn", {
  reset_vintage_warnings()
  expect_silent(warn_source_vintage("stevenblack"))
  expect_silent(warn_source_vintage("uni"))
})

test_that("shalla_cat reports the vintage of the label it returns", {
  reset_vintage_warnings()
  tmp <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(
    data.frame(domains = c("example.com", "test.org"), category = c("shopping", "news")),
    tmp,
    row.names = FALSE
  )

  res <- suppressWarnings(shalla_cat("http://www.example.com", use_file = tmp))
  expect_equal(res$shalla_category, "shopping")
  expect_equal(res$source_last_published, "2022-01")
})

test_that("shalla_cat warns that Shallalist is no longer published", {
  reset_vintage_warnings()
  tmp <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(
    data.frame(domains = "example.com", category = "shopping"), tmp, row.names = FALSE
  )
  expect_warning(shalla_cat("example.com", use_file = tmp), "no longer published")
})

test_that("dmoz_cat reports its 2017 vintage", {
  reset_vintage_warnings()
  tmp <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("example.com,Shopping", "test.org,News"), tmp)

  res <- suppressWarnings(dmoz_cat("http://www.example.com", use_file = tmp))
  expect_equal(res$dmoz_category, "Shopping")
  expect_equal(res$source_last_published, "2017-03")
})

test_that("an unmatched domain still carries the source vintage", {
  reset_vintage_warnings()
  tmp <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(
    data.frame(domains = "example.com", category = "shopping"), tmp, row.names = FALSE
  )
  res <- suppressWarnings(shalla_cat("nowhere-at-all.invalid", use_file = tmp))
  expect_true(is.na(res$shalla_category))
  # The label is missing; the provenance of the list that failed to supply it is not.
  expect_equal(res$source_last_published, "2022-01")
})
