#' Get Category from Shallalist
#'
#' Fetches category of content hosted by a domain according to Shalla. 
#' The function checks if path to the shalla file is provided by the user. 
#' If not, it looks for \code{shalla_domain_cateory.csv} in the working directory. 
#'
#' @param domains vector of domain names
#' @param use_file path to the latest shallalist file downloaded using \code{\link{get_shalla_data}}
#' 
#' @return data.frame with original list and content category of the domain
#' 
#' @export
#' @examples \dontrun{
#' shalla_cat(domains="http://www.google.com")
#' }

shalla_cat <- function(domains=NULL, use_file=NULL) {
	
	# Nuke leading and trailing spaces
	c_domains  <- gsub("^ *| *$", "", domains)

	# nuke leading http://
	c_domains  <- gsub("^http://", "", c_domains)

	# nuke leading www.
	c_domains  <- gsub("^www.", "", c_domains)

	# Initialize results df
	shalla <- NA
	domain_cat <- data.frame(domain_name = c_domains, shalla_category=NA)

	if (is.character(use_file)) {

		if (!file.exists(use_file)) stop("Please provide correct path to the file. Or download it using get_shalla_data().")
		shalla <- read.csv(use_file)
	
	} else { 

		if (!file.exists('shalla_domain_cateory.csv')) stop("Please provide path to the shallalist file. Or download it using get_shalla_data().")
		shalla <- read.csv('shalla_domain_cateory.csv')
	}

	# Match
	cats <- shalla$category[match(c_domains, shalla$hostname)]
	domain_cat$shalla_category <- ifelse(!is.null(cats), cats, NA)

	domain_cat
}
