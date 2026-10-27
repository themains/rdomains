#' Probability that Domain Hosts Adult Content Based on features of Domain Name and Suffix alone.
#'
#' Uses a historical ML model that uses keywords in the domain name
#' and suffix to predict probability that the domain hosts adult content. For
#' more information see \url{https://github.com/themains/keyword_porn}
#'
#' The bundled model artifact has not changed since November 2017. Its probabilities
#' have not been validated on current domains. It uses only the name and suffix, not
#' page content; use [pie_cat()] for content-based classification. Feature encoding
#' remains the training-era encoding rather than silently changing a fitted model.
#'
#' @param domains required; string; vector of domain names
#'
#' @return A tibble with input identity, `p_adult`, model identity and artifact date.
#'
#' @export
#' @examples \dontrun{
#' adult_name_probability("http://www.google.com")
#' }
adult_name_probability <- function(domains) {
  validate_domains(domains)
  c_domains <- clean_domains(domains)

  if (!length(domains)) {
    return(tibble(
      input_id = integer(), input = character(),
      domain_name = character(
      ), p_adult = numeric(), model_id = character(), model_last_updated = character()
    ))
  }
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
    type = "response"
  )[, 1]

  tibble(
    input_id = seq_along(domains), input = domains, domain_name = c_domains,
    p_adult = p_adult,
    model_id = "rdomains/glm_shalla",
    model_last_updated = "2017-11-10"
  )
}
