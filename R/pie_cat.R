#' Classify fetched HTML with piedomains
#'
#' Fetches pages with [collect_content()] and passes their original HTML to piedomains
#' for extraction, tokenization, calibration and classification. The Python package must
#' be version 0.15.0 or newer. This uses its text classifier, not its image or fusion models.
#'
#' A current fetch does not guarantee a correct current label. The shipped checkpoint
#' has known retail/drugs confusion; see its model card. Archive and cached content retain
#' their collection dates. `details` preserves the page and its `fetch_*` collection outcomes
#' separately from
#' the terminal classification `status`, `stage`, `error_code` and `retryable` columns.
#'
#' @section Setup:
#' Install `reticulate` and declare Python requirements before initializing Python:
#' `reticulate::py_require("piedomains==0.15.0", python_version = ">=3.12")`.
#' Set `RETICULATE_PYTHON` to select an existing Python environment.
#' Model weights download from Hugging Face on first use. The Python package pins its
#' default checkpoint; `PIEDOMAINS_TEXT_MODEL` can select another checkpoint or local path.
#' Results report the resolved model, revision when available, Python package version,
#' extractor, cleaning mode and calibration temperature.
#'
#' @param domains Character vector of domains or URLs. Supply either `domains` or `pages`.
#' @param pages Data frame from [collect_content()], including its retained `html` column, or
#' previous piedomains results.
#'   Previously extracted text alone is insufficient to reproduce model preprocessing.
#'   Failed fetches are retained. Failed inference can be retried on the same pages.
#' @param threshold Finite probability in `[0,1]`. Include every category at or above this
#'   value from the full model distribution, always retaining the predicted category.
#' @param model Optional Hugging Face model ID or local checkpoint directory. Overrides
#'   `PIEDOMAINS_TEXT_MODEL` for this call. The pinned default model is reused within a session.
#' @param ... Passed to [collect_content()] when `pages` is absent.
#' @return A tibble following [classification_results]. Source-specific data are
#'   retained in `details`; all source labels are retained in `labels`.
#'
#' @export
#' @examples \dontrun{
#' pages <- collect_content(c("cnn.com", "wikipedia.org"))
#' pie_cat(pages = pages)
#' }
pie_cat <- function(domains = NULL, pages = NULL, threshold = 0.10, model = NULL, ...) {
  if (!is.null(pages)) {
    rlang::check_dots_empty()
    if (!is.null(domains)) cli_abort("Supply either {.arg domains} or {.arg pages}, not both.")
  }
  if (!is.null(model)) {
    assert_character(model, len = 1, any.missing = FALSE, min.chars = 1)
  }
  if (!is.null(pages) && "provider" %in% names(pages)) {
    if (!all(pages$provider == "piedomains")) {
      cli_abort("Only piedomains results can be retried as pages.")
    }
    input_id <- pages$input_id
    pages <- if (nrow(pages)) bind_rows(pages$details) else fetch_row("", "", Sys.time())[FALSE, ]
    pages$input_id <- input_id
  }
  rows <- infer_pages(domains, pages, threshold, model = model, ...)
  input <- rows$input %||% rows$domain_name
  result <- classification_result(input, "piedomains", "page_content")
  for (i in seq_len(nrow(rows))) {
    scores <- rows$pie_categories[[i]]
    result <- set_result_labels(result, i, label_table(scores$category, scores$probability))
    if (identical(rows$label_source[i], "heuristic")) {
      result <- set_result_labels(result, i, label_table(rows$pie_category[i]))
      result$evidence_type[i] <- "page_state"
    } else if (identical(rows$source[i], "archive")) {
      result$evidence_type[i] <- "archived_content"
    }
  }
  result$category <- rows$pie_category
  result$confidence <- rows$pie_confidence
  outcome_columns <- c(
    "status", "stage", "error_code", "retryable", "http_status", "source_last_published"
  )
  for (name in outcome_columns) {
    if (name %in% names(rows)) result[[name]] <- rows[[name]]
  }
  result$model_id <- rows$model_repo
  result$model_revision <- rows$model_revision
  if ("input_id" %in% names(rows)) result$input_id <- rows$input_id
  if ("fetched_at" %in% names(rows)) {
    result$source_fetched_at <- format(rows$fetched_at, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  }
  result$details <- lapply(seq_len(nrow(rows)), function(i) rows[i, , drop = FALSE])
  result
}

#' Classify and retain acquired-page metadata
#' @keywords internal
#' @noRd
infer_pages <- function(domains = NULL, pages = NULL, threshold = 0.10, model = NULL, ...) {
  validate_number(threshold, "threshold", upper = 1)
  if (is.null(pages)) pages <- collect_content(domains, ...)
  needed <- c("domain_name", "html", "page_state", "status", "stage", "error_code", "retryable")
  if (!is.data.frame(pages) || !all(needed %in% names(pages))) {
    cli_abort("{.arg pages} must contain the HTML and outcome columns from {.fn collect_content}.")
  }
  for (name in setdiff(needed, "retryable")) {
    assert_character(pages[[name]],
      any.missing = name %in% c("html", "page_state", "error_code"),
      .var.name = paste0("pages$", name)
    )
  }
  assert_logical(pages$retryable, any.missing = FALSE)
  if (any(!pages$status %in% c("ok", "failed"))) cli_abort("Unknown {.arg pages$status}.")
  for (name in c("status", "stage", "error_code", "retryable")) {
    saved <- paste0("fetch_", name)
    if (!saved %in% names(pages)) pages[[saved]] <- pages[[name]]
    pages[[name]] <- pages[[saved]]
  }
  n <- nrow(pages)
  for (name in c(
    "pie_category", "label_source", "model_repo", "model_revision",
    "piedomains_version", "model_extractor", "model_cleaning", "inference_error"
  )) {
    pages[[name]] <- rep(NA_character_, n)
  }
  pages$pie_confidence <- pages$model_temperature <- rep(NA_real_, n)
  pages$pie_categories <- replicate(n, tibble(category = character(), probability = numeric()),
    simplify = FALSE
  )
  eligible <- pages$fetch_status == "ok"
  heuristic <- eligible & pages$page_state %in% c("parked", "unavailable")
  pages$pie_category[heuristic] <- pages$page_state[heuristic]
  pages$label_source[heuristic] <- "heuristic"
  pages$stage[heuristic] <- "infer"
  send <- which(eligible & !heuristic)
  if (!length(send)) {
    return(pages)
  }
  missing <- send[is.na(pages$html[send]) | !nzchar(pages$html[send])]
  if (length(missing)) {
    pages$status[missing] <- "failed"
    pages$stage[missing] <- "process"
    pages$error_code[missing] <- "missing_input_path"
    pages$retryable[missing] <- FALSE
    pages$inference_error[missing] <- "Raw HTML is missing; fetch the page again."
    send <- setdiff(send, missing)
  }
  if (!length(send)) {
    return(pages)
  }
  classifier <- tryCatch(pie_backend(model = model), error = function(e) e)
  load_failed <- inherits(classifier, "condition")
  scored <- if (load_failed) {
    classifier
  } else {
    tryCatch(classifier(pages$domain_name[send], pages$html[send], threshold),
      error = function(e) e
    )
  }
  if (inherits(scored, "condition")) {
    cli_warn(c("piedomains classification failed.", "x" = conditionMessage(scored)))
    pages$status[send] <- "failed"
    pages$stage[send] <- "infer"
    pages$error_code[send] <- if (load_failed) "model_load_error" else "model_error"
    pages$retryable[send] <- FALSE
    pages$inference_error[send] <- conditionMessage(scored)
    return(pages)
  }
  if (length(scored$category) != length(send)) {
    cli_abort("piedomains returned a different number of rows than requested.")
  }
  pages$pie_category[send] <- scored$category
  pages$pie_confidence[send] <- scored$confidence
  pages$pie_categories[send] <- scored$categories
  pages$status[send] <- ifelse(is.na(scored$category), "failed", "ok")
  pages$stage[send] <- scored$stage
  pages$error_code[send] <- scored$error_code
  pages$retryable[send] <- vapply(scored$error_code, is_retryable, logical(1))
  pages$inference_error[send] <- scored$error
  pages$label_source[send[!is.na(scored$category)]] <- "model"
  for (name in names(scored$metadata)) pages[[name]][send] <- scored$metadata[[name]]
  pages
}

#' Construct the Python bridge in the selected environment
#' @keywords internal
#' @noRd
pie_backend <- function(model = NULL) {
  if (!requireNamespace("reticulate", quietly = TRUE) ||
        !reticulate::py_module_available("piedomains")) {
    cli_abort("Install {.pkg reticulate} and Python {.pkg piedomains} >= 0.15.0.")
  }
  version <- reticulate::import("importlib.metadata")$version("piedomains")
  if (utils::compareVersion(version, "0.15.0") < 0) {
    cli_abort("piedomains >= 0.15.0 is required; the selected environment has {version}.")
  }
  text_mod <- reticulate::import("piedomains.text")
  config <- reticulate::import("piedomains.config")$get_config()
  python_env <- reticulate::import("os")$environ
  previous_python <- python_env$get("PIEDOMAINS_TEXT_MODEL")
  previous_r <- Sys.getenv("PIEDOMAINS_TEXT_MODEL", unset = NA_character_)
  on.exit({
    if (is.null(previous_python)) {
      python_env$pop("PIEDOMAINS_TEXT_MODEL", NULL)
    } else {
      python_env$`__setitem__`("PIEDOMAINS_TEXT_MODEL", previous_python)
    }
    if (is.na(previous_r)) {
      Sys.unsetenv("PIEDOMAINS_TEXT_MODEL")
    } else {
      Sys.setenv(PIEDOMAINS_TEXT_MODEL = previous_r)
    }
  }, add = TRUE)
  selected <- model %||% previous_r
  if (is.na(selected)) {
    python_env$pop("PIEDOMAINS_TEXT_MODEL", NULL)
  } else {
    python_env$`__setitem__`("PIEDOMAINS_TEXT_MODEL", selected)
  }
  source <- text_mod$resolve_text_model()
  key <- hash(list(
    version, source, config$get("text_max_length"), config$get("extractor"),
    config$get("text_cleaning")
  ))
  cached <- .rdomains_env$pie_model
  classifier <- if (identical(source, text_mod$DEFAULT_TEXT_MODEL) &&
                      identical(cached$key, key)) {
    cached$classifier
  } else {
    NULL
  }
  if (is.null(classifier)) {
    model_dir <- tempfile("rdomains-model-")
    dir.create(model_dir)
    classifier <- text_mod$TextClassifier(cache_dir = model_dir)
    classifier$load_models()
    if (identical(source, text_mod$DEFAULT_TEXT_MODEL)) {
      .rdomains_env$pie_model <- list(key = key, classifier = classifier)
    }
  }
  function(domains, html, threshold) {
    dir <- tempfile("rdomains-pie-")
    dir.create(dir)
    on.exit(unlink(dir, recursive = TRUE), add = TRUE)
    paths <- lapply(seq_along(domains), function(i) {
      path <- file.path(dir, paste0(i, ".html"))
      writeLines(enc2utf8(html[i]), path, useBytes = TRUE)
      list(domain = domains[i], text_path = path)
    })
    out <- classifier$classify_from_paths(paths)
    model_config <- classifier$`_model`$config
    revision <- if (reticulate::py_has_attr(model_config, "_commit_hash")) {
      model_config$`_commit_hash` %||% NA_character_
    } else {
      NA_character_
    }
    if (identical(source, text_mod$DEFAULT_TEXT_MODEL)) revision <- text_mod$DEFAULT_TEXT_REVISION
    pie_tidy(out, threshold, list(
      model_repo = source, model_revision = revision, piedomains_version = version,
      model_extractor = config$get("extractor"), model_cleaning = config$get("text_cleaning"),
      model_temperature = classifier$`_temperature`
    ))
  }
}

#' Keep predictions and errors aligned with their original rows
#' @keywords internal
#' @noRd
pie_tidy <- function(out, threshold, metadata) {
  rows <- if (!is.null(out$results)) out$results else out
  parsed <- lapply(rows, function(row) {
    category <- row$category %||% NA_character_
    confidence <- row$confidence %||% NA_real_
    scores <- unlist(row$raw_predictions, use.names = TRUE)
    valid <- length(category) == 1L && !is.na(category) && nzchar(category) &&
      length(confidence) == 1L && is.finite(confidence) && confidence >= 0 && confidence <= 1 &&
      is.numeric(scores) && length(scores) > 0 && all(is.finite(scores)) &&
      all(scores >= 0 & scores <= 1) && category %in% names(scores)
    if (!valid) {
      code <- row$error_code %||% "model_error"
      if (!code %in% RD_ERROR_CODES$code) code <- "model_error"
      return(list(
        category = NA_character_, confidence = NA_real_,
        categories = tibble(category = character(), probability = numeric()),
        error_code = code, stage = row$stage %||% "infer",
        error = row$error %||% "The model returned no valid classification."
      ))
    }
    scores <- sort(scores, decreasing = TRUE)
    keep <- scores >= threshold | names(scores) == category
    list(
      category = category, confidence = confidence,
      categories = tibble(category = names(scores)[keep], probability = unname(scores[keep])),
      error_code = NA_character_, stage = "infer", error = NA_character_
    )
  })
  list(
    category = vapply(parsed, `[[`, character(1), "category"),
    confidence = vapply(parsed, `[[`, numeric(1), "confidence"),
    categories = lapply(parsed, `[[`, "categories"),
    error_code = vapply(parsed, `[[`, character(1), "error_code"),
    stage = vapply(parsed, `[[`, character(1), "stage"),
    error = vapply(parsed, `[[`, character(1), "error"), metadata = metadata
  )
}
