#' Structured classification outcomes
#'
#' Common error strings are checked against the versioned piedomains contract in
#' inst/contracts. R-specific acquisition codes and retry policies are explicit.
#' @keywords internal
#' @noRd
NULL

#' Pipeline stage a domain reached
#' @keywords internal
#' @noRd
RD_STAGES <- c("validate", "fetch", "process", "infer", "lookup")

#' The closed set of failure reasons
#'
#' `retryable` marks transient service or fetch errors. Model/setup failures need
#' intervention before retrying; missing or insufficient content needs another source.
#'
#' @keywords internal
#' @noRd
RD_ERROR_CODES <- tribble(
  ~code, ~stage, ~retryable, ~description,
  "invalid_domain", "validate", FALSE, "Not a fetchable http(s) host.",
  "robots_blocked", "validate", FALSE, "Disallowed by the host's robots.txt.",
  "private_address", "validate", FALSE, "Host resolves to a non-global address.",
  "dns_error", "fetch", TRUE, "Host did not resolve.",
  "connection_error", "fetch", TRUE, "Connection refused or reset.",
  "timeout", "fetch", TRUE, "Request exceeded the timeout.",
  "http_error", "fetch", FALSE, "A non-successful HTTP response requiring intervention.",
  "http_not_found", "fetch", FALSE, "The requested resource was not found or is gone.",
  "http_unavailable", "fetch", TRUE, "Transient HTTP failure or rate limit.",
  "redirect_error", "fetch", FALSE, "A redirect did not provide a usable destination.",
  "robots_unavailable", "fetch", TRUE, "Robots rules could not be retrieved.",
  "archive_unavailable", "fetch", TRUE, "The archive service could not complete the request.",
  "archive_rate_limited", "fetch", TRUE, "The archive rate-limited the request.",
  "archive_invalid_response", "fetch", FALSE, "The archive returned an invalid capture response.",
  "content_type_rejected", "fetch", FALSE, "Response was not HTML.",
  "content_too_large", "fetch", FALSE, "Body exceeded the byte cap.",
  "bot_blocked", "fetch", FALSE, "An anti-bot interstitial was served.",
  "no_archive_snapshot", "fetch", FALSE, "No archived capture for the requested date.",
  "too_many_redirects", "fetch", FALSE, "Redirect chain exceeded max_redirects.",
  "empty_text", "process", FALSE, "No text could be extracted.",
  "thin_content", "process", FALSE, "Below the token floor for an honest label.",
  "service_unavailable", "infer", TRUE, "Classification service asleep or down.",
  "rate_limited", "infer", TRUE, "Classification service rate-limited us.",
  "service_error", "infer", TRUE, "Classification service returned an error.",
  "model_load_error", "infer", FALSE, "The classifier could not be loaded.",
  "model_error", "infer", FALSE, "The classifier returned no valid prediction.",
  "missing_input_path", "process", FALSE, "Raw HTML is unavailable.",
  "authentication_error", "infer", FALSE, "Provider credentials were rejected.",
  "provider_error", "infer", FALSE, "Provider rejected the request.",
  "invalid_response", "infer", FALSE, "Provider returned an incomplete or invalid label.",
  "unknown", NA, FALSE, "Unclassified failure."
)

#' Reasons a domain can fail to get a category
#'
#' The closed set of `error_code` values that [collect_content()] and [pie_cat()] can
#' return, with the pipeline stage each belongs to and whether it is worth retrying.
#'
#' Shared strings retain their meaning in `piedomains`. R-specific acquisition
#' failures and retry-policy exceptions are recorded in the versioned contract.
#'
#' @return A tibble with columns `code`, `stage`, `retryable` and `description`.
#'
#' @export
#' @seealso [fetch_report()] to summarise an actual run, [source_vintage()] for the
#'   provenance of the static label sources.
#' @examples
#' fetch_error_codes()
#'
#' # which failures are worth trying again?
#' subset(fetch_error_codes(), retryable)
fetch_error_codes <- function() {
  RD_ERROR_CODES
}

#' Summarise the outcome of a fetch or classification run
#'
#' A pure function over the returned tibble, deliberately **not** a stored summary. A
#' snapshot goes stale the moment you filter the rows; recomputing means
#' `fetch_report(subset(x, retryable))` is always correct.
#'
#' @param x A tibble from [collect_content()] or [pie_cat()].
#'
#' @return A one-row tibble: `n`, `ok`, `failed`, `no_match`, `retryable`, and list-columns
#'   `by_stage`, `by_reason` and `missing` (the domains that produced nothing).
#'
#' @export
#' @examples
#' rows <- data.frame(
#'   domain_name = c("a.com", "b.com", "c.com"),
#'   status = c("ok", "failed", "failed"),
#'   stage = c("infer", "fetch", "process"),
#'   error_code = c(NA, "timeout", "thin_content"),
#'   retryable = c(FALSE, TRUE, FALSE)
#' )
#' fetch_report(rows)
fetch_report <- function(x) {
  if (!is.data.frame(x)) {
    cli_abort("{.arg x} must be a data frame returned by {.fn collect_content}")
  }
  needed <- c("status", "stage", "error_code")
  missing_cols <- setdiff(needed, names(x))
  if (length(missing_cols)) {
    cli_abort("{.arg x} is missing column{?s}: {.field {missing_cols}}")
  }

  # Named `is_failed`, not `failed`: tibble() evaluates its arguments sequentially and
  # later ones see earlier ones, so a `failed = sum(failed)` column would shadow the mask
  # and every subsequent subset would index with the count instead.
  if (anyNA(x$status) || !all(x$status %in% c("ok", "no_match", "failed"))) {
    cli_abort("Unknown result status.", class = "rdomains_invalid_result")
  }
  is_failed <- x$status %in% "failed"
  tibble(
    n = nrow(x),
    ok = sum(x$status %in% "ok"),
    failed = sum(is_failed),
    no_match = sum(x$status %in% "no_match"),
    retryable = if ("retryable" %in% names(x)) sum(x$retryable %in% TRUE) else NA_integer_,
    by_stage = list(count_values(x$stage[is_failed])),
    by_reason = list(count_values(x$error_code[is_failed])),
    missing = list(
      if ("domain_name" %in% names(x)) x$domain_name[is_failed] else character()
    )
  )
}

#' Tally a character vector, commonest first
#'
#' @param values character vector, `NA`s dropped
#' @return tibble of value and n
#' @keywords internal
#' @noRd
count_values <- function(values) {
  values <- values[!is.na(values)]
  if (!length(values)) {
    return(tibble(value = character(), n = integer()))
  }
  counted <- sort(table(values), decreasing = TRUE)
  tibble(value = names(counted), n = as.integer(counted))
}

#' Look up whether a code is retryable
#'
#' @param code error code, or NA
#' @return logical
#' @keywords internal
#' @noRd
is_retryable <- function(code) {
  if (is.na(code)) {
    return(FALSE)
  }
  hit <- RD_ERROR_CODES$retryable[match(code, RD_ERROR_CODES$code)]
  isTRUE(hit)
}

#' Map provider HTTP failures without retrying invalid credentials or missing resources
#' @keywords internal
#' @noRd
provider_error_code <- function(status) {
  if (is.na(status)) {
    "service_error"
  } else if (status == 429L) {
    "rate_limited"
  } else if (status >= 500L || status %in% c(408L, 425L)) {
    "service_unavailable"
  } else if (status %in% c(401L, 403L)) {
    "authentication_error"
  } else if (status %in% c(404L, 410L)) {
    "http_not_found"
  } else {
    "provider_error"
  }
}
