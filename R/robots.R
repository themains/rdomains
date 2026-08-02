#' Honour robots.txt
#'
#' The sibling Python package does not do this -- I audited it and found robots.txt is
#' never fetched on its live path, `Crawl-delay` never parsed, and the user-agent
#' impersonates Chrome while a browser flag actively hides the automation. That is a defect
#' rather than a design, so rdomains does not copy it. Its outcome vocabulary already
#' anticipates this: `robots_blocked` exists in `piedomains/outcomes.py` and is simply
#' never emitted for live fetches.
#'
#' Written here rather than taken from the `robotstxt` package for one decisive reason:
#' that package fetches robots.txt with its own HTTP stack, which would bypass the
#' timeouts, byte caps, address guards and throttle this package is built around. The
#' robots fetch is itself a request to a host we have not yet validated.
#'
#' Parsing follows RFC 9309: group by `User-agent`, prefer the most specific matching
#' group over `*`, longest matching rule wins, and ties go to `Allow`.
#'
#' @keywords internal
#' @noRd
NULL

#' RFC 9309 says 500 KiB; anything larger is not a robots file.
#' @keywords internal
#' @noRd
RD_ROBOTS_MAX_BYTES <- 512000L

#' Parse a robots.txt body into rules for one agent
#'
#' @param txt Contents of robots.txt.
#' @param agent Our product token, lowercased.
#'
#' @return A list with `rules` (data frame of `pattern`, `allow`) and `crawl_delay`.
#' @keywords internal
#' @noRd
parse_robots <- function(txt, agent = "rdomains") {
  lines <- strsplit(txt, "\r?\n")[[1]]
  # Strip comments and a UTF-8 BOM.
  lines <- sub("\uFEFF", "", lines, useBytes = TRUE)
  lines <- sub("#.*$", "", lines)
  lines <- str_trim(lines)
  lines <- lines[nzchar(lines)]

  groups <- list()
  current_agents <- character()
  starting_group <- FALSE

  for (line in lines) {
    parts <- strsplit(line, ":", fixed = TRUE)[[1]]
    if (length(parts) < 2) next
    field <- tolower(str_trim(parts[1]))
    value <- str_trim(paste(parts[-1], collapse = ":"))

    if (identical(field, "user-agent")) {
      if (!starting_group) {
        current_agents <- character()
        starting_group <- TRUE
      }
      current_agents <- c(current_agents, tolower(value))
      next
    }
    if (!length(current_agents)) next
    starting_group <- FALSE

    for (a in current_agents) {
      if (is.null(groups[[a]])) {
        groups[[a]] <- list(rules = list(), crawl_delay = NA_real_)
      }
      if (field %in% c("allow", "disallow")) {
        groups[[a]]$rules[[length(groups[[a]]$rules) + 1]] <- list(
          pattern = value, allow = identical(field, "allow")
        )
      } else if (identical(field, "crawl-delay")) {
        delay <- suppressWarnings(as.numeric(value))
        if (!is.na(delay)) groups[[a]]$crawl_delay <- delay
      }
    }
  }

  # RFC 9309 section 2.2.1: match the whole product token, case-insensitively, and fall
  # back to the wildcard group. A substring test instead applies another crawler's rules
  # to us -- "main" is a substring of "rdomains" -- and, because it takes the first hit in
  # file order rather than the most specific one, it shadows the group naming us outright.
  agent <- tolower(agent)
  pick <- if (agent %in% setdiff(names(groups), "*")) agent else NULL
  if (is.null(pick)) pick <- if ("*" %in% names(groups)) "*" else NULL
  if (is.null(pick)) {
    return(list(rules = empty_rules(), crawl_delay = NA_real_))
  }

  chosen <- groups[[pick]]
  if (!length(chosen$rules)) {
    return(list(rules = empty_rules(), crawl_delay = chosen$crawl_delay))
  }
  rules <- data.frame(
    pattern = vapply(chosen$rules, function(r) r$pattern, character(1)),
    allow = vapply(chosen$rules, function(r) r$allow, logical(1)),
    stringsAsFactors = FALSE
  )
  list(rules = rules, crawl_delay = chosen$crawl_delay)
}

#' @keywords internal
#' @noRd
empty_rules <- function() {
  data.frame(pattern = character(), allow = logical(), stringsAsFactors = FALSE)
}

#' Translate a robots path pattern to a regex
#'
#' `*` matches any run of characters and `$` anchors the end. Everything else is literal.
#'
#' @param pattern robots.txt path pattern
#' @return regex string
#' @keywords internal
#' @noRd
robots_pattern_to_regex <- function(pattern) {
  anchored_end <- grepl("\\$$", pattern)
  if (anchored_end) pattern <- sub("\\$$", "", pattern)
  parts <- strsplit(pattern, "*", fixed = TRUE)[[1]]
  if (!length(parts)) parts <- ""
  escaped <- vapply(parts, function(p) gsub("([.\\\\+?^$(){}|\\[\\]])", "\\\\\\1", p),
                    character(1), USE.NAMES = FALSE)
  # A trailing "*" produces no final element from strsplit; re-add the wildcard.
  trailing <- if (grepl("\\*$", pattern)) ".*" else ""
  paste0("^", paste(escaped, collapse = ".*"), trailing, if (anchored_end) "$" else "")
}

#' Is a path allowed by parsed rules?
#'
#' Longest matching pattern wins; a tie goes to Allow, per RFC 9309.
#'
#' @param rules data frame of pattern/allow
#' @param path request path, beginning with "/"
#' @return logical
#' @keywords internal
#' @noRd
robots_path_allowed <- function(rules, path) {
  if (!nrow(rules)) {
    return(TRUE)
  }
  best_len <- -1L
  best_allow <- TRUE
  for (i in seq_len(nrow(rules))) {
    pattern <- rules$pattern[i]
    # An empty Disallow means "allow everything" and matches nothing.
    if (!nzchar(pattern)) next
    if (grepl(robots_pattern_to_regex(pattern), path)) {
      len <- nchar(pattern)
      if (len > best_len || (len == best_len && rules$allow[i])) {
        best_len <- len
        best_allow <- rules$allow[i]
      }
    }
  }
  best_allow
}

#' Fetch, parse and cache robots.txt for one origin
#'
#' Fail-closed on the cases where we cannot know: a 5xx, a timeout or an unparseable body
#' means disallow. A 4xx means allow, which is what RFC 9309 specifies and is by far the
#' common case.
#'
#' @param scheme_host origin, e.g. "https://example.com"
#' @param agent our product token
#' @param timeout seconds
#' @param ttl cache lifetime in seconds
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

  result <- tryCatch({
    resp <- request(paste0(scheme_host, "/robots.txt")) |>
      req_user_agent(agent) |>
      req_timeout(timeout) |>
      req_error(is_error = function(resp) FALSE) |>
      req_perform()
    status <- resp_status(resp)
    if (status >= 500) {
      list(rules = deny_all(), crawl_delay = NA_real_, status = status)
    } else if (status >= 400) {
      list(rules = empty_rules(), crawl_delay = NA_real_, status = status)
    } else {
      body <- resp_body_string(resp)
      if (nchar(body, type = "bytes") > RD_ROBOTS_MAX_BYTES) {
        list(rules = deny_all(), crawl_delay = NA_real_, status = status)
      } else {
        parsed <- parse_robots(body, agent)
        list(rules = parsed$rules, crawl_delay = parsed$crawl_delay, status = status)
      }
    }
  }, error = function(e) {
    list(rules = deny_all(), crawl_delay = NA_real_, status = NA_integer_)
  })

  result$fetched_at <- Sys.time()
  .rdomains_env[[key]] <- result
  result
}

#' @keywords internal
#' @noRd
deny_all <- function() {
  data.frame(pattern = "/", allow = FALSE, stringsAsFactors = FALSE)
}
