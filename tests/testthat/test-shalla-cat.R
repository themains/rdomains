test_that("shallalist cat", {
  # Downloads a real file: CRAN forbids that, and it fails offline.
  skip_on_cran()
  skip_if_offline()

  # Use temporary directory to avoid conflicts
  temp_dir <- tempdir()
  get_shalla_data(outdir = temp_dir, overwrite = TRUE)

  # Test with the downloaded data
  data_file <- file.path(temp_dir, "shalla_domain_category.csv")
  reset_vintage_warnings()
  expect_warning(
    report <- shalla_cat("http://www.google.com", use_file = data_file),
    "no longer published"
  )

  expect_s3_class(report, "data.frame")
  expect_equal(report$source_last_published, "2022-01")

  # Clean up
  if (file.exists(data_file)) {
    unlink(data_file)
  }
})

test_that("shalla_cat validates input", {
  expect_error(shalla_cat(NULL), "must not be NULL")
  expect_error(shalla_cat(""), "contains empty strings")
  expect_error(shalla_cat(123), "character")
})

test_that("shalla_cat provides helpful error for missing file", {
  expect_error(
    shalla_cat("google.com", use_file = "nonexistent.csv"),
    "File not found"
  )
})
