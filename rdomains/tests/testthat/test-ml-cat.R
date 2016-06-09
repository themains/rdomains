context("Get Name Suffix Cat")

test_that("Adult ML1 cat", {

    report <- adult_ml1_cat("http://www.google.com")
  	expect_that(report, is_a("data.frame"))
})

