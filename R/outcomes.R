#' Why a domain produced no category
#'
#' Ported from the sibling Python package piedomains (`src/piedomains/outcomes.py`), and
#' the strings are **copied verbatim** so results from either package aggregate together.
#' They are part of the public output contract: safe to group on, and they will not change
#' meaning between releases.
#'
#' The problem this solves in rdomains: every failure used to collapse to `NA` plus a
#' warning, so "the host does not resolve", "we were rate-limited" and "this domain has no
#' category" were indistinguishable. Only the second is worth retrying, and a caller had no
#' way to tell which rows those were.
#'
#' @keywords internal
#' @noRd
NULL

#' Pipeline stage a domain reached
#' @keywords internal
#' @noRd
RD_STAGES <- c("validate", "fetch", "process", "infer")

#' The closed set of failure reasons
#'
#' `retryable` marks transient conditions. Two deliberate divergences from piedomains,
#' both because rdomains has no archive.org fallback to retry *into*:
#'   * `bot_blocked` is not retryable here -- retrying from the same address is rudeness
#'     with a guaranteed identical outcome.
#'   * The archive-specific codes are absent.
#'
#' @keywords internal
#' @noRd
RD_ERROR_CODES <- tribble(
  ~code,                   ~stage,     ~retryable, ~description,
  "invalid_domain",        "validate", FALSE, "Not a fetchable http(s) host.",
  "robots_blocked",        "validate", FALSE, "Disallowed by the host's robots.txt.",
  "private_address",       "validate", FALSE, "Host resolves to a non-global address.",
  "dns_error",             "fetch",    TRUE,  "Host did not resolve.",
  "connection_error",      "fetch",    TRUE,  "Connection refused or reset.",
  "timeout",               "fetch",    TRUE,  "Request exceeded the timeout.",
  "http_error",            "fetch",    TRUE,  "Non-2xx status.",
  "content_type_rejected", "fetch",    FALSE, "Response was not HTML.",
  "content_too_large",     "fetch",    FALSE, "Body exceeded the byte cap.",
  "bot_blocked",           "fetch",    FALSE, "An anti-bot interstitial was served.",
  "empty_text",            "process",  FALSE, "No text could be extracted.",
  "thin_content",          "process",  FALSE, "Below the token floor for an honest label.",
  "service_unavailable",   "infer",    TRUE,  "Classification service asleep or down.",
  "rate_limited",          "infer",    TRUE,  "Classification service rate-limited us.",
  "service_error",         "infer",    TRUE,  "Classification service returned an error.",
  "unknown",               NA,         FALSE, "Unclassified failure."
)

#' Reasons a domain can fail to get a category
#'
#' The closed set of `error_code` values that [collect_content()] and [pie_cat()] can
#' return, with the pipeline stage each belongs to and whether it is worth retrying.
#'
#' These strings are shared verbatim with the Python package `piedomains`, so results from
#' the two can be aggregated together.
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
#' @return A one-row tibble: `n`, `ok`, `failed`, `retryable`, and list-columns
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
  is_failed <- x$status %in% "failed"
  tibble(
    n = nrow(x),
    ok = sum(x$status %in% "ok"),
    failed = sum(is_failed),
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
