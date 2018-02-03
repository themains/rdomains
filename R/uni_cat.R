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
#' @examples \dontrun{
#' uni_cat(domains = "http://www.google.com")
#' }

uni_cat <- function(domains = NULL) {

  # Nuke leading and trailing spaces
  c_domains  <- gsub("^ *| *$", "", domains)

  # nuke leading http://
  c_domains  <- gsub("^http://", "", c_domains)

  # nuke leading www.
  c_domains  <- gsub("^www.", "", c_domains)

  # Get list of university domain names
  uni_list <- fromJSON("https://raw.githubusercontent.com/Hipo/university-domains-list/master/world_universities_and_domains.json")

  # Match
  data.frame(domain_name = c_domains, uni_list[match(c_domains, uni_list$domains), ], row.names = NULL)
}
