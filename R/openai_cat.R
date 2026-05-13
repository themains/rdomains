#' Classify Domain Using OpenAI (Internal Helper)
#'
#' @param domain single domain name
#' @param categories allowed categories
#' @param model OpenAI model name
#' @param api_key API key
#' @keywords internal
#' @noRd
classify_domain_openai <- function(domain, categories, model, api_key) {
  prompt <- build_categorization_prompt(domain, categories)

  request_body <- list(
    model = model,
    messages = list(
      list(role = "user", content = prompt)
    ),
    max_tokens = 50,
    temperature = 0.1
  )

  result <- tryCatch({
    response <- httr::POST(
      url = "https://api.openai.com/v1/chat/completions",
      httr::add_headers(
        "Authorization" = paste("Bearer", api_key),
        "Content-Type" = "application/json"
      ),
      body = jsonlite::toJSON(request_body, auto_unbox = TRUE),
      encode = "raw"
    )

    if (status_code(response) == 200) {
      result <- fromJSON(content(response, "text", encoding = "UTF-8"))
      category <- str_trim(result$choices[1, ]$message$content)

      if (category %in% categories) {
        category
      } else {
        "other"
      }
    } else {
      cli_warn("API call failed for domain {domain} - Status: {status_code(response)}")
      NA_character_
    }
  }, error = function(e) {
    cli_warn(c(
      "Error processing domain: {domain}",
      "x" = e$message
    ))
    NA_character_
  })

  tibble(domain_name = domain, openai_category = result)
}

#' Get Category from OpenAI
#'
#' Fetches category of content hosted by a domain using OpenAI's chat completion API.
#' The function uses GPT models to classify domains into specified categories.
#'
#' @param domains vector of domain names
#' @param api_key OpenAI API key. If not provided, looks for OPENAI_API_KEY environment variable
#' @param categories vector of categories to classify into. If NULL, uses default web categories
#' @param model OpenAI model to use (default: "gpt-4o-mini" for cost efficiency)
#' @param rate_limit delay in seconds between API calls (default: 0.5)
#'
#' @return data.frame with original list and content category of the domain
#'
#' @export
#' @examples \dontrun{
#' openai_cat("google.com")
#' openai_cat(c("google.com", "facebook.com"))
#' openai_cat("google.com", categories = c("search", "social", "ecommerce", "news", "other"))
#' }

openai_cat <- function(domains = NULL, api_key = NULL, categories = NULL,
                      model = "gpt-4o-mini", rate_limit = 0.5) {

  validate_domains(domains)
  c_domains <- clean_domains(domains)

  if (is.null(categories)) {
    categories <- c("news", "shopping", "social", "adult", "gambling", "technology",
                   "finance", "education", "entertainment", "business", "other")
  }

  api_key <- get_api_key(api_key, "OPENAI_API_KEY", "OpenAI")

  results <- map_df(
    seq_along(c_domains),
    function(i) {
      result <- classify_domain_openai(c_domains[i], categories, model, api_key)
      apply_rate_limit(i, length(c_domains), rate_limit)
      result
    }
  )

  as.data.frame(results)
}
