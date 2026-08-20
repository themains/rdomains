test_that("claude cat validates input", {
  expect_error(claude_cat(), "must not be NULL")

  # Temporarily unset API keys to test error handling
  old_key1 <- Sys.getenv("ANTHROPIC_API_KEY")
  old_key2 <- Sys.getenv("CLAUDE_API_KEY")
  Sys.unsetenv("ANTHROPIC_API_KEY")
  Sys.unsetenv("CLAUDE_API_KEY")
  expect_error(claude_cat("google.com"), "API key not found")
  # Restore the keys
  if (old_key1 != "") Sys.setenv(ANTHROPIC_API_KEY = old_key1)
  if (old_key2 != "") Sys.setenv(CLAUDE_API_KEY = old_key2)
})

test_that("claude cat returns correct structure", {
  skip_if(
    identical(Sys.getenv("ANTHROPIC_API_KEY"), "") && identical(Sys.getenv("CLAUDE_API_KEY"), ""),
    "ANTHROPIC_API_KEY or CLAUDE_API_KEY not set"
  )

  result <- claude_cat("google.com")
  expect_s3_class(result, "data.frame")
  expect_named(result, c("domain_name", "claude_category"))
  expect_equal(nrow(result), 1)
  expect_equal(result$domain_name[1], "google.com")
})

test_that("claude cat handles multiple domains", {
  skip_if(
    identical(Sys.getenv("ANTHROPIC_API_KEY"), "") && identical(Sys.getenv("CLAUDE_API_KEY"), ""),
    "ANTHROPIC_API_KEY or CLAUDE_API_KEY not set"
  )

  domains <- c("google.com", "facebook.com")
  result <- claude_cat(domains)
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2)
  expect_equal(result$domain_name, domains)
})

test_that("claude cat preprocesses domains correctly", {
  skip_if(
    identical(Sys.getenv("ANTHROPIC_API_KEY"), "") && identical(Sys.getenv("CLAUDE_API_KEY"), ""),
    "ANTHROPIC_API_KEY or CLAUDE_API_KEY not set"
  )

  result <- claude_cat("https://www.facebook.com")
  expect_equal(result$domain_name[1], "facebook.com")
})

test_that("claude cat accepts custom categories", {
  skip_if(
    identical(Sys.getenv("ANTHROPIC_API_KEY"), "") && identical(Sys.getenv("CLAUDE_API_KEY"), ""),
    "ANTHROPIC_API_KEY or CLAUDE_API_KEY not set"
  )

  custom_cats <- c("search", "social", "other")
  result <- claude_cat("facebook.com", categories = custom_cats)
  expect_s3_class(result, "data.frame")
  # Category should be one of the custom categories or NA
  expect_true(is.na(result$claude_category[1]) || result$claude_category[1] %in% custom_cats)
})
