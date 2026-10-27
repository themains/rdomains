#' Default categories for domain-name inference
#' @return A character vector of category names shared by the LLM adapters.
#' @export
#' @examples
#' web_categories()
web_categories <- function() {
  c(
    "news", "shopping", "social", "adult", "gambling", "technology",
    "finance", "education", "entertainment", "business", "other"
  )
}

#' Execute one provider request while preserving operational failures
#' @keywords internal
#' @noRd
llm_response <- function(req, categories, parser, model) {
  result <- list(
    category = NA_character_, error_code = NA_character_,
    http_status = NA_integer_, model_id = model, message = NA_character_
  )
  tryCatch(
    {
      response <- req |>
        req_error(is_error = function(resp) FALSE) |>
        req_timeout(30) |>
        req_perform()
      status <- resp_status(response)
      result$http_status <- as.integer(status)
      if (status != 200L) {
        result$error_code <- provider_error_code(status)
        return(result)
      }
      body <- fromJSON(resp_body_string(response), simplifyVector = FALSE)
      parsed <- parser(body)
      if (!is.character(parsed) || length(parsed) != 1L || is.na(parsed) ||
            !trimws(parsed) %in% categories) {
        result$error_code <- "invalid_response"
      } else {
        result$category <- trimws(parsed)
      }
      if (is.character(body$model) && length(body$model) == 1L && !is.na(body$model)) {
        result$model_id <- body$model
      }
      result
    },
    error = function(e) {
      result$error_code <- if (!is.na(result$http_status) && result$http_status == 200L) {
        "invalid_response"
      } else {
        "service_error"
      }
      result$message <- conditionMessage(e)
      result
    }
  )
}

#' Share batching and result construction without sharing provider protocols
#' @keywords internal
#' @noRd
llm_cat <- function(domains, api_key, categories, model, delay, provider, env_vars, classify) {
  validate_domains(domains)
  categories <- categories %||% web_categories()
  validate_llm_options(categories, model, delay)
  result <- classification_result(domains, provider, "domain_name")
  result$model_id <- rep(model, length(domains))
  if (!length(domains)) {
    return(result)
  }
  key <- get_api_key(api_key, env_vars, provider)
  for (i in seq_along(domains)) {
    response <- classify(result$domain_name[i], categories, model, key)
    if (!is.na(response$category)) {
      result <- set_result_labels(result, i, label_table(response$category))
    } else {
      result$status[i] <- "failed"
    }
    result$error_code[i] <- response$error_code
    result$retryable[i] <- is_retryable(response$error_code)
    result$http_status[i] <- response$http_status
    result$model_id[i] <- response$model_id
    result$source_fetched_at[i] <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    result$details[[i]] <- list(
      message = response$message, categories = categories,
      requested_model = model
    )
    apply_rate_limit(i, length(domains), delay)
  }
  result
}
