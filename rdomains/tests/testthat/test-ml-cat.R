context("Get Name Suffix Cat")

test_that("ML cat", {

    report <- name_suffix_cat("http://www.google.com")
  	expect_that(report, is_a("data.frame"))
})

