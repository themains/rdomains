#' Fetch homepage content for a set of domains
#'
#' Mirrors the sibling Python package's `DataCollector` (`src/piedomains/data_collector.py`)
#' and its outcome contract: **one row per requested domain, never dropped**, each carrying
#' `status`, `stage`, `error_code` and `retryable` so a caller can tell a transient failure
#' from a permanent one and retry exactly the right rows.
#'
#' Static HTML only -- no headless browser. Pages that render their content with JavaScript
#' will come back thin, and `page_state` says so rather than pretending otherwise.
#'
#' **This crawler identifies itself and obeys robots.txt.** That is a deliberate departure
#' from piedomains, which I audited and found does neither on its live path. A CRAN package
#' fetching arbitrary URLs on a user's behalf has no business impersonating a browser.
#'
#' @keywords internal
#' @noRd
NULL

#' Identify ourselves honestly, with a way to be blocked
#' @keywords internal
#' @noRd
rdomains_user_agent <- function() {
  sprintf("rdomains/%s (R package; +https://github.com/themains/rdomains)",
          utils::packageVersion("rdomains"))
}

#' Addresses that must never be fetched
#'
#' Rejecting these stops a domain lookup from being turned into a probe of the caller's own
#' network. `169.254.169.254` in particular is the cloud metadata endpoint.
#'
#' @param ip character IP address
#' @return TRUE when the address is globally routable
#' @keywords internal
#' @noRd
is_global_ip <- function(ip) {
  if (is.na(ip) || !nzchar(ip)) {
    return(FALSE)
  }
  # IPv4-mapped IPv6 (::ffff:10.0.0.1) must be unwrapped before checking -- this is the
  # step people forget, and it re-opens the whole hole.
  mapped <- str_match(tolower(ip), "^::ffff:(\\d+\\.\\d+\\.\\d+\\.\\d+)$")
  if (!is.na(mapped[1, 2])) ip <- mapped[1, 2]

  if (grepl(":", ip, fixed = TRUE)) {
    lowered <- tolower(ip)
    if (lowered %in% c("::", "::1")) return(FALSE)
    # fc00::/7 unique-local, fe80::/10 link-local
    if (grepl("^f[cd]", lowered)) return(FALSE)
    if (grepl("^fe[89ab]", lowered)) return(FALSE)
    return(TRUE)
  }

  octets <- suppressWarnings(as.integer(strsplit(ip, ".", fixed = TRUE)[[1]]))
  if (length(octets) != 4 || any(is.na(octets))) {
    return(FALSE)
  }
  a <- octets[1]; b <- octets[2]
  !(a == 0 || a == 10 || a == 127 ||
      (a == 100 && b >= 64 && b <= 127) ||
      (a == 169 && b == 254) ||
      (a == 172 && b >= 16 && b <= 31) ||
      (a == 192 && b == 168) ||
      (a == 192 && b == 0) ||
      (a == 198 && (b == 18 || b == 19)) ||
      a >= 224)
}

#' Reject a URL we should not fetch
#'
#' @param url the URL
#' @param resolver function(host) -> character vector of IPs; injectable so tests never
#'   touch DNS
#' @return NULL when acceptable, otherwise an error code
#' @keywords internal
#' @noRd
check_url <- function(url, resolver = nslookup) {
  parsed <- tryCatch(url_parse(url), error = function(e) NULL)
  if (is.null(parsed) || is.null(parsed$hostname) || !nzchar(parsed$hostname)) {
    return("invalid_domain")
  }
  if (!identical(parsed$scheme, "http") && !identical(parsed$scheme, "https")) {
    return("invalid_domain")
  }
  host <- tolower(parsed$hostname)
  # A domain classifier has nothing to say about a bare IP, and .onion is unreachable.
  if (grepl("^\\d+\\.\\d+\\.\\d+\\.\\d+$", host) ||
      grepl("\\.(onion|local|internal|localhost)$", host) ||
      !grepl(".", host, fixed = TRUE)) {
    return("invalid_domain")
  }

  ips <- tryCatch(resolver(host, error = FALSE), error = function(e) NULL)
  if (is.null(ips) || !length(ips)) {
    return("dns_error")
  }
  if (!all(vapply(ips, is_global_ip, logical(1)))) {
    return("private_address")
  }
  NULL
}

#' Map a caught condition to a stable error code
#'
#' Matches on condition class first, because R's classes carry better information than
#' message text and matching on the word "timeout" misclassifies a page whose error text
#' merely contains it.
#'
#' @param cnd condition
#' @return error code string
#' @keywords internal
#' @noRd
classify_condition <- function(cnd) {
  classes <- class(cnd)
  msg <- tolower(conditionMessage(cnd))
  if (any(grepl("timeout", classes)) || grepl("timed? ?out", msg)) return("timeout")
  if (any(grepl("httr2_failure", classes))) {
    if (grepl("could not resolve|name or service|nodename", msg)) return("dns_error")
    if (grepl("ssl|certificate|tls", msg)) return("connection_error")
    return("connection_error")
  }
  if (grepl("could not resolve|name or service|nodename", msg)) return("dns_error")
  if (grepl("refused|reset|unreachable", msg)) return("connection_error")
  "unknown"
}

#' Fetch homepage HTML and text for domains
#'
#' Every requested domain comes back, in order, whether or not it was reachable. Failures
#' carry a code from [fetch_error_codes()] rather than a bare `NA`.
#'
#' The crawler identifies itself as `rdomains/<version>`, obeys `robots.txt` including
#' `Crawl-delay`, spaces requests to the same host, caps the response body, and refuses to
#' fetch hosts that resolve to private or link-local addresses.
#'
#' @param domains Character vector of domains or URLs.
#' @param delay Minimum seconds between requests to the same host. `Crawl-delay` overrides
#'   this upward.
#' @param timeout Per-request timeout, seconds.
#' @param max_bytes Cap on the response body actually read.
#' @param obey_robots Whether to fetch and honour robots.txt. Turning this off is
#'   discouraged and is your responsibility, not the package's.
#' @param max_crawl_delay Skip a host that asks for a longer delay than this rather than
#'   sleeping on it.
#' @param user_agent Override the identifying user-agent.
#'
#' @return A tibble with one row per input: `domain_name`, `status`, `stage`, `error_code`,
#'   `retryable`, `http_status`, `final_url`, `fetched_at`, `content_bytes`, `title`,
#'   `description`, `lang`, `text`, `n_tokens`, `page_state`, `block_vendor`,
#'   `robots_allowed`, `source_last_published`.
#'
#' @export
#' @seealso [fetch_report()] to summarise the run, [page_signals()] for what the page
#'   states are, [source_vintage()] for how a live fetch compares with the static lists.
#' @examples \dontrun{
#' res <- collect_content(c("example.com", "wikipedia.org"))
#' fetch_report(res)
#'
#' # retry only what is worth retrying
#' again <- collect_content(res$domain_name[res$retryable])
#' }
collect_content <- function(domains = NULL,
                            delay = 1,
                            timeout = 10,
                            max_bytes = 2 * 1024^2,
                            obey_robots = TRUE,
                            max_crawl_delay = 30,
                            user_agent = rdomains_user_agent()) {
  validate_domains(domains)
  clean <- clean_domains(domains)

  rows <- lapply(seq_along(clean), function(i) {
    fetch_one(
      clean[i], domains[i],
      delay = delay, timeout = timeout, max_bytes = max_bytes,
      obey_robots = obey_robots, max_crawl_delay = max_crawl_delay,
      user_agent = user_agent
    )
  })
  dplyr::bind_rows(rows)
}

#' Build one result row with a fixed schema and fixed column types
#'
#' R has no static types, so the schema is pinned here instead: every row in a run comes
#' from this one constructor, with every column explicitly coerced. Two separate `tibble()`
#' calls will drift, and when they do `bind_rows()` fails with a type error far from the
#' cause -- or worse, succeeds. This function is the type declaration.
#'
#' @param domain cleaned domain
#' @param input the caller's original string
#' @param started fetch start time
#' @param status "ok" or "failed"
#' @param stage pipeline stage reached
#' @param error_code code from [fetch_error_codes()], or NA
#' @param http_status HTTP status code, or NA
#' @param final_url URL after redirects, or NA
#' @param content_bytes body size actually read
#' @param parsed result of [html_text_content()], or NULL
#' @param signals result of [page_signals()], or NULL
#' @param robots_allowed whether robots.txt permitted the fetch
#'
#' @return a one-row tibble
#' @keywords internal
#' @noRd
fetch_row <- function(domain, input, started,
                      status = "failed", stage = "fetch", error_code = NA_character_,
                      http_status = NA_integer_, final_url = NA_character_,
                      content_bytes = NA_integer_, parsed = NULL, signals = NULL,
                      robots_allowed = NA) {
  tibble(
    domain_name = as.character(domain),
    input = as.character(input),
    status = as.character(status),
    stage = as.character(stage),
    error_code = as.character(error_code),
    retryable = isTRUE(is_retryable(error_code)),
    http_status = as.integer(http_status),
    final_url = as.character(final_url),
    fetched_at = started,
    content_bytes = as.integer(content_bytes),
    title = as.character(parsed$title %||% NA_character_),
    description = as.character(parsed$description %||% NA_character_),
    lang = as.character(parsed$lang %||% NA_character_),
    text = as.character(parsed$text %||% NA_character_),
    n_tokens = as.integer(signals$n_tokens %||% 0L),
    page_state = as.character(signals$page_state %||% NA_character_),
    block_vendor = as.character(signals$block_vendor %||% NA_character_),
    robots_allowed = as.logical(robots_allowed),
    source_last_published = format(started, "%Y-%m")
  )
}

#' @keywords internal
#' @noRd
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Fetch a single domain, returning one fully-populated row whatever happens
#' @keywords internal
#' @noRd
fetch_one <- function(domain, input, delay, timeout, max_bytes, obey_robots,
                      max_crawl_delay, user_agent) {
  started <- Sys.time()
  url <- paste0("https://", domain)

  blank <- function(code, stage, http_status = NA_integer_, robots_allowed = NA) {
    fetch_row(domain, input, started, status = "failed", stage = stage,
              error_code = code, http_status = http_status,
              robots_allowed = robots_allowed)
  }

  bad <- check_url(url)
  if (!is.null(bad)) {
    return(blank(bad, if (bad == "dns_error") "fetch" else "validate"))
  }

  crawl_delay <- delay
  if (obey_robots) {
    origin <- paste0("https://", domain)
    rules <- robots_for_origin(origin, agent = "rdomains", timeout = timeout)
    if (!robots_path_allowed(rules$rules, "/")) {
      return(blank("robots_blocked", "validate", robots_allowed = FALSE))
    }
    if (!is.na(rules$crawl_delay)) {
      if (rules$crawl_delay > max_crawl_delay) {
        return(blank("robots_blocked", "validate", robots_allowed = FALSE))
      }
      crawl_delay <- max(crawl_delay, rules$crawl_delay)
    }
  }

  resp <- tryCatch({
    request(url) |>
      req_user_agent(user_agent) |>
      req_timeout(timeout) |>
      req_throttle(capacity = 1L, fill_time_s = crawl_delay) |>
      req_retry(max_tries = 2, max_seconds = 30) |>
      # Without this a 403 interstitial throws and page_signals() never sees the body --
      # which is exactly the case we most need to classify.
      req_error(is_error = function(resp) FALSE) |>
      req_options(maxfilesize_large = max_bytes) |>
      req_perform()
  }, error = function(e) e)

  if (inherits(resp, "condition")) {
    return(blank(classify_condition(resp), "fetch", robots_allowed = TRUE))
  }

  # Named `http_code`, not `status`. tibble() evaluates its arguments sequentially and
  # later ones see earlier ones, so a `status = ...` column would shadow this variable and
  # `http_status = status` would silently store the string "ok"/"failed" instead of the
  # HTTP code. That exact mistake is why fetch_report() miscounted; it is worth naming.
  http_code <- as.integer(resp_status(resp))
  ctype <- tryCatch(resp_content_type(resp), error = function(e) NA_character_)
  body <- tryCatch(resp_body_string(resp), error = function(e) "")
  bytes <- nchar(body, type = "bytes")

  if (bytes > max_bytes) {
    return(blank("content_too_large", "fetch", http_status = http_code,
                 robots_allowed = TRUE))
  }
  if (!is.na(ctype) && !grepl("html|xml", ctype, fixed = FALSE)) {
    return(blank("content_type_rejected", "fetch", http_status = http_code,
                 robots_allowed = TRUE))
  }

  parsed <- html_text_content(body)
  signals <- page_signals(body, text = parsed$text, domain = domain, status = http_code)

  code <- NA_character_
  state_status <- "ok"
  stage <- "process"
  if (signals$blocked) {
    code <- "bot_blocked"; state_status <- "failed"; stage <- "fetch"
  } else if (http_code >= 400) {
    code <- "http_error"; state_status <- "failed"; stage <- "fetch"
  } else if (!nzchar(parsed$text)) {
    code <- "empty_text"; state_status <- "failed"
  } else if (signals$thin && signals$page_state == "thin") {
    code <- "thin_content"; state_status <- "failed"
  }

  fetch_row(
    domain, input, started,
    status = state_status,
    stage = if (identical(state_status, "ok")) "process" else stage,
    error_code = code,
    http_status = http_code,
    final_url = tryCatch(resp_url(resp), error = function(e) url),
    content_bytes = bytes,
    parsed = parsed,
    signals = signals,
    robots_allowed = TRUE
  )
}
