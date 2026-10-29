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

#' Classify domain names with a language model
#'
#' Sends each distinct domain name to the model behind `chat` and constrains the reply
#' to one of `categories` through the provider's structured-output API, so the answer
#' is always in the requested vocabulary or recorded as a failure. Any provider that
#' ellmer supports works: OpenAI, Anthropic, Google Gemini, Ollama, AWS Bedrock and
#' others. No page content is fetched; the answer reflects the model's knowledge of the
#' name, not a verified observation of the current website. [openai_cat()] and
#' [claude_cat()] are thin wrappers that build the chat for you.
#'
#' The default, `mode = "batch"`, submits every prompt to the provider's batch API
#' (OpenAI, Anthropic, Google Gemini and Groq): roughly half the price, results within
#' 24 hours and usually much sooner, and a job that survives interruption because
#' `state_file` records it. When `state_file` is `NULL` the file is named from a hash of
#' the provider, model and prompts under [rdomains_cache_dir()], so
#' calling again with the same arguments resumes or collects the job instead of paying
#' twice; the path is reported in `details` and in a message. Providers without a batch
#' API are refused rather than emulated; pass `mode = "parallel"` for them.
#' `"parallel"` keeps up to `max_active` requests in flight under a ceiling of `rpm`
#' requests per minute and answers in seconds. `"sequential"` sends one request at a
#' time. In every mode ellmer retries transient failures (HTTP 429 and 503) up to three
#' times before a row is reported as failed.
#'
#' @param domains character vector of domain names or URLs
#' @param chat an ellmer chat object, for example
#'   `ellmer::chat_openai(model = "gpt-6-luna")`
#' @param categories vector of categories to classify into. If NULL, uses
#'   [web_categories()]
#' @param mode one of `"batch"` (default), `"parallel"` or `"sequential"`
#' @param state_file batch mode only: path of a `.json` file that records the job.
#'   `NULL` derives one from the provider, model and prompts under the user cache
#'   directory. Not allowed in the other modes.
#' @param max_active maximum simultaneous requests in parallel mode
#' @param rpm requests per minute allowed in parallel mode
#' @param wait batch mode only: wait for the job to complete (`TRUE`) or return at once.
#'   Rows whose results are not yet available carry `error_code = "batch_pending"` and
#'   are retryable; call again with the same `state_file` to collect them.
#'
#' @return A tibble following [classification_results]. `provider` is ellmer's provider
#'   name in lower case, `model_id` the requested model. `details` holds the category
#'   vocabulary, the mode, the state file, per-request token counts and ellmer's cost
#'   estimate. `http_status` is `NA` because ellmer does not expose the response of a
#'   successful request.
#'
#' @export
#' @examples \dontrun{
#' chat <- ellmer::chat_openai(model = "gpt-6-luna")
#' llm_cat(domains, chat) # batch job, resumable
#' llm_cat(domains, chat, state_file = "domains-batch.json", wait = FALSE)
#' llm_cat(c("nytimes.com", "amazon.com"), chat, mode = "parallel")
#' }
llm_cat <- function(domains, chat, categories = NULL,
                    mode = c("batch", "parallel", "sequential"), state_file = NULL,
                    max_active = 10, rpm = 500, wait = TRUE) {
  validate_domains(domains)
  mode <- arg_match(mode)
  categories <- categories %||% web_categories()
  validate_categories(categories)
  validate_number(max_active, "max_active", lower = 1, integer = TRUE)
  validate_number(rpm, "rpm", lower = 1)
  assert_logical(wait, len = 1, any.missing = FALSE)
  if (mode == "batch") {
    if (!is.null(state_file)) {
      assert_character(state_file, len = 1, any.missing = FALSE, min.chars = 1)
      if (!grepl("\\.json$", state_file)) {
        cli_abort("{.arg state_file} must be a path ending in {.file .json}.")
      }
    }
  } else if (!is.null(state_file)) {
    cli_abort("{.arg state_file} applies only to {.code mode = \"batch\"}.")
  }
  if (!inherits(chat, "Chat")) {
    cli_abort(c(
      "{.arg chat} must be an ellmer chat object.",
      "i" = "For example {.code ellmer::chat_openai(model = \"gpt-6-luna\")}."
    ))
  }
  provider <- tolower(chat$get_provider()@name)
  model <- chat$get_model()
  result <- classification_result(domains, provider, "domain_name")
  result$model_id <- rep(model, length(domains))
  if (!length(domains)) {
    return(result)
  }

  # One request per distinct host: repeated inputs share the answer and the cost.
  # Sorted, so the same set of hosts in any order is the same batch job.
  hosts <- sort(unique(result$domain_name))
  prompts <- lapply(hosts, build_categorization_prompt, categories = categories)
  type <- ellmer::type_object(
    category = ellmer::type_enum(categories, "The single best category for this domain.")
  )
  out <- if (mode == "batch") {
    if (is.null(state_file)) {
      state_file <- llm_state_file(provider, model, prompts)
      cli_inform(
        "Batch job recorded in {.file {state_file}}; rerun the same call to resume.",
        class = "rdomains_batch_state"
      )
    }
    tryCatch(
      ellmer::batch_chat_structured(chat, prompts,
        path = state_file, type = type, wait = wait,
        convert = TRUE, include_tokens = TRUE, include_cost = TRUE
      ),
      error = function(e) {
        # ellmer's own refusal for providers without a batch API; emulating one would
        # hide the price and turnaround difference, so refuse the same way.
        if (grepl("not currently supported", conditionMessage(e), fixed = TRUE)) {
          cli_abort(c(
            "{.val {provider}} has no batch API.",
            "i" = "Use {.code mode = \"parallel\"} for this provider."
          ), class = "rdomains_invalid_input")
        }
        llm_failed_rows(length(prompts), e)
      }
    )
  } else {
    llm_run_prompts(prompts, function(batch) {
      # ellmer warns about every failed request and unparseable reply; each becomes a
      # structured outcome below, so the warnings would only repeat the result.
      suppressWarnings(ellmer::parallel_chat_structured(chat, batch,
        type = type, convert = TRUE, include_tokens = TRUE, include_cost = TRUE,
        max_active = if (mode == "sequential") 1L else max_active, rpm = rpm,
        on_error = "continue"
      ))
    })
  }
  outcomes <- llm_outcomes(out, length(hosts), categories)

  idx <- match(result$domain_name, hosts)
  now <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  for (i in seq_along(domains)) {
    outcome <- outcomes[[idx[i]]]
    if (!is.na(outcome$category)) {
      result <- set_result_labels(result, i, label_table(outcome$category))
    } else {
      result$status[i] <- "failed"
    }
    result$error_code[i] <- outcome$error_code
    result$retryable[i] <- is_retryable(outcome$error_code)
    result$http_status[i] <- outcome$http_status
    result$source_fetched_at[i] <- now
    result$details[[i]] <- list(
      message = outcome$message, categories = categories, requested_model = model,
      mode = mode, state_file = state_file,
      input_tokens = outcome$input_tokens, output_tokens = outcome$output_tokens,
      cost = outcome$cost
    )
  }
  result
}

# A batch job is identified by what was asked of whom, so the same call always finds
# the same state file and a different vocabulary or model never collects another job.
llm_state_file <- function(provider, model, prompts) {
  dir <- file.path(rdomains_cache_dir(), "llm-batches")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  file.path(dir, paste0(rlang::hash(list(provider, model, prompts)), ".json"))
}

#' Run prompts so that one unparseable reply fails only its own row
#'
#' ellmer raises while parsing a 200 response whose body is not the JSON it asked for,
#' before its per-request `.error` column exists, which would abort the whole call and
#' discard every other answer. On an error the prompts are split in half and each half
#' run again, down to the single prompt that caused it. Successful halves pay for their
#' requests again, at most once per level of the split.
#'
#' @keywords internal
#' @noRd
llm_run_prompts <- function(prompts, run) {
  out <- tryCatch(run(prompts), error = function(e) e)
  if (!inherits(out, "error")) {
    return(llm_rows(out))
  }
  if (length(prompts) == 1L) {
    return(llm_failed_rows(1L, out))
  }
  half <- seq_len(length(prompts) %/% 2)
  bind_rows(llm_run_prompts(prompts[half], run), llm_run_prompts(prompts[-half], run))
}

#' Normalise ellmer's structured tibble so halves can be bound
#' @keywords internal
#' @noRd
llm_rows <- function(out) {
  if (!is.data.frame(out)) {
    return(out)
  }
  out$category <- as.character(out$category)
  if (!".error" %in% names(out)) {
    out$.error <- vector("list", nrow(out))
  }
  out
}

#' Rows for prompts whose run raised instead of returning a result
#' @keywords internal
#' @noRd
llm_failed_rows <- function(n, condition) {
  tibble(
    category = rep(NA_character_, n), input_tokens = rep(NA_integer_, n),
    output_tokens = rep(NA_integer_, n), cost = rep(NA_real_, n),
    .error = replicate(n, condition, simplify = FALSE)
  )
}

#' Turn ellmer's structured result into one outcome per prompt
#'
#' `out` is what `parallel_chat_structured()` or `batch_chat_structured()` returned:
#' a data frame with one row per prompt, a `.error` list-column when any request
#' failed, and `NULL` for a batch that is not complete.
#'
#' @keywords internal
#' @noRd
llm_outcomes <- function(out, n, categories) {
  blank <- function(code, message, http_status = NA_integer_, tokens = c(NA_integer_, NA_integer_),
                    cost = NA_real_) {
    list(
      category = NA_character_, error_code = code, http_status = http_status,
      message = message, input_tokens = tokens[[1]], output_tokens = tokens[[2]], cost = cost
    )
  }
  if (is.null(out)) {
    pending <- blank("batch_pending", "Batch not complete; call again with the same state_file.")
    return(replicate(n, pending, simplify = FALSE))
  }
  if (!is.data.frame(out) || nrow(out) != n) {
    cli_abort("ellmer returned {nrow(out)} row{?s} for {n} prompt{?s}.", .internal = TRUE)
  }
  tokens <- function(i) {
    c(
      as.integer(out$input_tokens[i] %||% NA_integer_),
      as.integer(out$output_tokens[i] %||% NA_integer_)
    )
  }
  cost <- function(i) as.numeric(out$cost[i] %||% NA_real_)
  lapply(seq_len(n), function(i) {
    err <- if (".error" %in% names(out)) out$.error[[i]] else NULL
    if (!is.null(err)) {
      status <- llm_error_status(err)
      code <- if (!is.na(status)) {
        provider_error_code(status)
      } else if (inherits(err, "httr2_error")) {
        "service_error"
      } else {
        # Not an HTTP failure: the provider answered and ellmer could not parse it.
        "invalid_response"
      }
      return(blank(code, conditionMessage(err), status, tokens(i), cost(i)))
    }
    category <- as.character(out$category[i])
    if (is.na(category) || !category %in% categories) {
      return(blank(
        "invalid_response", "The model did not return a category in the requested vocabulary.",
        NA_integer_, tokens(i), cost(i)
      ))
    }
    list(
      category = category, error_code = NA_character_, http_status = NA_integer_,
      message = NA_character_, input_tokens = tokens(i)[[1]], output_tokens = tokens(i)[[2]],
      cost = cost(i)
    )
  })
}

#' HTTP status carried by an httr2 error condition, or NA
#' @keywords internal
#' @noRd
llm_error_status <- function(err) {
  resp <- err$resp
  if (is.null(resp)) {
    return(NA_integer_)
  }
  tryCatch(as.integer(httr2::resp_status(resp)), error = function(e) NA_integer_)
}
