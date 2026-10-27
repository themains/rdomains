#' Get Category from Shallalist
#'
#' Fetches category of content hosted by a domain according to Shalla.
#' The function checks if path to the shalla file is provided by the user.
#' If not, it looks for \code{shalla_domain_category.csv} in the working directory.
#'
#' Shallalist stopped publishing in 2022, so these labels describe the domain as it was
#' then or earlier, not as it is now. The returned \code{source_last_published} column
#' carries that vintage when the file has verified download metadata.
#' A warning is issued once per session. See
#' \code{\link{source_vintage}}.
#'
#' Publication dates come from the `.metadata.json` sidecar written by the downloader,
#' checked against the file contents. `source_fetched_at` is the download time.
#' Files without matching metadata return `NA` dates; filesystem timestamps are not used.
#'
#' @param domains vector of domain names
#' @param use_file path to the latest shallalist file downloaded using \code{\link{get_shalla_data}}
#'
#' @return A tibble following [classification_results]. Source-specific data are
#'   retained in `details`; all source labels are retained in `labels`.
#'
#' @export
#' @seealso \code{\link{source_vintage}} for the provenance of every category source
#' @examples \dontrun{
#' shalla_cat(domains = "http://www.google.com")
#' }
shalla_cat <- function(domains, use_file = NULL) {
  validate_domains(domains)
  if (!length(domains)) {
    return(classification_result(domains, "shalla", "list_membership", "lookup"))
  }
  data_file <- validate_data_file(use_file, "shalla_domain_category.csv", "get_shalla_data")
  data <- read_csv(
    data_file, show_col_types = FALSE, col_types = readr::cols(.default = readr::col_character())
  )
  warn_source_vintage("shalla")
  lookup_result(domains, data, "domains", "category", "shalla", load_source_metadata(data_file))
}
