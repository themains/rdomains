# The JSON's `domains` field is a list column: one university may list several hosts.
# 281 of the list's 10,256 entries (2.7%) do. match() against a list column coerces it
# with as.character(), so a two-element entry becomes the string
# 'c("student.wab.edu.pl", "wab.edu.pl")' and can never be matched.
fake_uni_list <- function() {
  u <- data.frame(
    name = c("A Uni", "Wroclaw Akademia Biznesu"),
    country = c("Nowhere", "Poland"),
    stringsAsFactors = FALSE
  )
  u$domains <- list("a.edu", c("student.wab.edu.pl", "wab.edu.pl"))
  u
}

test_that("uni_cat matches universities that list more than one domain", {
  local_mocked_bindings(fromJSON = function(...) fake_uni_list())
  expect_equal(uni_cat("http://wab.edu.pl")$name, "Wroclaw Akademia Biznesu")
  expect_equal(uni_cat("student.wab.edu.pl")$name, "Wroclaw Akademia Biznesu")
})

test_that("uni_cat still matches single-domain universities and misses non-matches", {
  local_mocked_bindings(fromJSON = function(...) fake_uni_list())
  expect_equal(uni_cat("http://www.a.edu")$name, "A Uni")
  expect_true(is.na(uni_cat("google.com")$name))
})
