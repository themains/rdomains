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
#' @return A tibble with `domain_name`, `ut1_category`, `ut1_usage` (`"black"` where UT1
#'   maintains the list for blocking, `"white"` where it maintains it for allowing — both
#'   describe content) and `source_last_published`, the date the list was published.
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
ut1_cat <- function(domains = NULL, use_file = NULL) {
  validate_domains(domains)
  c_domains <- clean_domains(domains)

  data_file <- validate_data_file(
    use_file,
    "ut1_domain_category.csv",
    "get_ut1_data"
  )

  ut1 <- read_csv(data_file, show_col_types = FALSE)
  validate_lookup(ut1, c("domain", "category", "usage"))
  metadata <- load_source_metadata(data_file)

  tibble(
    domain_name = c_domains,
    ut1_category = ut1$category[match(c_domains, ut1$domain)],
    ut1_usage = ut1$usage[match(c_domains, ut1$domain)],
    source_last_published = metadata$source_last_published,
    source_fetched_at = metadata$source_fetched_at
  )
}
