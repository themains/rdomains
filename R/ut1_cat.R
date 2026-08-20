#' Get category from the UT-Capitole blacklists
#'
#' Looks a domain up in the University of Toulouse (UT1) blacklists, the maintained
#' successor to Shallalist. Unlike [shalla_cat()] and [dmoz_cat()], which answer from lists
#' that stopped publishing in 2022 and 2017, this list is updated continuously — so
#' `source_last_published` is the date of the copy you downloaded rather than a constant.
#'
#' The categories are UT1's own (`drogue`, `publicite`, `tricheur`, `agressif`, ...) and are
#' reported verbatim. They do not share names with Shallalist's, and mapping one onto the
#' other would discard exactly the distinctions the two taxonomies disagree about.
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
  published <- tryCatch(
    format(as.Date(file.info(data_file)$mtime), "%Y-%m-%d"),
    error = function(e) NA_character_
  )

  tibble(
    domain_name = c_domains,
    ut1_category = ut1$category[match(c_domains, ut1$domain)],
    ut1_usage = ut1$usage[match(c_domains, ut1$domain)],
    source_last_published = published
  )
}
