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
#' @param target Optional `YYYYMMDD` date. When given, the latest capture on or before that day is
#'   returned rather than the most recent one.
#'
#' @return A list with `url` and `timestamp`, or `error_code` and `http_status` on failure.
#' @keywords internal
#' @noRd
archive_snapshot <- function(domain, timeout = 30, target = NULL) {
  if (!is.null(target)) validate_archive_date(target)
  tryCatch(
    {
      resp <- request("https://web.archive.org/cdx/search/cdx") |>
        req_url_query(
          url = domain, output = "json", filter = "statuscode:200",
          fl = "timestamp,original",
          limit = -1L,
          !!!(if (is.null(target)) list() else list(to = target))
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
        return(archive_failure(if (resp_status(resp) == 429L) {
          "archive_rate_limited"
        } else {
          "archive_unavailable"
        }, resp_status(resp)))
      }
      rows <- tryCatch(fromJSON(resp_body_string(resp)), error = function(e) NULL)
      if (is.null(rows)) return(archive_failure("archive_invalid_response", 200L))
      if (!length(rows)) {
        return(archive_failure("no_archive_snapshot", 200L))
      }
      if (!is.matrix(rows) || ncol(rows) != 2L ||
            !identical(as.character(rows[1, ]), c("timestamp", "original"))) {
        return(archive_failure("archive_invalid_response", 200L))
      }
      if (nrow(rows) == 1L) return(archive_failure("no_archive_snapshot", 200L))
      last <- rows[nrow(rows), ]
      timestamp <- as.character(last[[1]])
      original <- as.character(last[[2]])
      if (!grepl("^[0-9]{14}$", timestamp) ||
            !grepl("^https?://", original) ||
            (!is.null(target) && substr(timestamp, 1, 8) > target)) {
        return(archive_failure("archive_invalid_response", 200L))
      }
      list(
        # `id_` returns the raw capture without the Wayback toolbar, which would otherwise
        # be extracted as page text.
        url = paste0("https://web.archive.org/web/", timestamp, "id_/", original),
        timestamp = timestamp
      )
    },
    error = function(e) archive_failure("archive_unavailable")
  )
}

#' Fetch a blocked page from the archive
#'
#' @param domain Domain to fetch.
#' @param timeout Seconds.
#' @param max_bytes Byte cap.
#' @param user_agent Identifying user-agent.
#' @param target Optional `YYYYMMDD` date to fetch as of.
#'
#' @return A list with `html`, `timestamp` and `url`, or a structured failure.
#' @keywords internal
#' @noRd
archive_fetch <- function(domain, timeout = 45, max_bytes = 10 * 1024^2,
                          user_agent = rdomains_user_agent(), target = NULL) {
  snapshot <- archive_snapshot(domain, timeout = timeout, target = target)
  if (!is.null(snapshot$error_code)) {
    return(snapshot)
  }
  tryCatch(
    {
      fetched <- guarded_get(snapshot$url, timeout, max_bytes, user_agent)
      resp <- fetched$response
      if (is.null(resp)) {
        return(archive_failure(fetched$error_code %||% "archive_unavailable",
          fetched$http_status %||% NA_integer_
        ))
      }
      if (resp_status(resp) != 200L) {
        return(archive_failure(if (resp_status(resp) == 429L) {
          "archive_rate_limited"
        } else {
          "archive_unavailable"
        }, resp_status(resp)))
      }
      body <- resp_body_string(resp)
      if (!nzchar(body)) {
        return(archive_failure("archive_invalid_response", 200L))
      }
      list(html = body, timestamp = snapshot$timestamp, url = snapshot$url, http_status = 200L)
    },
    error = function(e) archive_failure("archive_unavailable")
  )
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
    sep = "-"
  )
}

#' Require a calendar date in the archive API format
#' @keywords internal
#' @noRd
validate_archive_date <- function(value) {
  assert_character(value, len = 1, any.missing = FALSE)
  date <- suppressWarnings(as.Date(value, format = "%Y%m%d"))
  if (!grepl("^[0-9]{8}$", value) || is.na(date) || format(date, "%Y%m%d") != value) {
    cli_abort("{.arg archive_date} must be a valid date in YYYYMMDD format.")
  }
}

#' Describe a failed archive request without losing its cause
#' @keywords internal
#' @noRd
archive_failure <- function(code, status = NA_integer_) {
  list(error_code = code, http_status = as.integer(status))
}
