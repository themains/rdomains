#' Get Category from Steven Black's Host List
#'
#' Classifies domains based on Steven Black's unified host list which blocks
#' ads, malware, and tracking domains. The function checks if a domain appears
#' in the blocklist and categorizes it accordingly.
#'
#' Steven Black's host list is a consolidated list from multiple sources including
#' adaway.org, mvps.org, malwaredomainlist.com, and someonewhocares.org.
#'
#' Unlike the Shallalist and DMOZ lookups, this list is actively maintained, so the
#' returned \code{source_last_published} is the fetched file's own modification date
#' rather than a constant. See \code{\link{source_vintage}}.
#'
#' @param domain domain names as character vector
#' @param use_file path to a local Steven Black hosts file. If NULL, downloads from GitHub
#'   once per session and reuses it
#'
#' @return data.frame with the original domain name, the category, and the date of the
#'   list that supplied it
#'
#' @export
#' @seealso \code{\link{source_vintage}} for the provenance of every category source
#' @references \url{https://github.com/StevenBlack/hosts}
#'
#' @examples \dontrun{
#' stevenblack_cat("doubleclick.net")
#' stevenblack_cat(c("google.com", "googleadservices.com", "malware-example.com"))
#' }

stevenblack_cat <- function(domain = NULL, use_file = NULL) {

  validate_domains(domain, "domain")
  clean_doms <- clean_domains(domain)

  downloaded <- FALSE
  if (is.null(use_file)) {
    # Cached for the session. This used to re-download ~4 MB on *every* call, so
    # classifying domains one at a time cost a fresh download each time.
    cached <- .rdomains_env$stevenblack_file
    if (!is.null(cached) && file.exists(cached)) {
      hosts_file <- cached
    } else {
      hosts_file <- tempfile(fileext = ".hosts")
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
      .rdomains_env$stevenblack_file <- hosts_file
      downloaded <- TRUE
    }
  } else {
    assert_file_exists(use_file)
    hosts_file <- use_file
  }

  file_date <- tryCatch(
    format(as.Date(file.info(hosts_file)$mtime), "%Y-%m-%d"),
    error = function(e) NA_character_
  )

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
    (\(x) x[x != "localhost"])() |>
    tolower()

  # "ad" has to be a label of its own, or the head of one: it is otherwise a substring of
  # trade, download, gadget, espadrilles and nokiadns. Unanchored, it labels 13,423 of the
  # live list's 99,278 blocked hosts "ads", 10,581 of which contain no ad token at all.
  ads_pattern <-
    "(^|[.-])ads?([.-]|$)|adserv|doubleclick|googleadservices|googlesyndication"

  # The list blocks hosts as written: 34,151 of the live list's 99,278 entries carry the
  # "www." that clean_domains() strips, and 1,870 have no bare counterpart. Matching only
  # the bare form calls a blocked host safe, which is the harmful direction here.
  is_blocked <- function(host) {
    host %in% blocked_domains || paste0("www.", host) %in% blocked_domains
  }

  results <- map_df(seq_along(clean_doms), function(i) {
    category <- if (is_blocked(clean_doms[i])) {
      if (str_detect(clean_doms[i], stringr::regex(ads_pattern, ignore_case = TRUE))) {
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
    tibble(
      domain = domain[i],
      stevenblack = category,
      source_last_published = file_date
    )
  })

  # The cached file is deliberately not unlinked -- it is the session cache. R removes the
  # tempdir on exit.
  invisible(downloaded)

  results
}
