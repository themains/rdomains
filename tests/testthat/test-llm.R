# The LLM layer is tested against fake OpenAI (Responses API) and Anthropic (Messages
# API) servers on a loopback port. ellmer issues its own httr2 requests, so mocking
# req_perform in this namespace would not intercept them; a real server is the honest
# substitute. Server-backed tests are skipped on CRAN like the other webfakes tests.

fake_provider <- function(provider = c("openai", "anthropic"), reply = list(category = "news"),
                          status = 200L, fail_first = 0L) {
  provider <- match.arg(provider)
  app <- webfakes::new_app()
  app$use(webfakes::mw_json())
  app$locals$calls <- 0L
  app$locals$requests <- list()
  path <- if (provider == "openai") "/responses" else "/messages"
  app$post(path, function(req, res) {
    res$app$locals$calls <- res$app$locals$calls + 1L
    res$app$locals$requests[[length(res$app$locals$requests) + 1L]] <- req$json
    if (res$app$locals$calls <= fail_first) {
      return(res$set_status(429L)$send_json(list(error = list(message = "slow down")),
        auto_unbox = TRUE
      ))
    }
    if (status != 200L) {
      return(res$set_status(status)$send_json(list(error = list(message = "refused")),
        auto_unbox = TRUE
      ))
    }
    text <- as.character(jsonlite::toJSON(reply, auto_unbox = TRUE))
    body <- if (provider == "openai") {
      list(
        status = "completed", model = "gpt-6-luna",
        output = list(list(
          type = "message",
          content = list(list(type = "output_text", text = text))
        )),
        usage = list(input_tokens = 12L, output_tokens = 4L)
      )
    } else {
      list(
        model = "claude-haiku-5-5", stop_reason = "end_turn",
        content = list(list(type = "text", text = text)),
        usage = list(input_tokens = 12L, output_tokens = 4L)
      )
    }
    res$send_json(body, auto_unbox = TRUE)
  })
  app$get("/calls", function(req, res) res$send(as.character(res$app$locals$calls)))
  app$get("/requests", function(req, res) {
    res$send_json(res$app$locals$requests, auto_unbox = TRUE)
  })
  app
}

local_fake <- function(..., env = parent.frame()) {
  testthat::skip_if_not_installed("webfakes")
  testthat::skip_on_cran()
  srv <- webfakes::new_app_process(fake_provider(...))
  withr::defer(srv$stop(), envir = env)
  srv
}

base_url <- function(srv) sub("/$", "", srv$url())

calls <- function(srv) {
  as.integer(httr2::resp_body_string(httr2::req_perform(httr2::request(srv$url("/calls")))))
}

requests <- function(srv) {
  httr2::resp_body_json(httr2::req_perform(httr2::request(srv$url("/requests"))))
}

test_that("openai_cat classifies through structured output and records the request", {
  srv <- local_fake("openai")
  out <- openai_cat("https://www.A.com/x", api_key = "fixture", categories = c("news", "sports"),
    base_url = base_url(srv)
  )
  expect_equal(out$domain_name, "a.com")
  expect_equal(out$category, "news")
  expect_equal(out$status, "ok")
  expect_equal(out$provider, "openai")
  expect_equal(out$evidence_type, "domain_name")
  expect_equal(out$model_id, "gpt-6-luna")
  expect_true(is.na(out$error_code))
  expect_equal(out$details[[1]]$input_tokens, 12L)
  expect_equal(out$details[[1]]$output_tokens, 4L)
  expect_equal(out$details[[1]]$mode, "sequential")

  sent <- requests(srv)[[1]]
  expect_equal(sent$model, "gpt-6-luna")
  expect_equal(sent$reasoning$effort, "none")
  expect_equal(sent$max_output_tokens, 64)
  expect_equal(sent$text$format$type, "json_schema")
  expect_setequal(unlist(sent$text$format$schema$properties$category$enum), c("news", "sports"))
  expect_match(sent$input[[1]]$content[[1]]$text, "a.com", fixed = TRUE)
  expect_null(sent$temperature)
})

test_that("claude_cat classifies through Anthropic structured output", {
  srv <- local_fake("anthropic")
  out <- claude_cat("a.com", api_key = "fixture", categories = c("news", "sports"),
    base_url = base_url(srv)
  )
  expect_equal(out$category, "news")
  expect_equal(out$provider, "anthropic")
  expect_equal(out$model_id, "claude-haiku-5-5")
  sent <- requests(srv)[[1]]
  expect_equal(sent$model, "claude-haiku-5-5")
  expect_equal(sent$max_tokens, 64)
  expect_equal(sent$output_config$format$type, "json_schema")
  expect_null(sent$temperature)
})

test_that("a reply outside the vocabulary is a failure, not a category", {
  srv <- local_fake("openai", reply = list(category = "wrong"))
  out <- openai_cat("a.com", api_key = "fixture", categories = c("news", "sports"),
    base_url = base_url(srv)
  )
  expect_equal(out$status, "failed")
  expect_true(is.na(out$category))
  expect_equal(out$error_code, "invalid_response")
  expect_false(out$retryable)
})

test_that("HTTP failures keep their status and retry policy", {
  cases <- list(list(401L, "authentication_error", FALSE), list(500L, "service_unavailable", TRUE))
  for (case in cases) {
    srv <- local_fake("openai", status = case[[1]])
    out <- openai_cat("a.com", api_key = "fixture", base_url = base_url(srv))
    expect_equal(out$status, "failed")
    expect_true(is.na(out$category))
    expect_equal(out$error_code, case[[2]])
    expect_equal(out$retryable, case[[3]])
    expect_equal(out$http_status, case[[1]])
    expect_equal(out$model_id, "gpt-6-luna")
    expect_match(out$details[[1]]$message, "refused")
  }
})

test_that("a rate limit is retried before it is reported", {
  srv <- local_fake("openai", fail_first = 1L)
  out <- openai_cat("a.com", api_key = "fixture", base_url = base_url(srv))
  expect_equal(out$status, "ok")
  expect_equal(out$category, "news")
  expect_equal(calls(srv), 2L)
})

test_that("repeated hosts are sent once and parallel mode sends every distinct host", {
  srv <- local_fake("openai")
  out <- openai_cat(c("a.com", "A.com", "http://www.a.com/x"), api_key = "fixture",
    base_url = base_url(srv)
  )
  expect_equal(out$category, rep("news", 3))
  expect_identical(out$input_id, 1:3)
  expect_equal(calls(srv), 1L)

  out <- openai_cat(c("b.com", "c.com", "d.com"), api_key = "fixture",
    mode = "parallel", max_active = 3, base_url = base_url(srv)
  )
  expect_equal(out$category, rep("news", 3))
  expect_equal(out$details[[1]]$mode, "parallel")
  expect_equal(calls(srv), 4L)
})

test_that("llm_cat accepts any ellmer chat", {
  srv <- local_fake("anthropic")
  chat <- ellmer::chat_anthropic(model = "claude-haiku-5-5", credentials = function() "fixture",
    base_url = base_url(srv)
  )
  out <- llm_cat(c("a.com", "b.com"), chat, categories = c("news", "sports"))
  expect_equal(out$category, c("news", "news"))
  expect_equal(out$provider, c("anthropic", "anthropic"))
  expect_equal(calls(srv), 2L)
})

test_that("batch mode reports a pending job and collects a finished one", {
  chat <- ellmer::chat_openai(model = "gpt-6-luna", credentials = function() "fixture")
  state <- withr::local_tempfile(fileext = ".json")

  local_mocked_bindings(batch_chat_structured = function(...) NULL, .package = "ellmer")
  pending <- llm_cat(c("a.com", "b.com"), chat, mode = "batch", state_file = state, wait = FALSE)
  expect_equal(pending$status, c("failed", "failed"))
  expect_equal(pending$error_code, rep("batch_pending", 2))
  expect_true(all(pending$retryable))
  expect_equal(pending$details[[1]]$state_file, state)

  local_mocked_bindings(
    batch_chat_structured = function(chat, prompts, path, type, ...) {
      tibble::tibble(
        category = factor(c("news", "shopping")),
        input_tokens = c(10L, 11L), output_tokens = c(3L, 3L), cost = c(1e-6, 1e-6)
      )
    },
    .package = "ellmer"
  )
  done <- llm_cat(c("a.com", "b.com"), chat, mode = "batch", state_file = state)
  expect_equal(done$status, c("ok", "ok"))
  expect_equal(done$category, c("news", "shopping"))
  expect_equal(done$details[[2]]$input_tokens, 11L)
})

test_that("options fail before any request and empty input performs none", {
  chat <- ellmer::chat_openai(model = "gpt-6-luna", credentials = function() "fixture",
    base_url = "http://127.0.0.1:9"
  )
  for (bad in list(character(), NA_character_, "", c("news", "news"))) {
    expect_error(llm_cat("a.com", chat, categories = bad), "categories")
  }
  expect_error(llm_cat("a.com", chat, mode = "nope"), "mode")
  expect_error(llm_cat("a.com", chat, mode = "batch"), "state_file")
  expect_error(llm_cat("a.com", chat, mode = "batch", state_file = "job.txt"), "json")
  expect_error(llm_cat("a.com", chat, state_file = "job.json"), "state_file")
  expect_error(llm_cat("a.com", chat, max_active = 0), "max_active")
  expect_error(llm_cat("a.com", "gpt-6-luna"), "ellmer chat")
  expect_error(openai_cat("a.com", api_key = "fixture", model = ""), "model")
  expect_error(openai_cat("a.com", api_key = ""), "api_key")

  empty <- llm_cat(character(), chat)
  expect_equal(nrow(empty), 0L)
  expect_identical(empty, classification_result(character(), "openai", "domain_name"))
})
