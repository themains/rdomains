test_that("openai cat validates input", {
  expect_error(openai_cat(), "must not be NULL")

  # Temporarily unset API key to test error handling
  old_key <- Sys.getenv("OPENAI_API_KEY")
  Sys.unsetenv("OPENAI_API_KEY")
  expect_error(openai_cat("google.com"), "API key not found")
  # Restore the key
  if (old_key != "") Sys.setenv(OPENAI_API_KEY = old_key)
})

test_that("openai cat returns correct structure", {
  skip_if(identical(Sys.getenv("OPENAI_API_KEY"), ""), "OPENAI_API_KEY not set")

  result <- openai_cat("google.com")
  expect_s3_class(result, "data.frame")
  expect_named(result, c("domain_name", "openai_category"))
  expect_equal(nrow(result), 1)
  expect_equal(result$domain_name[1], "google.com")
})

test_that("openai cat handles multiple domains", {
  skip_if(identical(Sys.getenv("OPENAI_API_KEY"), ""), "OPENAI_API_KEY not set")

  domains <- c("google.com", "facebook.com")
  result <- openai_cat(domains)
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2)
  expect_equal(result$domain_name, domains)
})

test_that("openai cat preprocesses domains correctly", {
  skip_if(identical(Sys.getenv("OPENAI_API_KEY"), ""), "OPENAI_API_KEY not set")

  result <- openai_cat("http://www.google.com")
  expect_equal(result$domain_name[1], "google.com")
})

test_that("openai cat accepts custom categories", {
  skip_if(identical(Sys.getenv("OPENAI_API_KEY"), ""), "OPENAI_API_KEY not set")

  custom_cats <- c("search", "social", "other")
  result <- openai_cat("google.com", categories = custom_cats)
  expect_s3_class(result, "data.frame")
  # Category should be one of the custom categories or NA
  expect_true(is.na(result$openai_category[1]) || result$openai_category[1] %in% custom_cats)
})
