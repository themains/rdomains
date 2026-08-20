#' Honour robots.txt
#'
#' Parsing is `spiderbar`'s job, not ours. It is the engine underneath the `robotstxt`
#' package -- a Rust binding to Google's reference implementation -- and it parses a
#' string, leaving the fetch to us. That distinction is the whole point: `robotstxt`
#' itself fetches with its own HTTP stack, which would bypass the timeouts, byte caps and
#' address guards this package is built around.
#'
#' This file previously carried ~120 lines of hand-written RFC 9309 parsing. It was
#' written on the mistaken belief that R had no parse-only equivalent of Python's
#' `protego`; `spiderbar` is exactly that, and two of the bugs the hand-written version
#' shipped -- a substring agent match that let a group for "main" capture "rdomains", and
#' first-in-file-order precedence instead of most-specific -- are bugs a maintained parser
#' does not have.
#'
#' @keywords internal
#' @noRd
NULL

#' RFC 9309 says 500 KiB; anything larger is not a robots file.
#' @keywords internal
#' @noRd
RD_ROBOTS_MAX_BYTES <- 512000L

#' Parse a robots.txt body
#'
#' @param txt Contents of robots.txt.
#' @param agent Our product token.
#'
#' @return A list with `rules` (a spiderbar object, or NULL when there is nothing to
#'   obey) and `crawl_delay`.
#' @keywords internal
#' @noRd
parse_robots <- function(txt, agent = "rdomains") {
  if (!nzchar(str_trim(txt))) {
    return(list(rules = NULL, crawl_delay = NA_real_))
  }
  parsed <- tryCatch(spiderbar::robxp(txt), error = function(e) NULL)
  if (is.null(parsed)) {
    # An unparseable body is not permission.
    return(list(rules = FALSE, crawl_delay = NA_real_))
  }

  delays <- tryCatch(spiderbar::crawl_delays(parsed), error = function(e) NULL)
  delay <- NA_real_
  if (!is.null(delays) && nrow(delays)) {
    mine <- delays$crawl_delay[delays$agent == agent]
    star <- delays$crawl_delay[delays$agent == "*"]
    chosen <- if (length(mine) && mine[1] >= 0) mine[1] else if (length(star)) star[1] else -1
    if (!is.na(chosen) && chosen >= 0) delay <- as.numeric(chosen)
  }
  list(rules = parsed, crawl_delay = delay)
}

#' Is a path allowed by parsed rules?
#'
#' @param rules Result of [parse_robots()]'s `rules`.
#' @param path Request path, beginning with "/".
#' @param agent Our product token.
#'
#' @return logical
#' @keywords internal
#' @noRd
robots_path_allowed <- function(rules, path, agent = "rdomains") {
  if (is.null(rules)) {
    return(TRUE)
  }
  if (isFALSE(rules)) {
    return(FALSE)
  }
  isTRUE(tryCatch(spiderbar::can_fetch(rules, path, agent), error = function(e) FALSE))
}

#' Fetch, parse and cache robots.txt for one origin
#'
#' Fail-closed where we cannot know: a 5xx, a timeout or an unparseable body disallows. A
#' 4xx allows, which is what RFC 9309 specifies and is by far the common case.
#'
#' @param scheme_host Origin, e.g. `https://example.com`.
#' @param agent Our product token.
#' @param timeout Seconds.
#' @param ttl Cache lifetime in seconds.
#'
#' @return list(rules, crawl_delay, status, fetched_at)
#' @keywords internal
#' @noRd
robots_for_origin <- function(scheme_host, agent = "rdomains", timeout = 10,
                              ttl = 86400) {
  key <- paste0("robots:", scheme_host)
  hit <- .rdomains_env[[key]]
  if (!is.null(hit) && difftime(Sys.time(), hit$fetched_at, units = "secs") < ttl) {
    return(hit)
  }

  result <- tryCatch(
    {
      resp <- request(paste0(scheme_host, "/robots.txt")) |>
        req_user_agent(agent) |>
        req_timeout(timeout) |>
        req_error(is_error = function(resp) FALSE) |>
        req_perform()
      status <- resp_status(resp)
      if (status >= 500) {
        list(rules = FALSE, crawl_delay = NA_real_, status = status)
      } else if (status >= 400) {
        list(rules = NULL, crawl_delay = NA_real_, status = status)
      } else {
        body <- resp_body_string(resp)
        if (nchar(body, type = "bytes") > RD_ROBOTS_MAX_BYTES) {
          list(rules = FALSE, crawl_delay = NA_real_, status = status)
        } else {
          parsed <- parse_robots(body, agent)
          list(rules = parsed$rules, crawl_delay = parsed$crawl_delay, status = status)
        }
      }
    },
    error = function(e) {
      list(rules = FALSE, crawl_delay = NA_real_, status = NA_integer_)
    }
  )

  result$fetched_at <- Sys.time()
  .rdomains_env[[key]] <- result
  result
}
