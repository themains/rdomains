context("Get dmoz Cat")

test_that("dmoz cat", {
  # Downloads an 80 MB archive: CRAN forbids that, and it fails offline.
  skip_on_cran()
  skip_if_offline()

  # Use temporary directory to avoid leaving large files
  temp_dir <- tempdir()
  get_dmoz_data(outdir = temp_dir, overwrite = TRUE)

  # Test with the downloaded data
  data_file <- file.path(temp_dir, "dmoz_domain_category.csv")
  reset_vintage_warnings()
  expect_warning(
    report <- dmoz_cat("http://www.google.com", use_file = data_file),
    "no longer published"
  )

  expect_that(report, is_a("data.frame"))
  expect_equal(report$source_last_published, "2017-03")

  # Clean up
  if (file.exists(data_file)) {
    unlink(data_file)
  }
})

test_that("get_dmoz_data writes to outdir, not a hidden file beside it", {
  # paste0(outdir, "name") produced ".dmoz_domain_category.csv" for the documented
  # default outdir = ".", which dmoz_cat() would then fail to find.
  temp_dir <- tempdir()
  expected <- file.path(temp_dir, "dmoz_domain_category.csv")
  writeLines("example.com,Shopping", expected)
  on.exit(unlink(expected), add = TRUE)

  # With the path built correctly, the existing-file guard fires.
  expect_error(
    get_dmoz_data(outdir = temp_dir, overwrite = FALSE),
    "already exists"
  )
})
