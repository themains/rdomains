test_that("not_news returns the documented column names", {
  res <- not_news(c("http://www.bbc.com/sport", "http://x.example/politics"))
  expect_equal(names(res), c("url", "not_news", "news"))
  expect_equal(res$url, c("http://www.bbc.com/sport", "http://x.example/politics"))
  expect_equal(res$not_news, c(TRUE, FALSE))
  expect_equal(res$news, c(FALSE, TRUE))
})

test_that("not_news validates its input", {
  expect_error(not_news(NULL), "must not be NULL")
  expect_error(not_news(""), "contains empty strings")
})
