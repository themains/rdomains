test_that("Adult ML1 cat", {
  report <- adult_ml1_cat("http://www.google.com")
  expect_s3_class(report, "data.frame")
})

test_that("adult_ml1_cat validates input", {
  expect_error(adult_ml1_cat(NULL), "must not be NULL")
  expect_error(adult_ml1_cat(""), "contains empty strings")
  expect_error(adult_ml1_cat(123), "character")
})
