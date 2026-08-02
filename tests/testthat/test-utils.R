test_that("clean_domains removes common prefixes and paths", {
  expect_equal(rdomains:::clean_domains("  google.com  "), "google.com")
  expect_equal(rdomains:::clean_domains("http://www.google.com"), "google.com")
  expect_equal(rdomains:::clean_domains("https://google.com"), "google.com")
  expect_equal(rdomains:::clean_domains("www.google.com"), "google.com")
  expect_equal(rdomains:::clean_domains("https://google.com/path"), "google.com")
  expect_equal(rdomains:::clean_domains("http://www.google.com/path/to/page"), "google.com")
})

test_that("clean_domains handles multiple domains", {
  input <- c("http://www.google.com", "  facebook.com  ", "https://twitter.com/user")
  expected <- c("google.com", "facebook.com", "twitter.com")
  expect_equal(rdomains:::clean_domains(input), expected)
})

test_that("validate_domains catches NULL input", {
  expect_error(
    rdomains:::validate_domains(NULL),
    "must not be NULL"
  )
})

test_that("validate_domains catches empty strings", {
  expect_error(
    rdomains:::validate_domains(""),
    "contains empty strings"
  )
  expect_error(
    rdomains:::validate_domains(c("google.com", "", "facebook.com")),
    "contains empty strings"
  )
})

test_that("validate_domains catches non-character input", {
  expect_error(
    rdomains:::validate_domains(123),
    "character"
  )
  expect_error(
    rdomains:::validate_domains(list("google.com")),
    "character"
  )
})

test_that("validate_domains accepts valid input", {
  expect_silent(rdomains:::validate_domains("google.com"))
  expect_silent(rdomains:::validate_domains(c("google.com", "facebook.com")))
})

test_that("validate_data_file provides helpful errors for missing files", {
  expect_error(
    rdomains:::validate_data_file("nonexistent.csv", "default.csv", "get_data"),
    "File not found"
  )
})

test_that("validate_data_file works with NULL path and existing default", {
  temp_file <- tempfile(fileext = ".csv")
  writeLines("test", temp_file)

  result <- rdomains:::validate_data_file(NULL, temp_file, "get_data")
  expect_equal(result, temp_file)

  unlink(temp_file)
})

test_that("validate_data_file works with specified path", {
  temp_file <- tempfile(fileext = ".csv")
  writeLines("test", temp_file)

  result <- rdomains:::validate_data_file(temp_file, "default.csv", "get_data")
  expect_equal(result, temp_file)

  unlink(temp_file)
})

test_that("get_api_key retrieves from parameter", {
  key <- rdomains:::get_api_key("test_key", "ENV_VAR", "Service")
  expect_equal(key, "test_key")
})

test_that("get_api_key retrieves from environment", {
  Sys.setenv(TEST_API_KEY = "env_key")
  key <- rdomains:::get_api_key(NULL, "TEST_API_KEY", "Service")
  expect_equal(key, "env_key")
  Sys.unsetenv("TEST_API_KEY")
})

test_that("get_api_key errors when key not found", {
  Sys.unsetenv("MISSING_KEY")
  expect_error(
    rdomains:::get_api_key(NULL, "MISSING_KEY", "Service"),
    "API key not found"
  )
})

test_that("build_categorization_prompt creates valid prompt", {
  prompt <- rdomains:::build_categorization_prompt("google.com", c("tech", "social", "other"))
  expect_true(grepl("google.com", prompt))
  expect_true(grepl("tech", prompt))
  expect_true(grepl("social", prompt))
  expect_true(grepl("other", prompt))
})

test_that("apply_rate_limit sleeps appropriately", {
  start_time <- Sys.time()
  rdomains:::apply_rate_limit(1, 3, 0.1)
  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  expect_true(elapsed >= 0.1)
})

test_that("apply_rate_limit doesn't sleep on last iteration", {
  start_time <- Sys.time()
  rdomains:::apply_rate_limit(3, 3, 1.0)
  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  expect_true(elapsed < 0.5)
})
