#' Get Category from DMOZ
#'
#' Fetches category (or categories) of content hosted by a domain according to DMOZ.
#' The function checks if path to the DMOZ file is provided by the user.
#' If not, it looks for \code{dmoz_domain_cateory.csv} in the working directory. It also returns
#' results for prominent subdomains.
#'
#' DMOZ closed in March 2017 and the snapshot shipped here is from 2015, so these labels
#' describe the domain as it was a decade ago. The returned \code{source_last_published}
#' column carries that vintage, and a warning is issued once per session. See
#' \code{\link{source_vintage}}.
#'
#' @param domains vector of domain names
#' @param use_file path to the dmoz file, which can be downloaded using \code{\link{get_dmoz_data}}
#'
#' @return data.frame with the original list, the content category of the domain, and the
#'   vintage of the list that supplied it
#'
#' @export
#' @seealso \code{\link{source_vintage}} for the provenance of every category source
#' @importFrom dplyr coalesce
#' @examples \dontrun{
#' dmoz_cat(domains = "http://www.google.com")
#' dmoz_cat(domains = c("http://www.google.com", "http://plus.google.com"))
#' }

dmoz_cat <- function(domains = NULL, use_file = NULL) {

  validate_domains(domains)
  c_domains <- clean_domains(domains)

  data_file <- validate_data_file(
    use_file,
    "dmoz_domain_category.csv",
    "get_dmoz_data"
  )

  dmoz <- read_csv(data_file, col_names = c("hostname", "category"), show_col_types = FALSE)

  # The file get_dmoz_data() produces carries a "domain","cat_labels_en" header, and
  # naming the columns here does not consume it, so "domain" was a live lookup key.
  # Recognised rather than skipped, so a headerless file keeps its first row.
  if (nrow(dmoz) > 0 &&
        identical(dmoz$hostname[1], "domain") &&
        identical(dmoz$category[1], "cat_labels_en")) {
    dmoz <- dmoz[-1, ]
  }
  hostname <- tolower(dmoz$hostname)

  warn_source_vintage("dmoz")

  # DMOZ recorded hosts as they were published, and 84% of the rows keep the "www."
  # that clean_domains() strips: 2,089,331 of 2,488,259 rows have no bare counterpart
  # anywhere in the file. Looking up only the bare form leaves them unreachable.
  tibble(
    domain_name = c_domains,
    dmoz_category = coalesce(
      dmoz$category[match(c_domains, hostname)],
      dmoz$category[match(paste0("www.", c_domains), hostname)]
    ),
    source_last_published = SOURCE_VINTAGE$dmoz$last_published
  )
}
