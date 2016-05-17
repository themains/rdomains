#' Get Category from DMOZ
#'
#' Fetches category of content hosted by domain from DMOZ.
#'
#' @param domains vector of domain names
#' 
#' @return data.frame with original list and content category of the domain
#' @export
#' @examples 
#' dmoz_cat(domains="http://www.google.com")
#' 

dmoz_cat <- function(domains=NULL) {
	
	# Nuke leading and trailing spaces
	c_domains  <- gsub("^ *| *$", "", domains)

	# nuke leading http://
	c_domains  <- gsub("^http://", "", c_domains)

	# nuke leading www.
	c_domains  <- gsub("^www.", "", c_domains)

	# Initialize results df
	domain_cat <- data.frame(domain_name = c_domains, dmoz_category=NA)

	# Match
	domain_cat$dmoz_category <- dmoz$category[match(c_domains, dmoz$hostname)]

	domain_cat
}
