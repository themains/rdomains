#' Get Category from DMOZ
#'
#' Fetches category of content hosted by a domain according to DMOZ. 
#' The function checks if path to the dmoz file is provided by the user. 
#' If not, it looks for \code{dmoz_domain_cateory.csv} in the working directory. 
#'
#' @param domains vector of domain names
#' @param use_file path to the dmoz file, which can be downloaded using \code{\link{get_dmoz_data}}
#' 
#' @return data.frame with original list and content category of the domain
#' 
#' @export
#' @examples 
#' dmoz_cat(domains="http://www.google.com")
#' 

dmoz_cat <- function(domains=NULL, use_file=NULL) {
	
	# Nuke leading and trailing spaces
	c_domains  <- gsub("^ *| *$", "", domains)

	# nuke leading http://
	c_domains  <- gsub("^http://", "", c_domains)

	# nuke leading www.
	c_domains  <- gsub("^www.", "", c_domains)

	# Initialize results df
	dmoz <- NA
	domain_cat <- data.frame(domain_name = c_domains, shalla_category=NA)

	if (!is.character(use_file)) {

		if (!file.exists(use_file)) stop("Please provide correct path to the file.")
		dmoz <- read.csv(use_file, header =F)
	
	} else { 

		if (!file.exists('dmoz_domain_cateory.csv')) stop("Please provide path to the dmoz file. Or download it using get_dmoz_data().")
		dmoz <- read.csv('dmoz_domain_cateory.csv', header =F)
	}

	names(dmoz) <- c("hostname", "category")

	# Match
	domain_cat$dmoz_category <- dmoz$category[match(c_domains, dmoz$hostname)]
	domain_cat
}
