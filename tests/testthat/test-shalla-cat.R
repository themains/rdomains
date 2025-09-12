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
