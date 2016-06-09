#' Get Category from Shallalist
#'
#' Fetches category of content hosted by domain from Shallalist. 
#'
#' 
#' @param domains vector of domain names
#' @param use_file path to the latest shallalist file downloaded using \code{\link{get_shalla_data}}
#' 
#' 
#' @return data.frame with original list and content category of the domain
#' 
#' @export
#' @examples 
#' shalla_cat(domains="http://www.google.com")
#' 

shalla_cat <- function(domains=NULL, use_file=NULL) {
	
	# Nuke leading and trailing spaces
	c_domains  <- gsub("^ *| *$", "", domains)

	# nuke leading http://
	c_domains  <- gsub("^http://", "", c_domains)

	# nuke leading www.
	c_domains  <- gsub("^www.", "", c_domains)

	# Initialize results df
	domain_cat <- data.frame(domain_name = c_domains, shalla_category=NA)

	if (!is.null(use_file)) {

		shalla <- read.csv(use_file)
		# Match
		domain_cat$shalla_category <- shalla$category[match(c_domains, shalla$hostname)]
		return(domain_cat)
	}

	# Match
	domain_cat$shalla_category <- shallalist$category[match(c_domains, shallalist$hostname)]

	domain_cat
}
