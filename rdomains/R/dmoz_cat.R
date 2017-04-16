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
#' @examples \dontrun{
#' dmoz_cat(domains = "http://www.google.com")
#' dmoz_cat(domains = c("http://www.google.com", "http://plus.google.com"))
#' }

dmoz_cat <- function(domains = NULL, use_file = NULL) {
  
  # Nuke leading and trailing spaces
  c_domains  <- gsub("^ *| *$", "", domains)

  # nuke leading http://
  c_domains_http  <- gsub("^http://", "", c_domains)

  # nuke leading www.
  c_domains  <- gsub("^www.", "", c_domains)

  # Initialize DMOZ object to read in the file
  dmoz <- NA

  # Initialize results df
  domain_cat <- data.frame(domain_name = c_domains, dmoz_category = NA)

  if (is.character(use_file)) {

    if (!file.exists(use_file)) stop("Please provide correct path to the file. Or download it using get_dmoz_data().")
    dmoz <- read.csv(use_file, header = FALSE, stringsAsFactors = FALSE)
  
  } else { 

    if (!file.exists('dmoz_domain_category.csv')) stop("Please provide path to the dmoz file. Or download it using get_dmoz_data().")
    dmoz <- read.csv('dmoz_domain_category.csv', header = FALSE, stringsAsFactors = FALSE)
  }

  names(dmoz) <- c("hostname", "category")

  # Match
  domain_cat$dmoz_category <- dmoz$category[match(c_domains_http, dmoz$hostname)]
  domain_cat$dmoz_category <- ifelse(is.na(domain_cat$dmoz_category), dmoz$category[match(c_domains, dmoz$hostname)], domain_cat$dmoz_category)
  domain_cat
}
