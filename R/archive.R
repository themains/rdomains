#' Recover a page from the Internet Archive when a site blocks us
#'
#' When a host serves an anti-bot interstitial instead of its content, the honest options
#' are to report the block or to ask an archive that was allowed in. The sibling Python
#' package takes the second, and so does this: detection plus an archive fallback rather
#' than an evasion arms race.
#'
#' **Only for blocks, never for dead domains.** A domain that no longer resolves gets
#' `dns_error`, not a 2022 capture. Resurrecting a dead domain from the archive would
#' reintroduce exactly the staleness [source_vintage()] exists to surface -- it would
#' answer "what was this" while looking like "what is this". A block is different: the
#' site is alive and serving, it just would not serve us.
#'
#' When a row does come from the archive, `source` says `"archive"` and
#' `snapshot_timestamp` carries the capture date, so the vintage is never hidden.
#'
#' Uses the CDX API rather than the `/wayback/available` endpoint, which is unreliable --
#' it returns an empty result for domains that demonstrably have thousands of captures.
#' No package dependency: CDX is a JSON endpoint and `httr2` is already here.
#'
#' @keywords internal
#' @noRd
NULL

#' Find the most recent successful capture of a domain
#'
#' @param domain Domain to look up.
#' @param timeout Seconds.
#'
#' @return A list with `url` and `timestamp`, or `NULL` when there is no capture.
#' @keywords internal
#' @noRd
archive_snapshot <- function(domain, timeout = 30) {
  tryCatch({
    resp <- request("https://web.archive.org/cdx/search/cdx") |>
      req_url_query(
        url = domain, output = "json", filter = "statuscode:200",
        # -1 asks for the last row, which is the most recent capture.
        limit = -1L, fl = "timestamp,original"
      ) |>
      req_user_agent(rdomains_user_agent()) |>
      req_timeout(timeout) |>
      # The CDX endpoint is intermittent and rate-limits. Without retries the lookup
      # silently returns NULL and the fallback simply does not happen -- the feature
      # looks broken at random. The sibling package configures three retries against
      # archive.org for the same reason.
      req_retry(max_tries = 3, max_seconds = 60) |>
      req_error(is_error = function(resp) FALSE) |>
      req_perform()

    if (resp_status(resp) != 200L) {
      return(NULL)
    }
    rows <- fromJSON(resp_body_string(resp))
    if (is.null(rows) || !length(rows) || nrow(rows) < 1) {
      return(NULL)
    }
    last <- rows[nrow(rows), ]
    timestamp <- as.character(last[[1]])
    original <- as.character(last[[2]])
    if (!nzchar(timestamp) || !nzchar(original)) {
      return(NULL)
    }
    list(
      # `id_` returns the raw capture without the Wayback toolbar, which would otherwise
      # be extracted as page text.
      url = paste0("https://web.archive.org/web/", timestamp, "id_/", original),
      timestamp = timestamp
    )
  }, error = function(e) NULL)
}

#' Fetch a blocked page from the archive
#'
#' @param domain Domain that was blocked.
#' @param timeout Seconds.
#' @param max_bytes Byte cap.
#' @param user_agent Identifying user-agent.
#'
#' @return A list with `html`, `timestamp` and `url`, or `NULL`.
#' @keywords internal
#' @noRd
archive_fetch <- function(domain, timeout = 45, max_bytes = 10 * 1024^2,
                          user_agent = rdomains_user_agent()) {
  snapshot <- archive_snapshot(domain, timeout = timeout)
  if (is.null(snapshot)) {
    return(NULL)
  }
  tryCatch({
    resp <- request(snapshot$url) |>
      req_user_agent(user_agent) |>
      req_timeout(timeout) |>
      req_retry(max_tries = 3, max_seconds = 60) |>
      req_error(is_error = function(resp) FALSE) |>
      req_options(maxfilesize_large = max_bytes) |>
      req_perform()
    if (resp_status(resp) != 200L) {
      return(NULL)
    }
    body <- resp_body_string(resp)
    if (!nzchar(body)) {
      return(NULL)
    }
    list(html = body, timestamp = snapshot$timestamp, url = snapshot$url)
  }, error = function(e) NULL)
}

#' Turn a Wayback timestamp into a date
#'
#' @param timestamp 14-digit Wayback timestamp.
#' @return character date, or NA
#' @keywords internal
#' @noRd
archive_date <- function(timestamp) {
  if (is.null(timestamp) || is.na(timestamp) || nchar(timestamp) < 8) {
    return(NA_character_)
  }
  paste(substr(timestamp, 1, 4), substr(timestamp, 5, 6), substr(timestamp, 7, 8),
        sep = "-")
}
