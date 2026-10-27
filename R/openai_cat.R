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
    max_completion_tokens = 256,
    reasoning_effort = "none"
  )

  result <- tryCatch(
    {
      response <- request("https://api.openai.com/v1/chat/completions") |>
        req_headers_redacted(Authorization = paste("Bearer", api_key)) |>
        req_body_json(request_body, auto_unbox = TRUE) |>
        req_error(is_error = function(resp) FALSE) |>
        req_timeout(30) |>
        req_perform()

      if (resp_status(response) == 200) {
        result <- fromJSON(resp_body_string(response), simplifyVector = FALSE)
        choice <- result$choices[[1]]
        if (!identical(choice$finish_reason, "stop")) {
          cli_warn("The provider did not complete the category response.")
          return(tibble(domain_name = domain, openai_category = NA_character_))
        }
        checked_category(choice$message$content, categories)
      } else {
        cli_warn("API call failed for domain {domain} - Status: {resp_status(response)}")
        NA_character_
      }
    },
    error = function(e) {
      cli_warn(c(
        "Error processing domain: {domain}",
        "x" = e$message
      ))
      NA_character_
    }
  )

  tibble(domain_name = domain, openai_category = result)
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
                       model = "gpt-6-luna", rate_limit = 0.5) {
  validate_domains(domains)
  c_domains <- clean_domains(domains)

  if (is.null(categories)) {
    categories <- c(
      "news", "shopping", "social", "adult", "gambling", "technology",
      "finance", "education", "entertainment", "business", "other"
    )
  }

  validate_llm_options(categories, model, rate_limit)
  api_key <- get_api_key(api_key, "OPENAI_API_KEY", "OpenAI")

  map_df(
    seq_along(c_domains),
    function(i) {
      result <- classify_domain_openai(c_domains[i], categories, model, api_key)
      apply_rate_limit(i, length(c_domains), rate_limit)
      result
    }
  )
}
