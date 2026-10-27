#' Get category from the UT-Capitole blacklists
#'
#' Looks a domain up in the University of Toulouse (UT1) blacklists, the maintained
#' successor to Shallalist. Unlike [shalla_cat()] and [dmoz_cat()], which answer from lists
#' that stopped publishing in 2022 and 2017, this list is updated continuously — so
#' publication and download dates are recorded separately.
#'
#' The categories are UT1's own (`drogue`, `publicite`, `tricheur`, `agressif`, ...) and are
#' reported verbatim. They do not share names with Shallalist's, and mapping one onto the
#' other would discard exactly the distinctions the two taxonomies disagree about.
#'
#' Publication dates come from the `.metadata.json` sidecar written by the downloader,
#' checked against the file contents. `source_fetched_at` is the download time.
#' Files without matching metadata return `NA` dates; filesystem timestamps are not used.
#'
#' @param domains Vector of domain names.
#' @param use_file Path to the file written by [get_ut1_data()]. If `NULL`, looks for
#'   `ut1_domain_category.csv` in the working directory.
#'
#' @return A tibble following [classification_results]. Source-specific data are
#'   retained in `details`; all source labels are retained in `labels`.
#'
#' @export
#' @seealso [get_ut1_data()] to download the data, [source_vintage()] for how this source
#'   compares with the discontinued ones.
#' @examples \dontrun{
#' get_ut1_data()
#' ut1_cat(domains = c("example.com", "wikipedia.org"))
#'
#' # what a maintained list says versus one that stopped in 2022
#' merge(ut1_cat("example.com"), shalla_cat("example.com"), by = "domain_name")
#' }
ut1_cat <- function(domains, use_file = NULL) {
  validate_domains(domains)
  if (!length(domains)) {
    return(classification_result(domains, "ut1", "list_membership", "lookup"))
  }
  data_file <- validate_data_file(use_file, "ut1_domain_category.csv", "get_ut1_data")
  data <- read_csv(
    data_file, show_col_types = FALSE, col_types = readr::cols(.default = readr::col_character())
  )
  validate_lookup(data, c("domain", "category", "usage"), allow_missing = "usage")
  lookup_result(domains, data, "domain", "category", "ut1", load_source_metadata(data_file))
}
