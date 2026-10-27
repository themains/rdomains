#' Get Category from Steven Black's Host List
#'
#' Classifies domains based on Steven Black's unified host list which blocks
#' ads, malware, and tracking domains. The function checks if a domain appears
#' in the blocklist and categorizes it accordingly.
#'
#' Steven Black's host list is a consolidated list from multiple sources including
#' adaway.org, mvps.org, malwaredomainlist.com, and someonewhocares.org.
#'
#' Listed hosts receive `blocked`; absent hosts have `status = "no_match"`.
#' Neither outcome determines safety or a content subclass.
#'
#' Publication dates come from the `.metadata.json` sidecar written by the downloader,
#' checked against the file contents. `source_fetched_at` is the download time.
#' Files without matching metadata return `NA` dates; filesystem timestamps are not used.
#'
#' @param domains domain names as character vector
#' @param use_file path to a local Steven Black hosts file. If NULL, downloads from GitHub
#'   once per session and reuses it
#'
#' @return A tibble following [classification_results]. Source-specific data are
#'   retained in `details`; all source labels are retained in `labels`.
#'
#' @export
#' @seealso \code{\link{source_vintage}} for the provenance of every category source
#' @references \url{https://github.com/StevenBlack/hosts}
#'
#' @examples \dontrun{
#' stevenblack_cat("doubleclick.net")
#' stevenblack_cat(c("google.com", "googleadservices.com", "malware-example.com"))
#' }
stevenblack_cat <- function(domains, use_file = NULL) {
  validate_domains(domains)
  result <- classification_result(domains, "stevenblack", "list_membership", "lookup")
  if (!length(domains)) {
    return(result)
  }
  path <- lookup_source_file("stevenblack", use_file)
  metadata <- load_source_metadata(path)
  lines <- sub("#.*$", "", trimws(readLines(path, warn = FALSE)))
  pattern <- "^(0\\.0\\.0\\.0|127\\.0\\.0\\.1)\\s+"
  lines <- lines[grepl(pattern, lines)]
  hosts <- tolower(unlist(strsplit(trimws(sub(pattern, "", lines)), "\\s+"), use.names = FALSE))
  hosts <- setdiff(hosts, c("", "localhost"))
  matched <- result$domain_name %in% hosts | paste0("www.", result$domain_name) %in% hosts
  for (i in which(matched)) result <- set_result_labels(result, i, label_table("blocked"))
  result$source_last_published <- rep(metadata$source_last_published, length(domains))
  result$source_fetched_at <- rep(metadata$source_fetched_at, length(domains))
  result$details <- replicate(length(domains), list(
    source_url = metadata$source_url,
    checksum = metadata$checksum
  ), simplify = FALSE)
  result
}
