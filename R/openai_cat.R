#' Get Category from OpenAI
#'
#' Infers a category from the domain name with an OpenAI model through [llm_cat()].
#' No page content is fetched. The answer reflects the provider's knowledge and the
#' domain name, not a verified observation of the current website.
#'
#' @inheritParams llm_cat
#' @param api_key OpenAI API key. If not provided, looks for the `OPENAI_API_KEY`
#'   environment variable
#' @param model OpenAI model to use (default: "gpt-6-luna" for cost efficiency)
#' @param base_url API endpoint; `NULL` uses OpenAI's. Set it for an OpenAI-compatible
#'   gateway.
#'
#' @return A tibble following [classification_results], including provider failures and
#'   model identity.
#'
#' @export
#' @seealso [llm_cat()] for any ellmer provider and the parallel and batch modes.
#' @examples \dontrun{
#' openai_cat(domains) # batch job, about half price, resumable
#' openai_cat(domains, state_file = "openai-batch.json", wait = FALSE)
#' openai_cat(c("google.com", "facebook.com"), mode = "parallel")
#' openai_cat("google.com", categories = c("search", "social", "ecommerce", "news", "other"))
#' }
openai_cat <- function(domains, api_key = NULL, categories = NULL, model = "gpt-6-luna",
                       mode = c("batch", "parallel", "sequential"), state_file = NULL,
                       max_active = 10, rpm = 500, wait = TRUE, base_url = NULL) {
  validate_domains(domains)
  validate_model(model)
  if (!length(domains)) {
    return(classification_result(domains, "openai", "domain_name"))
  }
  key <- get_api_key(api_key, "OPENAI_API_KEY", "OpenAI")
  chat <- ellmer::chat_openai(
    model = model, credentials = function() key,
    base_url = base_url %||% "https://api.openai.com/v1",
    # Reasoning adds cost and nothing to a one-word label.
    params = ellmer::params(max_tokens = 64, reasoning_effort = "none"),
    echo = "none"
  )
  llm_cat(domains, chat, categories,
    mode = mode, state_file = state_file, max_active = max_active, rpm = rpm, wait = wait
  )
}
