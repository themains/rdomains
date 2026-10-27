#' Clean and Normalize Domain Names
#'
#' @param domains character vector of domain names
#' @return character vector of cleaned domains
#' @keywords internal
#' @noRd
clean_domains <- function(domains) {
  vapply(domains, function(value) {
    parsed <- tryCatch(url_parse(request_url(value)), error = function(e) NULL)
    host <- parsed$hostname
    if (is.null(host) || !nzchar(host)) {
      return(tolower(trimws(value)))
    }
    sub("^www\\.", "", sub("\\.$", "", tolower(host)))
  }, character(1), USE.NAMES = FALSE)
}

#' Validate Domain Input
#'
#' @param domains domain input to validate
#' @param arg_name name of argument for error messages
#' @keywords internal
#' @noRd
validate_domains <- function(domains, arg_name = "domains") {
  if (is.null(domains)) {
    cli_abort("{.arg {arg_name}} must not be NULL", class = "rdomains_invalid_input")
  }

  if (!is.character(domains) || anyNA(domains)) {
    cli_abort("{.arg {arg_name}} must be a character vector without missing values.",
              class = "rdomains_invalid_input")
  }

  if (any(str_trim(domains) == "")) {
    cli_abort("{.arg {arg_name}} contains empty strings", class = "rdomains_invalid_input")
  }

  invisible(domains)
}

#' Validate Data File Path
#'
#' @param file_path path to file
#' @param default_name default filename to look for
#' @param download_function name of function to download data
#' @keywords internal
#' @noRd
validate_data_file <- function(file_path = NULL,
                               default_name,
                               download_function) {
  if (!is.null(file_path)) {
    assert_character(file_path, len = 1)
    if (!file.exists(file_path)) {
      cli_abort(c(
        "File not found: {.file {file_path}}",
        "i" = "Download data using {.fn {download_function}}"
      ))
    }
    return(file_path)
  }

  if (!file.exists(default_name)) {
    cli_abort(c(
      "Data file not found: {.file {default_name}}",
      "i" = "Download data using {.fn {download_function}}",
      "i" = "Or specify custom path with {.arg use_file}"
    ))
  }

  default_name
}

#' Get and Validate API Key
#'
#' @param api_key user-provided API key
#' @param env_vars character vector of environment variable names
#' @param service_name name of service for error messages
#' @keywords internal
#' @noRd
get_api_key <- function(api_key = NULL, env_vars, service_name) {
  if (!is.null(api_key)) {
    assert_character(api_key, len = 1, any.missing = FALSE, min.chars = 1)
    if (!nzchar(trimws(api_key))) cli_abort("{.arg api_key} must not be blank")
    return(api_key)
  }

  for (var in env_vars) {
    key <- Sys.getenv(var)
    if (nzchar(trimws(key))) {
      return(key)
    }
  }

  cli_abort(c(
    "{service_name} API key not found",
    "i" = "Provide via {.arg api_key} parameter",
    "i" = "Or set environment variable: {.envvar {env_vars[1]}}"
  ))
}

#' Build LLM Categorization Prompt
#'
#' @param domain domain name to classify
#' @param categories allowed categories
#' @keywords internal
#' @noRd
build_categorization_prompt <- function(domain, categories) {
  glue(
    "Classify the website domain '{domain}' into exactly one of these categories: ",
    "{paste(categories, collapse = ', ')}. ",
    "Consider what type of content this domain likely hosts. ",
    "Respond with only the category name, no explanation or punctuation."
  )
}

#' Apply Rate Limiting
#'
#' @param i current iteration
#' @param total total iterations
#' @param rate_limit delay in seconds
#' @keywords internal
#' @noRd
apply_rate_limit <- function(i, total, rate_limit) {
  if (i < total && rate_limit > 0) {
    Sys.sleep(rate_limit)
  }
}

#' Validate a finite scalar within a closed interval
#' @keywords internal
#' @noRd
validate_number <- function(x, name, lower = 0, upper = Inf, integer = FALSE) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) ||
        x < lower || x > upper || (integer && x != floor(x))) {
    kind <- if (integer) "integer" else "number"
    cli_abort(paste0("{.arg {name}} must be a finite ", kind, " between {lower} and {upper}."))
  }
  invisible(x)
}

#' Validate a requested category vocabulary and request controls
#' @keywords internal
#' @noRd
validate_llm_options <- function(categories, model, delay) {
  assert_character(categories, min.len = 1, any.missing = FALSE, min.chars = 1)
  if (any(!nzchar(trimws(categories))) || anyDuplicated(categories)) {
    cli_abort("{.arg categories} must contain distinct nonblank names.")
  }
  assert_character(model, len = 1, any.missing = FALSE, min.chars = 1)
  if (!nzchar(trimws(model))) cli_abort("{.arg model} must not be blank.")
  validate_number(delay, "delay")
}

#' Reject a provider response that is not a requested category
#' @keywords internal
#' @noRd
checked_category <- function(value, categories) {
  if (!is.character(value) || length(value) != 1L || is.na(value) ||
        !trimws(value) %in% categories) {
    cli_warn("The provider did not return a category in the requested vocabulary.")
    return(NA_character_)
  }
  trimws(value)
}
