#' Get Category from DMOZ
#'
#' Fetches category (or categories) of content hosted by a domain according to DMOZ.
#' The function checks if path to the DMOZ file is provided by the user.
#' If not, it looks for \code{dmoz_domain_cateory.csv} in the working directory. It also returns
#' results for prominent subdomains.
#'
#' @param domains vector of domain names
#' @param use_file path to the dmoz file, which can be downloaded using \code{\link{get_dmoz_data}}
#'
#' @return data.frame with original list and content category of the domain
#'
#' @export
#' @importFrom dplyr coalesce
#' @examples \dontrun{
#' dmoz_cat(domains = "http://www.google.com")
#' dmoz_cat(domains = c("http://www.google.com", "http://plus.google.com"))
#' }

dmoz_cat <- function(domains = NULL, use_file = NULL) {

  validate_domains(domains)
  c_domains <- clean_domains(domains)
  c_domains_http <- str_remove(c_domains, "^http://")

  data_file <- validate_data_file(
    use_file,
    "dmoz_domain_category.csv",
    "get_dmoz_data"
  )

  dmoz <- read_csv(data_file, col_names = c("hostname", "category"), show_col_types = FALSE)

  tibble(
    domain_name = c_domains,
    dmoz_category = coalesce(
      dmoz$category[match(c_domains_http, dmoz$hostname)],
      dmoz$category[match(c_domains, dmoz$hostname)]
    )
  )
}
