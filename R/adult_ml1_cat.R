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

  validate_domains(domains)
  c_domains <- clean_domains(domains)

  coefs <- dimnames(glm_shalla$glmnet.fit$beta)[[1]]

  features <- spMatrix(length(c_domains), length(coefs))

  for (j in 1:60) {
    tfs <- grepl(coefs[j], c_domains)
    features[, j] <- as(tfs, "sparseVector")
  }

  tfs <- grepl("^[0-9]*.[0-9]*.[0-9]*.[0-9]", c_domains)
  features[, 61] <- as(tfs, "sparseVector")

  split_url <- suffix_extract(c_domains)
  suffixes <- split_url$suffix[match(c_domains, split_url$host)]

  for (t in 62:length(coefs)) {
    tfs <- grepl(coefs[t], suffixes)
    features[, t] <- as(tfs, "sparseVector")
  }

  p_adult <- predict(glm_shalla, features,
                     s = "lambda.min",
                     type = "response")[, 1]

  tibble(
    domain_name = c_domains,
    p_adult = p_adult
  )
}
