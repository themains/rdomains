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
#' @param apikey virustotal API key
#'
#' @return data.frame with domain and VirusTotal analysis results
#'
#' @export
#' @references \url{https://docs.virustotal.com/reference/domains}
#'
#' @examples \dontrun{
#' virustotal_cat("http://www.google.com")
#' virustotal_cat(c("google.com", "facebook.com"))
#' }
virustotal_cat <- function(domains = NULL, apikey = NULL) {
  validate_domains(domains, "domains")

  if (identical(Sys.getenv("VirustotalToken"), "")) {
    if (is.null(apikey)) {
      cli_abort(c(
        "VirusTotal API key not found",
        "i" = "Provide via {.arg apikey} parameter",
        "i" = "Or set environment variable: {.envvar VirustotalToken}"
      ))
    }
    set_key(apikey)
  }

  results <- map_df(domains, function(domain) {
    res <- tryCatch(
      domain_report(domain),
      error = function(e) {
        cli_warn(c(
          "Error processing domain: {domain}",
          "x" = e$message
        ))
        data.frame(domain = domain)
      }
    )

    has_categories <- !is.null(res$data) &&
      !is.null(res$data$attributes$categories) &&
      length(res$data$attributes$categories) > 0

    if (has_categories) {
      categories <- res$data$attributes$categories
      cat_df <- as.data.frame(as.list(categories), stringsAsFactors = FALSE)
      data.frame(domain = domain, cat_df, stringsAsFactors = FALSE)
    } else {
      data.frame(domain = domain)
    }
  })

  results
}
