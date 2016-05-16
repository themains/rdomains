context("Get shalla Cat")

test_that("shallalist cat", {

    report <- shalla_cat("http://www.google.com")
  	expect_that(report, is_a("data.frame"))
})

