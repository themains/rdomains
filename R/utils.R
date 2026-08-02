#' Clean and Normalize Domain Names
#'
#' @param domains character vector of domain names
#' @return character vector of cleaned domains
#' @keywords internal
#' @noRd
clean_domains <- function(domains) {
  # tolower(): host names are case-insensitive, and every list this package looks up is
  # stored lower-cased (exactly 1 row in the 2,488,259-row DMOZ table is not). Without
  # it "Example.com" and "example.com" resolve differently.
  domains |>
    str_trim() |>
    tolower() |>
    str_remove("^https?://") |>
    str_remove("^www\\.") |>
    str_remove("/.*$")
}

#' Validate Domain Input
#'
#' @param domains domain input to validate
#' @param arg_name name of argument for error messages
#' @keywords internal
#' @noRd
validate_domains <- function(domains, arg_name = "domains") {
  if (is.null(domains)) {
    cli_abort("{.arg {arg_name}} must not be NULL")
  }

  assert_character(
    domains,
    min.len = 1,
    any.missing = FALSE,
    .var.name = arg_name
  )

  if (any(str_trim(domains) == "")) {
    cli_abort("{.arg {arg_name}} contains empty strings")
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
    assert_character(api_key, len = 1)
    return(api_key)
  }

  for (var in env_vars) {
    key <- Sys.getenv(var)
    if (!identical(key, "")) {
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
