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
  local_mocked_bindings(pie_backend = function(model = NULL) {
    function(domains, html, threshold) {
      pie_tidy(
        list(list(error_code = "thin_content", stage = "process", error = "short")),
        threshold, list(model_repo = "fixture/model")
      )
    }
  })
  res <- pie_cat(pages = pie_page())
  expect_equal(res$status, "failed")
  expect_equal(res$details[[1]]$fetch_status, "ok")
  expect_equal(res$error_code, "thin_content")
  expect_true(is.na(res$details[[1]]$label_source))
  expect_equal(fetch_report(res)$failed, 1L)
  local_mocked_bindings(pie_backend = function(model = NULL) {
    function(domains, html, threshold) {
      pie_tidy(list(pie_prediction()), threshold, list(model_repo = "fixture/model"))
    }
  })
  retried <- pie_cat(pages = res)
  expect_equal(retried$status, "ok")
  expect_equal(retried$stage, "infer")
  expect_equal(retried$model_id, "fixture/model")
  expect_equal(retried$details[[1]]$fetch_status, "ok")
  expect_true(is.na(retried$error_code))
})

test_that("an unavailable model is never reported as a successful classification", {
  local_mocked_bindings(pie_backend = function(model = NULL) stop("missing model"))
  expect_warning(res <- pie_cat(pages = pie_page()), "classification failed")
  expect_equal(res$error_code, "model_load_error")
  expect_equal(res$status, "failed")
  expect_true(is.na(res$details[[1]]$label_source))
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
  expect_equal(pie_cat(pages = p)$details[[1]]$label_source, "heuristic")
  p$status <- "failed"
  expect_true(is.na(pie_cat(pages = p)$category))
})

test_that("Python bridge preserves HTML, duplicate rows, threshold and checkpoint identity", {
  python <- Sys.getenv("RDOMAINS_TEST_PYTHON")
  skip_if(!nzchar(python), "Set RDOMAINS_TEST_PYTHON to exercise installed piedomains")
  skip_if_not_installed("reticulate")
  cached_model <- .rdomains_env$pie_model
  .rdomains_env$pie_model <- NULL
  withr::defer(.rdomains_env$pie_model <- cached_model)
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
  a$html <- paste0(
    "<html><body><nav>", paste(rep("football", 50), collapse = " "),
    "</nav><main><article><p>", a$text,
    "</p></article></main></body></html>"
  )
  b <- pie_page(paste(rep("football game match results", 20), collapse = " "))
  out <- pie_cat(pages = rbind(a, b), threshold = 0.9)
  expect_equal(out$category, c("news", "sports"))
  expect_equal(lengths(out$labels), c(3L, 3L))
  expect_equal(vapply(out$labels, nrow, integer(1)), c(1L, 1L))
  expect_equal(out$model_id, rep("gojiberries/piedomains-text", 2))
  expect_equal(out$model_revision, rep("38d7e6403f911902f47b9218ce5c645a06dd02fe", 2))
  reverse <- pie_cat(pages = rbind(b, a))
  expect_equal(reverse$category, rev(out$category))
  expect_equal(pie_cat(pages = pie_page("short"))$error_code, "thin_content")
})

test_that("prediction exceptions are distinct from unavailable backends", {
  local_mocked_bindings(pie_backend = function(model = NULL) {
    function(domains, html, threshold) stop("prediction failed")
  })
  expect_warning(out <- pie_cat(pages = pie_page()), "classification failed")
  expect_equal(out$error_code, "model_error")
  expect_equal(out$status, "failed")
})

test_that("successive model choices reach Python and restore both environments", {
  python <- Sys.getenv("RDOMAINS_TEST_PYTHON")
  skip_if(!nzchar(python), "Set RDOMAINS_TEST_PYTHON to exercise installed piedomains")
  skip_if_not_installed("reticulate")
  reticulate::use_python(python, required = TRUE)
  cached_model <- .rdomains_env$pie_model
  .rdomains_env$pie_model <- NULL
  withr::defer(.rdomains_env$pie_model <- cached_model)
  withr::local_envvar(c(PIEDOMAINS_TEXT_MODEL = "r-original"))
  reticulate::py_run_string(paste(
    "import os",
    "from piedomains.text import TextClassifier, resolve_text_model",
    "from types import SimpleNamespace",
    "_rd_previous_env = os.environ.get('PIEDOMAINS_TEXT_MODEL')",
    "os.environ['PIEDOMAINS_TEXT_MODEL'] = 'python-original'",
    "_rd_model_load = TextClassifier.load_models",
    "_rd_model_score = TextClassifier._predict_text",
    "_rd_selected_models = []",
    "def _rd_select_model(self, latest=False):",
    "    if self._model is not None and not latest:",
    "        return",
    "    source = resolve_text_model()",
    "    _rd_selected_models.append(source)",
    "    if source == 'fixture/failure':",
    "        raise RuntimeError('fixture load failure')",
    "    self._model = SimpleNamespace(config=SimpleNamespace(_commit_hash=source))",
    "def _rd_select_score(self, text):",
    "    return {'text_label':'news', 'text_prob':0.8,",
    "            'text_domain_probs':{'news':0.8,'shopping':0.2}, 'text_categories':[]}",
    "TextClassifier.load_models = _rd_select_model",
    "TextClassifier._predict_text = _rd_select_score",
    sep = "\n"
  ))
  withr::defer(reticulate::py_run_string(paste(
    "TextClassifier.load_models = _rd_model_load",
    "TextClassifier._predict_text = _rd_model_score",
    "if _rd_previous_env is None:",
    "    os.environ.pop('PIEDOMAINS_TEXT_MODEL', None)",
    "else:",
    "    os.environ['PIEDOMAINS_TEXT_MODEL'] = _rd_previous_env",
    sep = "\n"
  )))
  Sys.setenv(PIEDOMAINS_TEXT_MODEL = "r-original")
  page <- pie_page(paste(rep("election journalism government news", 20), collapse = " "))
  for (choice in c("fixture/alpha", "fixture/beta")) {
    result <- pie_cat(pages = page, model = choice)
    expect_identical(result$status, "ok")
    expect_identical(result$model_id, choice)
    expect_identical(result$model_revision, choice)
    expect_identical(Sys.getenv("PIEDOMAINS_TEXT_MODEL"), "r-original")
    expect_identical(reticulate::py_eval("os.environ['PIEDOMAINS_TEXT_MODEL']"), "python-original")
  }
  expect_identical(pie_cat(pages = page)$model_id, "r-original")
  expect_warning(
    failed <- pie_cat(pages = page, model = "fixture/failure"), "classification failed"
  )
  expect_identical(failed$error_code, "model_load_error")
  expect_identical(Sys.getenv("PIEDOMAINS_TEXT_MODEL"), "r-original")
  expect_identical(reticulate::py_eval("os.environ['PIEDOMAINS_TEXT_MODEL']"), "python-original")
  expect_equal(reticulate::py_eval("_rd_selected_models"),
               c("fixture/alpha", "fixture/beta", "r-original", "fixture/failure"))
})
