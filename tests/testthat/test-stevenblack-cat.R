context("Steven Black Host List Classification")

test_that("stevenblack_cat returns expected data structure", {
  # Test with minimal mock data
  mock_hosts <- c(
    "# This is a test hosts file",
    "127.0.0.1 localhost",
    "0.0.0.0 doubleclick.net",
    "0.0.0.0 googleadservices.com",
    "127.0.0.1 malware-example.com"
  )
  
  # Create temporary hosts file
  temp_hosts <- tempfile(fileext = ".txt")
  writeLines(mock_hosts, temp_hosts)
  
  # Test function
  result <- stevenblack_cat(c("google.com", "doubleclick.net"), use_file = temp_hosts)
  
  # Clean up
  unlink(temp_hosts)
  
  # Check structure
  expect_is(result, "data.frame")
  expect_equal(ncol(result), 2)
  expect_equal(names(result), c("domain", "stevenblack"))
  expect_equal(nrow(result), 2)
  
  # Check classifications
  expect_equal(result$stevenblack[1], "safe")  # google.com not in blocklist
  expect_equal(result$stevenblack[2], "ads")   # doubleclick.net classified as ads
})

test_that("stevenblack_cat handles domain cleaning", {
  mock_hosts <- c("0.0.0.0 example.com")
  temp_hosts <- tempfile(fileext = ".txt")
  writeLines(mock_hosts, temp_hosts)
  
  # Test with various domain formats
  domains <- c(
    "http://example.com",
    "https://www.example.com",
    "example.com/path"
  )
  
  result <- stevenblack_cat(domains, use_file = temp_hosts)
  unlink(temp_hosts)
  
  # All should be classified as blocked since they resolve to example.com
  expect_equal(sum(result$stevenblack == "blocked"), 3)
})

test_that("stevenblack_cat handles errors appropriately", {
  # Test with non-existent file
  expect_error(
    stevenblack_cat("test.com", use_file = "nonexistent.txt"),
    "File does not exist"
  )

  # Test with no domain
  expect_error(
    stevenblack_cat(NULL),
    "must not be NULL"
  )
})

test_that("get_stevenblack_data creates file", {
  skip_if_offline()
  
  temp_dir <- tempdir()
  
  # Test download (this might be slow, so we'll skip on CRAN)
  skip_on_cran()
  
  # Download base variant
  result_file <- get_stevenblack_data(outdir = temp_dir, variant = "base", overwrite = TRUE)
  
  expect_true(file.exists(result_file))
  expect_true(file.size(result_file) > 1000)  # Should be a substantial file
  
  # Clean up
  unlink(result_file)
})

test_that("get_stevenblack_data validates variants", {
  expect_error(
    get_stevenblack_data(variant = "invalid"),
    "Invalid variant"
  )
})

test_that("get_stevenblack_data respects overwrite parameter", {
  temp_dir <- tempdir()
  test_file <- file.path(temp_dir, "stevenblack_hosts_base.txt")
  
  # Create a dummy file
  writeLines("test", test_file)
  
  # Should error without overwrite
  expect_error(
    get_stevenblack_data(outdir = temp_dir, overwrite = FALSE),
    "File already exists"
  )
  
  # Clean up
  unlink(test_file)
})