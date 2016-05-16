#' Get Category Based on Domain Name, Suffix 
#'
#' Uses a validated ML model that uses keywords in the domain name
#' and suffix to predict category of content hosted by the domain. 
#' Currently only supports classification of pornographic content.
#'
#' @param domains vector of domain names
#' 
#' @return data.frame with original list and content category of the domain
#' @export
#' @examples 
#' name_suffix_cat(domains="http://www.google.com")
#' 

name_suffix_cat <- function(domains=NULL) {

	coefs <- dimnames(glm_shalla$glmnet.fit$beta)[[1]]

	# Nuke leading and trailing spaces
	c_domains  <- gsub("^ *| *$", "", domains)

	# nuke leading http://
	c_domains  <- gsub("^http://", "", c_domains)

	# nuke leading www.
	c_domains  <- gsub("^www.", "", c_domains)

	# Initialize results 
	res_df <- data.frame(domain_name=c_domains, category=NA)

	# Initialize feature df
	features  <- setNames(data.frame(matrix(ncol = length(coefs), nrow = length(domains))), coefs)

	# length
	for (j in 1:60) {
		features[, j] <- grepl(coefs[j], c_domains)
	}

	# num 
	features$num <- grepl("^[0-9]*.[0-9]*.[0-9]*.[0-9]", c_domains)

	# suffix
	split_url  <- suffix_extract(c_domains)
	suffixes   <- split_url$suffix[match(res_df$domain_name, split_url$host)]

	for(t in 62:length(coefs)) {
	  features[, t] <- grepl(coefs[t], suffixes)
	}

	# Predict
	res_df$category   <- c(predict.cv.glmnet(glm_shalla, as.matrix(features*1), s = "lambda.min", type="response"))

	res_df
}
