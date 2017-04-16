context("Get shalla Cat")

test_that("shallalist cat", {

  get_shalla_data()
  report <- shalla_cat("http://www.google.com")
  expect_that(report, is_a("data.frame"))
})
