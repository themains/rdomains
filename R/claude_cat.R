#' Get Category from Anthropic Claude
#'
#' Infers a category from the domain name with a Claude model through [llm_cat()].
#' No page content is fetched. The answer reflects the provider's knowledge and the
#' domain name, not a verified observation of the current website.
#'
#' @inheritParams llm_cat
#' @param api_key Anthropic API key. If not provided, looks for the
#'   `ANTHROPIC_API_KEY` or `CLAUDE_API_KEY` environment variable
#' @param model Claude model to use (default: "claude-haiku-5-5" for cost efficiency)
#' @param base_url API endpoint; `NULL` uses Anthropic's.
#'
#' @return A tibble following [classification_results], including provider failures and
#'   model identity.
#'
#' @export
#' @seealso [llm_cat()] for any ellmer provider and the parallel and batch modes.
#' @examples \dontrun{
#' claude_cat("google.com")
#' claude_cat(c("google.com", "facebook.com"), mode = "parallel")
#' claude_cat("google.com", categories = c("search", "social", "ecommerce", "news", "other"))
#' }
claude_cat <- function(domains, api_key = NULL, categories = NULL, model = "claude-haiku-5-5",
                       mode = c("batch", "parallel", "sequential"), state_file = NULL,
                       max_active = 10, rpm = 500, wait = TRUE, base_url = NULL) {
  validate_domains(domains)
  validate_model(model)
  if (!length(domains)) {
    return(classification_result(domains, "anthropic", "domain_name"))
  }
  key <- get_api_key(api_key, c("ANTHROPIC_API_KEY", "CLAUDE_API_KEY"), "Anthropic")
  chat <- ellmer::chat_anthropic(
    model = model, credentials = function() key, base_url = base_url,
    params = ellmer::params(max_tokens = 64), echo = "none"
  )
  llm_cat(domains, chat, categories,
    mode = mode, state_file = state_file, max_active = max_active, rpm = rpm, wait = wait
  )
}
