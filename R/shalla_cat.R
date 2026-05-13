#' Get Category from Shallalist
#'
#' Fetches category of content hosted by a domain according to Shalla.
#' The function checks if path to the shalla file is provided by the user.
#' If not, it looks for \code{shalla_domain_category.csv} in the working directory.
#'
#' @param domains vector of domain names
#' @param use_file path to the latest shallalist file downloaded using \code{\link{get_shalla_data}}
#'
#' @return data.frame with original list and content category of the domain
#'
#' @export
#' @examples \dontrun{
#' shalla_cat(domains = "http://www.google.com")
#' }

shalla_cat <- function(domains = NULL, use_file = NULL) {

  validate_domains(domains)
  c_domains <- clean_domains(domains)

  data_file <- validate_data_file(
    use_file,
    "shalla_domain_category.csv",
    "get_shalla_data"
  )

  shalla <- read_csv(data_file, show_col_types = FALSE)

  tibble(
    domain_name = c_domains,
    shalla_category = shalla$category[match(c_domains, shalla$domains)]
  ) |>
    as.data.frame()
}
