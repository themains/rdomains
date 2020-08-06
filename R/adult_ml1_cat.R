#' Probability that Domain Hosts Adult Content Based on features of Domain Name and Suffix alone.
#'
#' Uses a validated ML model that uses keywords in the domain name
#' and suffix to predict probability that the domain hosts adult content. For
#' more information see \url{https://github.com/themains/keyword_porn}
#'
#' @param domains required; string; vector of domain names
#'
#' @return data.frame with original list and content category of the domains
#'
#' @export
#' @examples \dontrun{
#' adult_ml1_cat("http://www.google.com")
#' }

adult_ml1_cat <- function(domains = NULL) {

  if (!is.character(domains)) {
    stop("Please provide a valid vector of domain names.")
  }

  coefs <- dimnames(glm_shalla$glmnet.fit$beta)[[1]]

  # Nuke leading and trailing spaces
  c_domains  <- gsub("^ *| *$", "", domains)

  # nuke leading http://
  c_domains  <- gsub("^http://", "", c_domains)

  # nuke leading www.
  c_domains  <- gsub("^www.", "", c_domains)

  # Initialize results
  res_df <- data.frame(domain_name = c_domains, p_adult = NA)

  # Initialize feature df
  features  <- spMatrix(nrow(res_df), length(coefs))

  # length
  for (j in 1:60) {
    tfs           <- grepl(coefs[j], c_domains)
    features[, j]  <- as(tfs, "sparseVector")
  }

  # num
  tfs <- grepl("^[0-9]*.[0-9]*.[0-9]*.[0-9]", c_domains)
  features[, 61] <- as(tfs, "sparseVector")

  # suffix
  split_url  <- suffix_extract(c_domains)
  suffixes   <- split_url$suffix[match(res_df$domain_name, split_url$host)]

  for (t in 62:length(coefs)) {
    tfs          <- grepl(coefs[t], suffixes)
    features[, t] <- as(tfs, "sparseVector")
  }

  # Predict
  res_df$p_adult  <- predict(glm_shalla, features,
                                         s = "lambda.min",
                                         type = "response")[, 1]

  res_df
}
