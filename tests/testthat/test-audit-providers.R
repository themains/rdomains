test_that("current provider requests produce validated categories", {
  requests <- list()
  local_mocked_bindings(req_perform = function(req) {
    requests[[length(requests) + 1L]] <<- req$body$data
    reply <- if (grepl("openai", req$url)) {
      '{"choices":[{"message":{"content":" news "},"finish_reason":"stop"}]}'
    } else {
      '{"content":[{"type":"text","text":"news"}],"stop_reason":"end_turn"}'
    }
    httr2::response(status_code = 200, body = charToRaw(reply))
  })
  expect_equal(openai_cat("a.com", "fixture", c("news", "sports"))$category, "news")
  expect_equal(claude_cat("a.com", "fixture", c("news", "sports"))$category, "news")
  expect_equal(requests[[1]]$model, "gpt-6-luna")
  expect_equal(requests[[1]]$reasoning_effort, "none")
  expect_equal(requests[[1]]$max_completion_tokens, 256)
  expect_null(requests[[1]]$temperature)
  expect_equal(requests[[2]]$model, "claude-haiku-5-5")
  expect_null(requests[[2]]$temperature)
})

test_that("provider truncation and HTTP failures never become a category", {
  for (provider in c("openai", "claude")) {
    classify <- get(paste0(provider, "_cat"))
    column <- "category"
    for (status in c(200L, 401L, 429L, 500L)) {
      local_mocked_bindings(req_perform = function(req) {
        reply <- if (provider == "openai") {
          '{"choices":[{"message":{"content":"news"},"finish_reason":"length"}]}'
        } else {
          '{"content":[{"type":"text","text":"news"}],"stop_reason":"max_tokens"}'
        }
        httr2::response(status_code = status, body = charToRaw(reply))
      })
      out <- classify("a.com", "fixture", c("news", "sports"))
      expect_equal(out$status, "failed")
      expect_equal(out$error_code, switch(as.character(status),
        `200` = "invalid_response",
        `401` = "authentication_error",
        `429` = "rate_limited",
        `500` = "service_unavailable"
      ))
      expect_true(is.na(out[[column]]))
    }
  }
})

test_that("provider options fail before any API request", {
  local_mocked_bindings(req_perform = function(...) stop("unexpected network call"))
  for (classify in list(openai_cat, claude_cat)) {
    for (bad in list(character(), NA_character_, "", c("news", "news"))) {
      expect_error(classify("a.com", "fixture", categories = bad), "categories")
    }
    expect_error(classify("a.com", "fixture", model = ""), "model")
    expect_error(classify("a.com", "fixture", delay = -1), "delay")
    expect_error(classify("a.com", ""), "api_key")
  }
})
