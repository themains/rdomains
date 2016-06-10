#' @title rdomains: Classify Domains by their Content
#' 
#' @name rdomains-package
#' @aliases rdomains
#'
#' @description Want to know what kind of content is carried on a domain?
#' Get the results quickly using rdomains. The package provides access to virustotal
#' API, shalla, and validated ML model based off shallalist data to predict content
#' of a domain.
#'
#' To learn how to use rdomains, see this vignette: \url{vignettes/rdomains.html}. 
#' 
#' @importFrom urltools suffix_extract
#' @importFrom Matrix Matrix spMatrix sparseVector
#' @importFrom glmnet predict.cv.glmnet
#' @importFrom stats setNames
#' @importFrom methods as
#' @importFrom utils read.table URLencode untar unzip read.csv write.csv 
#' @importFrom curl curl_download
#' @importFrom XML readHTMLTable
#' @importFrom RSelenium remoteDriver checkForServer startServer
#' @importFrom virustotal set_key domain_report
#' @importFrom aws.alexa set_secret_key url_info
#' 
#' @docType package
#' @author Gaurav Sood
NULL
#' Probability that Domain Hosts Adult Content Based on features of Domain Name and Suffix alone. 
#'
#' Uses a validated ML model that uses keywords in the domain name
#' and suffix to predict probability that the domain hosts adult content. 
#' See \url{https://github.com/soodoku/domain_classifier/tree/master/domain_name} for details. 
#'
#' @param domains vector of domain names
#' 
#' @return data.frame with original list and content category of the domain
#' @export
#' @examples 
#' adult_ml1_cat(domains="http://www.google.com")
#' 

adult_ml1_cat <- function(domains=NULL) {

	coefs <- dimnames(glm_shalla$glmnet.fit$beta)[[1]]

	# Nuke leading and trailing spaces
	c_domains  <- gsub("^ *| *$", "", domains)

	# nuke leading http://
	c_domains  <- gsub("^http://", "", c_domains)

	# nuke leading www.
	c_domains  <- gsub("^www.", "", c_domains)

	# Initialize results 
	res_df <- data.frame(domain_name=c_domains, p_adult=NA)

	# Initialize feature df
	features  <- spMatrix(nrow(res_df), length(coefs)) # list() # setNames(data.frame(matrix(ncol = length(coefs), nrow = length(domains))), coefs)

	# length
	for (j in 1:60) {
	  tfs           <- grepl(coefs[j], c_domains)
      features[,j]  <- as(tfs, "sparseVector")

	}

	# num 
	tfs <- grepl("^[0-9]*.[0-9]*.[0-9]*.[0-9]", c_domains)
    features[,61] <- as(tfs, "sparseVector")

	# suffix
	split_url  <- suffix_extract(c_domains)
	suffixes   <- split_url$suffix[match(res_df$domain_name, split_url$host)]

	for(t in 62:length(coefs)) {
	  tfs          <- grepl(coefs[t], suffixes)
      features[,t] <- as(tfs, "sparseVector")
	}

	# Predict
	res_df$category   <- predict.cv.glmnet(glm_shalla, features, s = "lambda.min", type="response")

	res_df
}
