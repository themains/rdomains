#' Get Category from Steven Black's Host List
#'
#' Classifies domains based on Steven Black's unified host list which blocks
#' ads, malware, and tracking domains. The function checks if a domain appears
#' in the blocklist and categorizes it accordingly.
#'
#' Steven Black's host list is a consolidated list from multiple sources including
#' adaway.org, mvps.org, malwaredomainlist.com, and someonewhocares.org.
#'
#' @param domain domain names as character vector
#' @param use_file path to a local Steven Black hosts file. If NULL, downloads from GitHub
#'
#' @return data.frame with original domain name and category
#'
#' @export
#' @references \url{https://github.com/StevenBlack/hosts}
#'
#' @examples \dontrun{
#' stevenblack_cat("doubleclick.net")
#' stevenblack_cat(c("google.com", "googleadservices.com", "malware-example.com"))
#' }

stevenblack_cat <- function(domain = NULL, use_file = NULL) {

  validate_domains(domain, "domain")
  clean_doms <- clean_domains(domain)

  if (is.null(use_file)) {
    hosts_file <- tempfile()
    tryCatch({
      cli_inform("Downloading Steven Black's hosts file...")
      curl::curl_download(
        "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts",
        hosts_file
      )
    }, error = function(e) {
      cli_abort(c(
        "Failed to download hosts file",
        "x" = e$message
      ))
    })
  } else {
    assert_file_exists(use_file)
    hosts_file <- use_file
  }

  hosts_lines <- tryCatch({
    readLines(hosts_file, warn = FALSE)
  }, error = function(e) {
    cli_abort(c(
      "Failed to read hosts file",
      "x" = e$message
    ))
  })

  blocked_pattern <- "^(0\\.0\\.0\\.0|127\\.0\\.0\\.1)\\s+"
  blocked_lines <- hosts_lines[str_detect(hosts_lines, blocked_pattern)]

  blocked_domains <- blocked_lines |>
    str_remove(blocked_pattern) |>
    str_trim() |>
    (\(x) x[!str_detect(x, "^#")])() |>
    (\(x) x[x != ""])() |>
    (\(x) x[x != "localhost"])()

  results <- map_df(seq_along(clean_doms), function(i) {
    category <- if (clean_doms[i] %in% blocked_domains) {
      if (str_detect(clean_doms[i], stringr::regex("ad|ads|doubleclick|googleadservices|googlesyndication", ignore_case = TRUE))) {
        "ads"
      } else if (str_detect(clean_doms[i], stringr::regex("malware|virus|trojan|phishing", ignore_case = TRUE))) {
        "malware"
      } else if (str_detect(clean_doms[i], stringr::regex("track|analytics|metric|stats", ignore_case = TRUE))) {
        "tracking"
      } else {
        "blocked"
      }
    } else {
      "safe"
    }
    tibble(domain = domain[i], stevenblack = category)
  })

  if (is.null(use_file)) {
    unlink(hosts_file)
  }

  results
}
