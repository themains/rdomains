test_that("not_news returns the documented column names", {
  res <- news_url_signals(c("http://www.bbc.com/sport", "http://x.example/politics"))
  expect_equal(names(res), c("input_id", "input", "soft_news", "hard_news"))
  expect_equal(res$input, c("http://www.bbc.com/sport", "http://x.example/politics"))
  expect_equal(res$soft_news, c(TRUE, FALSE))
  expect_equal(res$hard_news, c(FALSE, TRUE))
})

test_that("not_news validates its input", {
  expect_error(news_url_signals(NULL), "must not be NULL")
  expect_error(news_url_signals(""), "contains empty strings")
})
