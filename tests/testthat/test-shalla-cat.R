context("Get shalla Cat")

test_that("shallalist cat", {

  # Use temporary directory to avoid conflicts
  temp_dir <- tempdir()
  get_shalla_data(outdir = temp_dir, overwrite = TRUE)

  # Test with the downloaded data
  data_file <- file.path(temp_dir, "shalla_domain_category.csv")
  report <- shalla_cat("http://www.google.com", use_file = data_file)

  expect_that(report, is_a("data.frame"))

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
