#' Get Category from DMOZ
#'
#' Fetches category (or categories) of content hosted by a domain according to DMOZ.
#' The function checks if path to the DMOZ file is provided by the user.
#' If not, it looks for \code{dmoz_domain_category.csv} in the working directory. It also returns
#' results for prominent subdomains.
#'
#' DMOZ closed in March 2017 and the snapshot shipped here is from 2015, so these labels
#' describe the domain as it was a decade ago. The returned \code{source_last_published}
#' column carries that vintage when the file has verified download metadata.
#' A warning is issued once per session. See
#' \code{\link{source_vintage}}.
#'
#' Publication dates come from the `.metadata.json` sidecar written by the downloader,
#' checked against the file contents. `source_fetched_at` is the download time.
#' Files without matching metadata return `NA` dates; filesystem timestamps are not used.
#'
#' @param domains vector of domain names
#' @param use_file path to the dmoz file, which can be downloaded using \code{\link{get_dmoz_data}}
#'
#' @return A tibble following [classification_results]. Source-specific data are
#'   retained in `details`; all source labels are retained in `labels`.
#'
#' @export
#' @seealso \code{\link{source_vintage}} for the provenance of every category source
#' @importFrom dplyr coalesce
#' @examples \dontrun{
#' dmoz_cat(domains = "http://www.google.com")
#' dmoz_cat(domains = c("http://www.google.com", "http://plus.google.com"))
#' }
dmoz_cat <- function(domains, use_file = NULL) {
  validate_domains(domains)
  if (!length(domains)) {
    return(classification_result(domains, "dmoz", "list_membership", "lookup"))
  }
  data_file <- validate_data_file(use_file, "dmoz_domain_category.csv", "get_dmoz_data")
  data <- read_csv(data_file,
    col_names = c("hostname", "category"), show_col_types = FALSE,
    col_types = readr::cols(.default = readr::col_character())
  )
  if (nrow(data) && identical(data$hostname[1], "domain") &&
        identical(data$category[1], "cat_labels_en")) {
    data <- data[-1, ]
  }
  warn_source_vintage("dmoz")
  lookup_result(domains, data, "hostname", "category", "dmoz", load_source_metadata(data_file))
}
