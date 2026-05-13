#' Classify Domain Using Claude (Internal Helper)
#'
#' @param domain single domain name
#' @param categories allowed categories
#' @param model Claude model name
#' @param api_key API key
#' @keywords internal
#' @noRd
classify_domain_claude <- function(domain, categories, model, api_key) {
  prompt <- build_categorization_prompt(domain, categories)

  request_body <- list(
    model = model,
    max_tokens = 50,
    messages = list(
      list(role = "user", content = prompt)
    ),
    temperature = 0.1
  )

  result <- tryCatch({
    response <- httr::POST(
      url = "https://api.anthropic.com/v1/messages",
      httr::add_headers(
        "x-api-key" = api_key,
        "Content-Type" = "application/json",
        "anthropic-version" = "2023-06-01"
      ),
      body = jsonlite::toJSON(request_body, auto_unbox = TRUE),
      encode = "raw"
    )

    if (status_code(response) == 200) {
      result <- fromJSON(content(response, "text", encoding = "UTF-8"))
      category <- str_trim(result$content[1, ]$text)

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

  tibble(domain_name = domain, claude_category = result)
}

#' Get Category from Anthropic Claude
#'
#' Fetches category of content hosted by a domain using Anthropic's Claude API.
#' The function uses Claude models to classify domains into specified categories.
#'
#' @param domains vector of domain names
#' @param api_key Anthropic API key. If not provided, looks for ANTHROPIC_API_KEY or CLAUDE_API_KEY environment variable
#' @param categories vector of categories to classify into. If NULL, uses default web categories
#' @param model Claude model to use (default: "claude-3-haiku-20240307" for cost efficiency)
#' @param rate_limit delay in seconds between API calls (default: 0.5)
#'
#' @return data.frame with original list and content category of the domain
#'
#' @export
#' @examples \dontrun{
#' claude_cat("google.com")
#' claude_cat(c("google.com", "facebook.com"))
#' claude_cat("google.com", categories = c("search", "social", "ecommerce", "news", "other"))
#' }

claude_cat <- function(domains = NULL, api_key = NULL, categories = NULL,
                      model = "claude-3-haiku-20240307", rate_limit = 0.5) {

  validate_domains(domains)
  c_domains <- clean_domains(domains)

  if (is.null(categories)) {
    categories <- c("news", "shopping", "social", "adult", "gambling", "technology",
                   "finance", "education", "entertainment", "business", "other")
  }

  api_key <- get_api_key(api_key, c("ANTHROPIC_API_KEY", "CLAUDE_API_KEY"), "Anthropic")

  results <- map_df(
    seq_along(c_domains),
    function(i) {
      result <- classify_domain_claude(c_domains[i], categories, model, api_key)
      apply_rate_limit(i, length(c_domains), rate_limit)
      result
    }
  )

  as.data.frame(results)
}
