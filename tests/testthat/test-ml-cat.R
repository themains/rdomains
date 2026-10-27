test_that("Adult ML1 cat", {
  report <- adult_name_probability("http://www.google.com")
  expect_s3_class(report, "data.frame")
})

test_that("adult_name_probability validates input", {
  expect_error(adult_name_probability(NULL), "must not be NULL")
  expect_error(adult_name_probability(""), "contains empty strings")
  expect_error(adult_name_probability(123), "character")
})
