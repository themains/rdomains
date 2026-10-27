#' Classify Domain Using OpenAI (Internal Helper)
#'
#' @param domain single domain name
#' @param categories allowed categories
#' @param model OpenAI model name
#' @param api_key API key
#' @keywords internal
#' @noRd
classify_domain_openai <- function(domain, categories, model, api_key) {
  req <- request("https://api.openai.com/v1/chat/completions") |>
    req_headers_redacted(Authorization = paste("Bearer", api_key)) |>
    req_body_json(list(
      model = model, messages = list(list(
        role = "user",
        content = build_categorization_prompt(domain, categories)
      )),
      max_completion_tokens = 256, reasoning_effort = "none"
    ), auto_unbox = TRUE)
  llm_response(req, categories, function(body) {
    choice <- body$choices[[1]]
    if (!identical(choice$finish_reason, "stop")) {
      return(NA_character_)
    }
    choice$message$content
  }, model)
}

#' Get Category from OpenAI
#'
#' Infers a category from the domain name using OpenAI's chat completion API.
#' No page content is fetched. The answer reflects the provider's knowledge and the
#' domain name, not a verified observation of the current website.
#'
#' @param domains vector of domain names
#' @param api_key OpenAI API key. If not provided, looks for OPENAI_API_KEY environment variable
#' @param categories vector of categories to classify into. If NULL, uses default web categories
#' @param model OpenAI model to use (default: "gpt-6-luna" for cost efficiency)
#' @param delay delay in seconds between API calls (default: 0.5)
#'
#' @return A tibble following [classification_results], including provider failures and model
#' identity.
#'
#' @export
#' @examples \dontrun{
#' openai_cat("google.com")
#' openai_cat(c("google.com", "facebook.com"))
#' openai_cat("google.com", categories = c("search", "social", "ecommerce", "news", "other"))
#' }
openai_cat <- function(domains, api_key = NULL, categories = NULL,
                       model = "gpt-6-luna", delay = 0.5) {
  llm_cat(
    domains, api_key, categories, model, delay, "openai",
    "OPENAI_API_KEY", classify_domain_openai
  )
}
