#' Get Category from Steven Black's Host List
#'
#' Classifies domains based on Steven Black's unified host list which blocks
#' ads, malware, and tracking domains. The function checks if a domain appears
#' in the blocklist and categorizes it accordingly.
#'
#' Steven Black's host list is a consolidated list from multiple sources including
#' adaway.org, mvps.org, malwaredomainlist.com, and someonewhocares.org.
#'
#' Absence from the list is `not_listed`, not a safety assessment. Subcategories
#' such as `ads` are domain-name heuristics applied only to listed hosts.
#'
#' Publication dates come from the `.metadata.json` sidecar written by the downloader,
#' checked against the file contents. `source_fetched_at` is the download time.
#' Files without matching metadata return `NA` dates; filesystem timestamps are not used.
#'
#' @param domains domain names as character vector
#' @param use_file path to a local Steven Black hosts file. If NULL, downloads from GitHub
#'   once per session and reuses it
#'
#' @return data.frame with the normalized domain_name, the category, and the date of the
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
stevenblack_cat <- function(domains = NULL, use_file = NULL) {
  validate_domains(domains)
  clean_doms <- clean_domains(domains)

  if (is.null(use_file)) {
    # Cached for the session. This used to re-download ~4 MB on *every* call, so
    # classifying domains one at a time cost a fresh download each time.
    cached <- .rdomains_env$stevenblack_file
    if (!is.null(cached) && file.exists(cached)) {
      hosts_file <- cached
    } else {
      hosts_file <- tempfile(fileext = ".hosts")
      tryCatch(
        {
          cli_inform("Downloading Steven Black's hosts file...")
          metadata <- download_source(
            "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts",
            hosts_file
          )
          save_source_metadata(hosts_file, metadata)
        },
        error = function(e) {
          cli_abort(c(
            "Failed to download hosts file",
            "x" = e$message
          ))
        }
      )
      .rdomains_env$stevenblack_file <- hosts_file
    }
  } else {
    assert_file_exists(use_file)
    hosts_file <- use_file
  }

  metadata <- load_source_metadata(hosts_file)

  hosts_lines <- tryCatch(
    {
      readLines(hosts_file, warn = FALSE)
    },
    error = function(e) {
      cli_abort(c(
        "Failed to read hosts file",
        "x" = e$message
      ))
    }
  )

  blocked_pattern <- "^(0\\.0\\.0\\.0|127\\.0\\.0\\.1)\\s+"
  hosts_lines <- sub("#.*$", "", trimws(hosts_lines))
  blocked_lines <- hosts_lines[str_detect(hosts_lines, blocked_pattern)]

  blocked_domains <- tolower(unlist(strsplit(
    trimws(str_remove(blocked_lines, blocked_pattern)), "\\s+"
  ), use.names = FALSE))
  blocked_domains <- setdiff(blocked_domains, c("", "localhost"))

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
      } else if (str_detect(
        clean_doms[i],
        stringr::regex("malware|virus|trojan|phishing", ignore_case = TRUE)
      )) {
        "malware"
      } else if (str_detect(
        clean_doms[i],
        stringr::regex("track|analytics|metric|stats", ignore_case = TRUE)
      )) {
        "tracking"
      } else {
        "blocked"
      }
    } else {
      "not_listed"
    }
    tibble(
      domain_name = clean_doms[i],
      stevenblack = category,
      source_last_published = metadata$source_last_published,
      source_fetched_at = metadata$source_fetched_at
    )
  })

  # The cached file is deliberately not unlinked -- it is the session cache. R removes the
  # tempdir on exit.

  results
}
