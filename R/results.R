#' Classification result contract
#'
#' Classifiers preserve input order and return one row per input. `input_id` is the
#' one-based position in that call; retain it when saving and resuming a batch.
#' `status` is `ok`, `no_match` or `failed`. An absent lookup membership is not a
#' failed request. `category` is populated only when there is one selected label;
#' `labels` preserves every label in a tibble with `category`, `score` and `vendor`.
#' Unknown scores are `NA`, not probabilities inferred from list membership.
#'
#' `provider` identifies the classifier or list; `evidence_type` distinguishes page
#' content, archived content, name inference and list membership. `details` retains
#' source-specific records, including the collected page for piedomains results.
#' Model and source identifiers are reported where known; missing dates stay missing.
#'
#' @name classification_results
#' @return A tibble with input identity, provider, evidence, category, confidence,
#'   labels, status, stage, error_code, retryable, http_status, model_id,
#'   model_revision, source_last_published, source_fetched_at and details.
NULL

#' Construct a result with stable column types
#' @keywords internal
#' @noRd
classification_result <- function(input, provider, evidence_type, stage = "infer") {
  n <- length(input)
  tibble(
    input_id = seq_len(n), input = input, domain_name = clean_domains(input),
    provider = rep(provider, n), evidence_type = rep(evidence_type, n),
    category = rep(NA_character_, n), confidence = rep(NA_real_, n),
    labels = replicate(n, label_table(), simplify = FALSE),
    status = rep("no_match", n), stage = rep(stage, n),
    error_code = rep(NA_character_, n), retryable = rep(FALSE, n),
    http_status = rep(NA_integer_, n), model_id = rep(NA_character_, n),
    model_revision = rep(NA_character_, n), source_last_published = rep(NA_character_, n),
    source_fetched_at = rep(NA_character_, n), details = replicate(n, list(), simplify = FALSE)
  )
}

#' Construct typed labels without conflating membership with probability
#' @keywords internal
#' @noRd
label_table <- function(category = character(), score = NA_real_, vendor = NA_character_) {
  n <- length(category)
  tibble(
    category = as.character(category), score = rep_len(as.double(score), n),
    vendor = rep_len(as.character(vendor), n)
  )
}

#' Attach all labels while keeping the single-label summary unambiguous
#' @keywords internal
#' @noRd
set_result_labels <- function(result, i, labels) {
  labels <- unique(labels[order(labels$category, labels$vendor, na.last = TRUE), ])
  result$labels[[i]] <- labels
  result$status[i] <- if (nrow(labels)) "ok" else "no_match"
  categories <- unique(labels$category)
  result$category[i] <- if (length(categories) == 1L) categories else NA_character_
  result$confidence[i] <- if (nrow(labels) == 1L) labels$score else NA_real_
  result
}

#' Look up memberships without discarding repeated keys
#' @keywords internal
#' @noRd
lookup_result <- function(domains, data, key, label, provider, metadata = list()) {
  validate_lookup(data, c(key, label))
  result <- classification_result(domains, provider, "list_membership", "lookup")
  keys <- sub("^www\\.", "", tolower(trimws(data[[key]])))
  keep <- keys %in% result$domain_name
  data <- data[keep, , drop = FALSE]
  keys <- keys[keep]
  groups <- split(seq_along(keys), keys)
  for (i in seq_along(domains)) {
    rows <- data[groups[[result$domain_name[i]]] %||% integer(), , drop = FALSE]
    result <- set_result_labels(result, i, label_table(rows[[label]]))
    result$details[[i]] <- list(
      records = rows, source_url = metadata$source_url %||% NA_character_,
      checksum = metadata$checksum %||% NA_character_
    )
  }
  result$source_last_published <- rep(
    metadata$source_last_published %||% NA_character_, length(domains)
  )
  result$source_fetched_at <- rep(metadata$source_fetched_at %||% NA_character_, length(domains))
  result
}
