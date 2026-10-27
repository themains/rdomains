#' Get Category from VirusTotal
#'
#' Returns category of content from multiple security vendors using the VirusTotal API v3.
#' The function retrieves domain analysis results including categories from various security
#' services. Not all services will have categories for all domains.
#'
#' Get the API Access Key from \url{https://www.virustotal.com/}. Either pass the API Key to the function # nolint: line_length_linter.
#' or set the environmental variable: \code{VirustotalToken}. Environment variables persist within
#' a R session.
#'
#' @param domains domain names as character vector
#' @param api_key virustotal API key
#'
#' @return A tibble following [classification_results]. Source-specific data are
#'   retained in `details`; all source labels are retained in `labels`.
#'
#' @export
#' @references \url{https://docs.virustotal.com/reference/domains}
#'
#' @examples \dontrun{
#' virustotal_cat("http://www.google.com")
#' virustotal_cat(c("google.com", "facebook.com"))
#' }
virustotal_cat <- function(domains, api_key = NULL) {
  validate_domains(domains)
  result <- classification_result(domains, "virustotal", "vendor_report", "lookup")
  if (!length(domains)) {
    return(result)
  }
  key <- get_api_key(api_key, c("VIRUSTOTAL_API_KEY", "VirustotalToken"), "VirusTotal")
  withr::local_envvar(c(VIRUSTOTAL_API_KEY = key, VirustotalToken = key))
  for (i in seq_along(domains)) {
    response <- tryCatch(domain_report(result$domain_name[i]), error = function(e) e)
    if (inherits(response, "condition")) {
      result$status[i] <- "failed"
      status <- response$status_code
      if (is.null(status) || !is.numeric(status) || length(status) != 1L || is.na(status)) {
        status <- NA_integer_
      }
      result$http_status[i] <- as.integer(status)
      result$error_code[i] <- if (inherits(response, "virustotal_auth_error")) {
        "authentication_error"
      } else if (inherits(response, "virustotal_rate_limit_error")) {
        "rate_limited"
      } else {
        provider_error_code(status)
      }
      result$retryable[i] <- is_retryable(result$error_code[i])
      result$details[[i]] <- list(message = conditionMessage(response))
    } else {
      labels <- tryCatch({
        categories <- response$data$attributes$categories
        if (!length(categories)) {
          label_table()
        } else {
          valid <- !is.null(names(categories)) && all(nzchar(names(categories))) &&
            all(vapply(categories, function(x) {
              is.character(x) && length(x) == 1L && !is.na(x) && nzchar(trimws(x))
            }, logical(1)))
          if (!valid) stop("Malformed vendor labels")
          label_table(unlist(categories, use.names = FALSE), vendor = names(categories))
        }
      }, error = function(e) e)
      if (inherits(labels, "condition")) {
        result$status[i] <- "failed"
        result$error_code[i] <- "invalid_response"
        result$details[[i]] <- list(message = conditionMessage(labels))
      } else {
        result <- set_result_labels(result, i, labels)
      }
    }
    result$source_fetched_at[i] <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  }
  result
}
