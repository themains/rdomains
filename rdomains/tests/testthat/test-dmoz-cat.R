context("Get dmoz Cat")

test_that("dmoz cat", {

  get_dmoz_data()
  report <- dmoz_cat("http://www.google.com")
  expect_that(report, is_a("data.frame"))
})
