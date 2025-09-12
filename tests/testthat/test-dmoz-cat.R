context("Get dmoz Cat")

test_that("dmoz cat", {
  
  # Use temporary directory to avoid leaving large files
  temp_dir <- tempdir()
  get_dmoz_data(outdir = temp_dir, overwrite = TRUE)
  
  # Test with the downloaded data
  data_file <- file.path(temp_dir, "dmoz_domain_category.csv")
  report <- dmoz_cat("http://www.google.com", use_file = data_file)
  
  expect_that(report, is_a("data.frame"))
  
  # Clean up
  if (file.exists(data_file)) {
    unlink(data_file)
  }
})
