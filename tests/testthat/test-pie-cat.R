pie_page <- function(text = "text", domain = "example.com") {
  fetch_row(domain, domain, Sys.time(),
    status = "ok", stage = "process",
    parsed = list(text = text), signals = list(page_state = "content"),
    html = paste0("<html><body>", text, "</body></html>")
  )
}

pie_prediction <- function(category = "news", confidence = 0.6) {
  list(
    category = category, confidence = confidence,
    raw_predictions = list(news = confidence, shopping = 1 - confidence)
  )
}

test_that("pie thresholds filter the full distribution and retain the argmax", {
  out <- list(pie_prediction())
  low <- pie_tidy(out, 0.1, list())
  high <- pie_tidy(out, 0.9, list())
  expect_equal(low$categories[[1]]$category, c("news", "shopping"))
  expect_equal(high$categories[[1]]$category, "news")
  expect_equal(pie_tidy(out, 0, list())$categories[[1]]$probability, c(0.6, 0.4))
  for (bad in list(NA_real_, NaN, Inf, -0.1, 1.01, numeric(), c(0.1, 0.2), "0.1")) {
    expect_error(pie_cat(pages = pie_page(), threshold = bad), "threshold")
  }
})

test_that("classification failures preserve fetch provenance and remain retryable by caller", {
  local_mocked_bindings(pie_backend = function() {
    function(domains, html, threshold) {
      pie_tidy(
        list(list(error_code = "thin_content", stage = "process", error = "short")),
        threshold, list(model_repo = "fixture/model")
      )
    }
  })
  res <- pie_cat(pages = pie_page())
  expect_equal(res$status, "failed")
  expect_equal(res$fetch_status, "ok")
  expect_equal(res$error_code, "thin_content")
  expect_true(is.na(res$label_source))
  expect_equal(fetch_report(res)$failed, 1L)
  local_mocked_bindings(pie_backend = function() {
    function(domains, html, threshold) {
      pie_tidy(list(pie_prediction()), threshold, list(model_repo = "fixture/model"))
    }
  })
  retried <- pie_cat(pages = res)
  expect_equal(retried$status, "ok")
  expect_equal(retried$stage, "infer")
  expect_equal(retried$model_repo, "fixture/model")
  expect_equal(retried$fetch_status, "ok")
  expect_true(is.na(retried$error_code))
})

test_that("an unavailable model is never reported as a successful classification", {
  local_mocked_bindings(pie_backend = function() stop("missing model"))
  expect_warning(res <- pie_cat(pages = pie_page()), "classification failed")
  expect_equal(res$error_code, "model_load_error")
  expect_equal(res$status, "failed")
  expect_true(is.na(res$label_source))
})

test_that("pie requires raw HTML and page state and handles empty frames", {
  p <- pie_page()
  expect_error(pie_cat(pages = p[, setdiff(names(p), "page_state")]), "pages")
  expect_error(pie_cat(pages = p[, setdiff(names(p), "html")]), "pages")
  expect_equal(nrow(pie_cat(pages = p[FALSE, ])), 0L)
  p$html <- NA_character_
  expect_equal(pie_cat(pages = p)$error_code, "missing_input_path")
  p$status <- "unknown"
  expect_error(pie_cat(pages = p), "status")
})

test_that("failed fetches are not relabeled by page heuristics", {
  p <- pie_page()
  p$page_state <- "parked"
  expect_equal(pie_cat(pages = p)$label_source, "heuristic")
  p$status <- "failed"
  expect_true(is.na(pie_cat(pages = p)$pie_category))
})

test_that("Python bridge preserves HTML, duplicate rows, threshold and checkpoint identity", {
  python <- Sys.getenv("RDOMAINS_TEST_PYTHON")
  skip_if(!nzchar(python), "Set RDOMAINS_TEST_PYTHON to exercise installed piedomains")
  skip_if_not_installed("reticulate")
  reticulate::use_python(python, required = TRUE)
  reticulate::py_run_string(paste(
    "from piedomains.text import TextClassifier",
    "from types import SimpleNamespace",
    "_rd_load = TextClassifier.load_models",
    "_rd_score = TextClassifier._predict_text",
    "def _rd_fake_load(self, latest=False):",
    "    self._model = SimpleNamespace(config=SimpleNamespace(_commit_hash='fixture'))",
    "def _rd_fake_score(self, text):",
    "    name = 'sports' if 'football' in text else 'news'",
    "    return {'text_label':name, 'text_prob':0.6,",
    "            'text_domain_probs':{name:0.6,'shopping':0.4}, 'text_categories':[]}",
    "TextClassifier.load_models = _rd_fake_load",
    "TextClassifier._predict_text = _rd_fake_score",
    sep = "\n"
  ))
  withr::defer(reticulate::py_run_string(paste(
    "TextClassifier.load_models = _rd_load",
    "TextClassifier._predict_text = _rd_score",
    sep = "\n"
  )))
  a <- pie_page(paste(rep("election journalism government news", 20), collapse = " "))
  a$html <- paste0("<html><body><nav>", paste(rep("football", 50), collapse = " "),
                   "</nav><main><article><p>", a$text,
                   "</p></article></main></body></html>")
  b <- pie_page(paste(rep("football game match results", 20), collapse = " "))
  out <- pie_cat(pages = rbind(a, b), threshold = 0.9)
  expect_equal(out$pie_category, c("news", "sports"))
  expect_equal(lengths(out$pie_categories), c(2L, 2L))
  expect_equal(vapply(out$pie_categories, nrow, integer(1)), c(1L, 1L))
  expect_equal(out$model_repo, rep("gojiberries/piedomains-text", 2))
  expect_equal(out$model_revision, rep("38d7e6403f911902f47b9218ce5c645a06dd02fe", 2))
  reverse <- pie_cat(pages = rbind(b, a))
  expect_equal(reverse$pie_category, rev(out$pie_category))
  expect_equal(pie_cat(pages = pie_page("short"))$error_code, "thin_content")
})

test_that("prediction exceptions are distinct from unavailable backends", {
  local_mocked_bindings(pie_backend = function() {
    function(domains, html, threshold) stop("prediction failed")
  })
  expect_warning(out <- pie_cat(pages = pie_page()), "classification failed")
  expect_equal(out$error_code, "model_error")
  expect_equal(out$status, "failed")
})
