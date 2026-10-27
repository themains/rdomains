#' Classify Domain Using Claude (Internal Helper)
#'
#' @param domain single domain name
#' @param categories allowed categories
#' @param model Claude model name
#' @param api_key API key
#' @keywords internal
#' @noRd
classify_domain_claude <- function(domain, categories, model, api_key) {
  req <- request("https://api.anthropic.com/v1/messages") |>
    req_headers_redacted(`x-api-key` = api_key) |>
    req_headers(`anthropic-version` = "2023-06-01") |>
    req_body_json(
      list(
        model = model, max_tokens = 256,
        messages = list(
          list(role = "user", content = build_categorization_prompt(domain, categories))
        )
      ),
      auto_unbox = TRUE
    )
  llm_response(req, categories, function(body) {
    if (!identical(body$stop_reason, "end_turn")) {
      return(NA_character_)
    }
    blocks <- Filter(function(x) identical(x$type, "text"), body$content)
    paste(vapply(blocks, function(x) x$text, character(1)), collapse = "")
  }, model)
}

#' Get Category from Anthropic Claude
#'
#' Infers a category from the domain name using Anthropic's Claude API.
#' No page content is fetched. The answer reflects the provider's knowledge and the
#' domain name, not a verified observation of the current website.
#'
#' @param domains vector of domain names
#' @param api_key Anthropic API key. If not provided, looks for the
#'   ANTHROPIC_API_KEY or CLAUDE_API_KEY environment variable
#' @param categories vector of categories to classify into. If NULL, uses default web categories
#' @param model Claude model to use (default: "claude-haiku-5-5" for cost efficiency)
#' @param delay delay in seconds between API calls (default: 0.5)
#'
#' @return A tibble following [classification_results], including provider failures and model
#' identity.
#'
#' @export
#' @examples \dontrun{
#' claude_cat("google.com")
#' claude_cat(c("google.com", "facebook.com"))
#' claude_cat("google.com", categories = c("search", "social", "ecommerce", "news", "other"))
#' }
claude_cat <- function(domains, api_key = NULL, categories = NULL,
                       model = "claude-haiku-5-5", delay = 0.5) {
  llm_cat(
    domains, api_key, categories, model, delay, "claude",
    c("ANTHROPIC_API_KEY", "CLAUDE_API_KEY"), classify_domain_claude
  )
}
