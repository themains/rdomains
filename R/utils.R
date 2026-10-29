#' Clean and Normalize Domain Names
#'
#' The one host normaliser: lowercase, drop scheme, userinfo, port, path, query,
#' fragment, trailing dots and a leading `www.`. Vectorised with regular expressions
#' because lookup tables run to millions of keys. Input that is not URL-shaped is
#' returned lowercased and trimmed so it can still be echoed back to the caller.
#'
#' @param domains character vector of domain names or URLs
#' @return character vector of hostnames
#' @keywords internal
#' @noRd
clean_domains <- function(domains) {
  host <- tolower(trimws(domains))
  host <- sub("^[a-z][a-z0-9+.-]*://", "", host)
  host <- sub("^[^/?#@]*@", "", host)
  host <- sub("[/?#].*$", "", host)
  host <- sub(":[0-9]+$", "", host)
  host <- sub("\\.+$", "", host)
  sub("^www\\.", "", host)
}

#' Registrable domain of a host (public suffix plus one label)
#'
#' Uses the Public Suffix List through `urltools::suffix_extract()`, so `news.bbc.co.uk`
#' gives `bbc.co.uk` and `foo.github.io` stays `foo.github.io`. Hosts without a known
#' suffix (IP addresses, `localhost`, junk) are returned unchanged.
#'
#' @param hosts character vector of normalised hostnames
#' @return character vector, same length
#' @keywords internal
#' @noRd
registrable_domain <- function(hosts) {
  if (!length(hosts)) {
    return(character())
  }
  parts <- suffix_extract(hosts)
  known <- !is.na(parts$domain) & !is.na(parts$suffix) & nzchar(parts$suffix)
  out <- hosts
  out[known] <- paste(parts$domain[known], parts$suffix[known], sep = ".")
  out
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
  as.character(glue(
    "Classify the website domain '{domain}' into exactly one of these categories: ",
    "{paste(categories, collapse = ', ')}. ",
    "Consider what type of content this domain likely hosts."
  ))
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

#' Validate a requested category vocabulary
#' @keywords internal
#' @noRd
validate_categories <- function(categories) {
  assert_character(categories, min.len = 1, any.missing = FALSE, min.chars = 1)
  if (any(!nzchar(trimws(categories))) || anyDuplicated(categories)) {
    cli_abort("{.arg categories} must contain distinct nonblank names.")
  }
  invisible(categories)
}

#' Validate a model name
#' @keywords internal
#' @noRd
validate_model <- function(model) {
  assert_character(model, len = 1, any.missing = FALSE, min.chars = 1)
  if (!nzchar(trimws(model))) cli_abort("{.arg model} must not be blank.")
  invisible(model)
}
