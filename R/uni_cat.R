#' Get Category from University Domain List
#'
#' Fetches university domain json from:
#' \url{https://raw.githubusercontent.com/Hipo/university-domains-list/master/world_universities_and_domains.json}
#'
#' @param domains vector of domain names
#'
#' @return data.frame with original list and all the other columns from the university json
#'
#' @export
#' @importFrom dplyr bind_cols
#' @examples \dontrun{
#' uni_cat(domains = "http://www.google.com")
#' }

uni_cat <- function(domains = NULL) {

  validate_domains(domains)
  c_domains <- clean_domains(domains)

  uni_list <- fromJSON(paste0("https://raw.githubusercontent.com/Hipo/",
                              "university-domains-list/master/",
                              "world_universities_and_domains.json"))

  tibble(
    domain_name = c_domains
  ) |>
    bind_cols(
      uni_list[match(c_domains, uni_list$domains), ]
    ) |>
    as.data.frame(row.names = NULL)
}
