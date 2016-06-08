#' Get Category from Shallalist
#'
#' Fetches category of content hosted by domain from Shallalist. If \code{use_new} is TRUE,
#' \link{\code{get_shall_data}} is invoked, which in turn checks whether the user wants to use a 
#' local (but newer than what is in the package) shallalist file or download a new one.
#'
#' 
#' @param domains vector of domain names
#' @param use_new use new shallalist database; default is FALSE
#' 
#' @return data.frame with original list and content category of the domain
#' 
#' @export
#' @examples 
#' shalla_cat(domains="http://www.google.com")
#' 

shalla_cat <- function(domains=NULL, use_new=FALSE) {
	
	# Nuke leading and trailing spaces
	c_domains  <- gsub("^ *| *$", "", domains)

	# nuke leading http://
	c_domains  <- gsub("^http://", "", c_domains)

	# nuke leading www.
	c_domains  <- gsub("^www.", "", c_domains)

	# Initialize results df
	domain_cat <- data.frame(domain_name = c_domains, shalla_category=NA)

	# Match
	domain_cat$shalla_category <- shallalist$category[match(c_domains, shallalist$hostname)]

	domain_cat
}
