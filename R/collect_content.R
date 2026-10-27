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
#' The crawler identifies itself and checks robots.txt before each content request.
#' Address checks precede each redirect hop; DNS and the HTTP client resolve separately,
#' so this is not a substitute for an egress firewall against DNS rebinding.
#'
#' @keywords internal
#' @noRd
NULL

#' Identify ourselves honestly, with a way to be blocked
#' @keywords internal
#' @noRd
rdomains_user_agent <- function() {
  sprintf(
    "rdomains/%s (R package; +https://github.com/themains/rdomains)",
    utils::packageVersion("rdomains")
  )
}

#' Addresses that must never be fetched
#'
#' `ipaddress::is_global()` already knows every range that matters -- RFC1918, loopback,
#' link-local (including the cloud metadata endpoint), CGNAT, benchmarking, TEST-NET,
#' IPv6 ULA and link-local. This function previously spelled all of that out by hand,
#' written on the mistaken belief that R had no equivalent of Python's stdlib
#' `ipaddress`. It does, and the package gets one case the hand-written version did not
#' even try: `is_global` is stricter about IPv4-mapped IPv6, refusing `::ffff:8.8.8.8`
#' where the hand-written check allowed it. That is the safe direction and the case is
#' vanishingly rare in practice.
#'
#' @param ip character IP address
#' @return TRUE when the address is globally routable
#' @keywords internal
#' @noRd
is_global_ip <- function(ip) {
  if (is.na(ip) || !nzchar(ip)) {
    return(FALSE)
  }
  parsed <- suppressWarnings(ipaddress::ip_address(ip))
  if (is.na(parsed)) {
    return(FALSE)
  }
  isTRUE(
    ipaddress::is_global(parsed) &&
      !ipaddress::is_multicast(parsed) &&
      !ipaddress::is_reserved(parsed)
  )
}

#' Build the URL to request for one input
#'
#' A bare domain becomes `https://<domain>`. An input that already carries a scheme is
#' honoured as given, keeping its port and path -- otherwise an http-only host is
#' unreachable, and the package cannot be exercised against a local test server.
#'
#' @param input the caller's original string
#' @return a URL
#' @keywords internal
#' @noRd
request_url <- function(input) {
  input <- trimws(input)
  if (grepl("^[a-z][a-z0-9+.-]*://", input, ignore.case = TRUE)) {
    input
  } else {
    paste0("https://", input)
  }
}

#' Reject a URL we should not fetch
#'
#' @param url the URL
#' @param resolver function(host) -> character vector of IPs; injectable so tests never
#'   touch DNS
#' @param allow_hosts hosts exempt from the address checks, by exact name
#' @return NULL when acceptable, otherwise an error code
#' @keywords internal
#' @noRd
check_url <- function(url, resolver = nslookup, allow_hosts = character()) {
  parsed <- tryCatch(url_parse(url), error = function(e) NULL)
  if (is.null(parsed) || is.null(parsed$hostname) || !nzchar(parsed$hostname)) {
    return("invalid_domain")
  }
  if (!identical(parsed$scheme, "http") && !identical(parsed$scheme, "https")) {
    return("invalid_domain")
  }
  host <- tolower(parsed$hostname)
  # An explicitly exempted host skips the address checks. Only the named hosts are
  # exempt, so a redirect elsewhere -- including to another private address -- is still
  # refused.
  if (host %in% tolower(allow_hosts)) {
    return(NULL)
  }
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
  # curl aborts an oversized transfer rather than returning a body, so the size limit
  # surfaces as a request failure. Left unmapped it becomes connection_error -- which is
  # retryable, so a caller would retry a too-large page forever.
  if (grepl("maximum file size exceeded|filesize exceeded", msg)) {
    return("content_too_large")
  }
  if (any(grepl("timeout", classes)) || grepl("timed? ?out", msg)) {
    return("timeout")
  }
  if (any(grepl("httr2_failure", classes))) {
    if (grepl("could not resolve|name or service|nodename", msg)) {
      return("dns_error")
    }
    if (grepl("ssl|certificate|tls", msg)) {
      return("connection_error")
    }
    return("connection_error")
  }
  if (grepl("could not resolve|name or service|nodename", msg)) {
    return("dns_error")
  }
  if (grepl("refused|reset|unreachable", msg)) {
    return("connection_error")
  }
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
#' @param max_bytes Cap on the response body actually read. The default matches
#'   piedomains' 10 MB. A smaller cap looks prudent and is not: cnn.com's homepage
#'   alone is roughly 6 MB, so a 2 MB limit rejects major news sites as
#'   `content_too_large` while they return HTTP 200.
#' @param obey_robots Whether to fetch and honour robots.txt. Turning this off is
#'   discouraged and is your responsibility, not the package's.
#' @param max_crawl_delay Skip a host that asks for a longer delay than this rather than
#'   sleeping on it.
#' @param max_redirects Maximum redirect hops to follow. Every hop is re-validated, so a
#'   redirect cannot be used to reach an address the first check refused.
#' @param cache_dir Where to cache fetched pages. Defaults to a directory under
#'   [tempdir()], so nothing persists past the session; pass [rdomains_cache_dir()] to opt
#'   into a cache that does.
#' @param cache_ttl Seconds a cached page stays fresh.
#' @param cache_max_size Prune the cache above this many bytes, oldest first.
#' @param allow_hosts Hosts exempt from the private-address checks, by exact name. Only
#'   the hosts named are exempt, so a redirect elsewhere is still refused. Intended for
#'   testing against a local server.
#' @param archive_date Fetch each domain as it was on this date (`"YYYYMMDD"`) from the
#'   Internet Archive instead of fetching it live. This is how you ask what a domain
#'   *used to be* -- and, set against a live run, how you measure whether a label has gone
#'   stale. Rows carry `source = "archive"` and the realised `snapshot_timestamp`, which
#'   is the latest capture on or before the requested day.
#' @param archive_fallback Opt in to archived content (default `FALSE`). When a host serves an
#' anti-bot interstitial, try the
#'   Internet Archive's most recent capture. Rows recovered this way carry
#'   `source = "archive"` and a `snapshot_timestamp`, so the vintage is never
#'   hidden. Dead domains and explicitly exempted hosts are not recovered this way.
#' @param user_agent Override the identifying user-agent.
#'
#' @return A tibble with one row per input: `input_id`, `input`, `domain_name`,
#'   `archive_error_code`, `status`, `stage`, `error_code`,
#'   `retryable`, `http_status`, `final_url`, `fetched_at`, `content_bytes`, `title`,
#'   `description`, `lang`, `text`, `html`, `n_tokens`, `page_state`, `block_vendor`,
#'   `robots_allowed`, `from_cache`, `source`, `snapshot_timestamp`, `source_last_published`.
#'   Live pages have no inferred publication date; `fetched_at` records retrieval.
#'
#' @export
#' @seealso [fetch_report()] to summarise the run, [page_signals()] for what the page
#'   states are, [source_vintage()] for how a live fetch compares with the static lists.
#' @examples \dontrun{
#' res <- collect_content(c("example.com", "wikipedia.org"))
#' fetch_report(res)
#'
#' # retry only what is worth retrying
#' again <- collect_content(res$input[res$retryable])
#' }
collect_content <- function(domains = NULL,
                            delay = 1,
                            timeout = 10,
                            max_bytes = 10 * 1024^2,
                            obey_robots = TRUE,
                            max_crawl_delay = 30,
                            max_redirects = 5,
                            cache_dir = NULL,
                            cache_ttl = 7 * 86400,
                            cache_max_size = 1024^3,
                            allow_hosts = character(),
                            archive_fallback = FALSE,
                            archive_date = NULL,
                            user_agent = rdomains_user_agent()) {
  cache_dir <- cache_dir %||% default_cache_dir()
  validate_domains(domains)
  validate_number(delay, "delay")
  validate_number(timeout, "timeout", lower = .Machine$double.eps)
  validate_number(max_bytes, "max_bytes", lower = 1, integer = TRUE)
  validate_number(max_crawl_delay, "max_crawl_delay")
  validate_number(max_redirects, "max_redirects", integer = TRUE)
  validate_number(cache_ttl, "cache_ttl")
  validate_number(cache_max_size, "cache_max_size")
  checkmate::assert_flag(obey_robots)
  checkmate::assert_flag(archive_fallback)
  assert_character(cache_dir, len = 1, any.missing = FALSE, min.chars = 1)
  assert_character(allow_hosts, any.missing = FALSE, min.chars = 1)
  assert_character(user_agent, len = 1, any.missing = FALSE, min.chars = 1)
  if (!is.null(archive_date)) validate_archive_date(archive_date)
  clean <- clean_domains(domains)

  if (!length(clean)) {
    return(fetch_row("", "", Sys.time())[FALSE, ])
  }
  rows <- lapply(seq_along(clean), function(i) {
    fetch_one(
      clean[i], domains[i],
      delay = delay, timeout = timeout, max_bytes = max_bytes,
      obey_robots = obey_robots, max_crawl_delay = max_crawl_delay,
      max_redirects = max_redirects, cache_dir = cache_dir,
      cache_ttl = cache_ttl, cache_max_size = cache_max_size,
      allow_hosts = allow_hosts, archive_fallback = archive_fallback,
      archive_date = archive_date, user_agent = user_agent
    )
  })
  result <- dplyr::bind_rows(rows)
  result$input_id <- seq_along(domains)
  result
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
#' @param from_cache whether the row was replayed from cache rather than fetched
#' @param source "live" or "archive"
#' @param snapshot_timestamp Wayback capture timestamp, when source is archive
#' @param html Raw response HTML, retained for model-specific extraction.
#'
#' @return a one-row tibble
#' @keywords internal
#' @noRd
fetch_row <- function(domain, input, started,
                      status = "failed", stage = "fetch", error_code = NA_character_,
                      http_status = NA_integer_, final_url = NA_character_,
                      content_bytes = NA_integer_, parsed = NULL, signals = NULL,
                      robots_allowed = NA, from_cache = FALSE,
                      source = "live", snapshot_timestamp = NA_character_, html = NA_character_) {
  tibble(
    input_id = 1L,
    domain_name = as.character(domain),
    input = as.character(input),
    archive_error_code = NA_character_,
    status = as.character(status),
    stage = as.character(stage),
    error_code = as.character(error_code),
    retryable = isTRUE(is_retryable(error_code)),
    http_status = as.integer(http_status),
    final_url = as.character(final_url),
    # Always UTC: a fresh row carries the session's timezone and a replayed one
    # carries UTC, so without this the same column prints differently
    # depending on cache state.
    fetched_at = as.POSIXct(started, tz = "UTC"),
    content_bytes = as.integer(content_bytes),
    title = as.character(parsed$title %||% NA_character_),
    description = as.character(parsed$description %||% NA_character_),
    lang = as.character(parsed$lang %||% NA_character_),
    text = as.character(parsed$text %||% NA_character_),
    html = as.character(html),
    n_tokens = as.integer(signals$n_tokens %||% 0L),
    page_state = as.character(signals$page_state %||% NA_character_),
    block_vendor = as.character(signals$block_vendor %||% NA_character_),
    robots_allowed = as.logical(robots_allowed),
    from_cache = as.logical(from_cache),
    source = as.character(source),
    snapshot_timestamp = as.character(snapshot_timestamp),
    source_last_published = if (source == "archive") {
      archive_date(snapshot_timestamp)
    } else {
      NA_character_
    }
  )
}

#' @keywords internal
#' @noRd
`%||%` <- function(x, y) if (is.null(x)) y else x # nolint: object_name_linter.

#' Fetch a single domain, returning one fully-populated row whatever happens
#' @keywords internal
#' @noRd
fetch_one <- function(domain, input, delay, timeout, max_bytes, obey_robots,
                      max_crawl_delay, max_redirects, cache_dir, cache_ttl,
                      cache_max_size, allow_hosts, archive_fallback, archive_date,
                      user_agent) {
  started <- Sys.time()
  url <- request_url(input)

  blank <- function(code, stage, http_status = NA_integer_, robots_allowed = NA,
                    source = "live") {
    fetch_row(domain, input, started,
      status = "failed", stage = stage,
      error_code = code, http_status = http_status,
      robots_allowed = robots_allowed, source = source
    )
  }

  if (!is.null(archive_date)) {
    recovered <- archive_fetch(url,
      timeout = timeout, max_bytes = max_bytes,
      user_agent = user_agent, target = archive_date
    )
    if (is.null(recovered) || !is.null(recovered$error_code)) {
      return(blank(recovered$error_code %||% "no_archive_snapshot", "fetch",
        http_status = recovered$http_status %||% NA_integer_, source = "archive"
      ))
    }
    return(acquired_row(domain, input, started, recovered$html, 200L, recovered$url,
      source = "archive", snapshot_timestamp = recovered$timestamp
    ))
  }

  # Cache hits retain the original collection time and outcome.
  hit <- cache_get(cache_dir, url, cache_ttl)
  if (!is.null(hit)) {
    return(acquired_row(domain, input, hit$fetched_at, hit$html, hit$meta$http_status,
      hit$meta$final_url,
      robots_allowed = hit$meta$robots_allowed %||% NA,
      from_cache = TRUE
    ))
  }

  fetched <- guarded_get(
    url, timeout, max_bytes, user_agent, allow_hosts,
    max_redirects, obey_robots, delay, max_crawl_delay
  )
  resp <- fetched$response
  if (is.null(resp)) {
    return(blank(fetched$error_code, fetched$stage,
      http_status = fetched$http_status %||% NA_integer_, robots_allowed = fetched$robots_allowed
    ))
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
    return(blank("content_too_large", "fetch",
      http_status = http_code,
      robots_allowed = fetched$robots_allowed
    ))
  }
  if (!is.na(ctype) && !grepl("html|xml", ctype, fixed = FALSE)) {
    return(blank("content_type_rejected", "fetch",
      http_status = http_code,
      robots_allowed = fetched$robots_allowed
    ))
  }

  final <- tryCatch(resp_url(resp), error = function(e) url)
  row <- acquired_row(domain, input, started, body, http_code, final,
    robots_allowed = fetched$robots_allowed
  )

  # Failures are not cached: they are the rows worth retrying, and caching them would
  # defeat the retry.
  if (identical(row$status, "ok")) {
    tryCatch(
      cache_put(
        cache_dir, url, body,
        meta = list(
          requested_url = url, final_url = final, http_status = http_code,
          content_bytes = bytes, status = row$status, stage = "process",
          error_code = row$error_code, robots_allowed = fetched$robots_allowed,
          fetched_at = format(started, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
        ),
        max_size = cache_max_size
      ),
      # A cache that cannot be written must not fail the fetch.
      error = function(e) NULL
    )
  }

  # A block means the site is alive and would not serve *us*. Asking an archive that was
  # allowed in is the honest response. A dead domain is deliberately not recovered this
  # way -- see R/archive.R.
  if (archive_fallback && identical(row$error_code, "bot_blocked") &&
        !tolower(url_parse(url)$hostname) %in% tolower(allow_hosts)) {
    recovered <- archive_fetch(url,
      timeout = timeout, max_bytes = max_bytes,
      user_agent = user_agent
    )
    if (!is.null(recovered) && is.null(recovered$error_code)) {
      archived <- acquired_row(domain, input, started, recovered$html, 200L, recovered$url,
        source = "archive", snapshot_timestamp = recovered$timestamp,
        robots_allowed = fetched$robots_allowed
      )
      archived$archive_error_code <- archived$error_code
      return(archived)
    }
    row <- blank(recovered$error_code %||% "no_archive_snapshot", "fetch",
      http_status = recovered$http_status %||% NA_integer_, source = "archive"
    )
    row$archive_error_code <- row$error_code
  }
  row
}

#' Process acquired HTML consistently across live, cached and archived pages
#' @keywords internal
#' @noRd
acquired_row <- function(domain, input, started, html, http_status, final_url,
                         robots_allowed = NA, from_cache = FALSE,
                         source = "live", snapshot_timestamp = NA_character_) {
  parsed <- html_text_content(html)
  signals <- page_signals(html, text = parsed$text, domain = domain, status = http_status)
  code <- if (http_status %in% c(404L, 410L)) {
    "http_not_found"
  } else if (http_status >= 300L && http_status < 400L) {
    "redirect_error"
  } else if (signals$blocked) {
    "bot_blocked"
  } else if (http_status %in% c(408L, 425L, 429L) || http_status >= 500L) {
    "http_unavailable"
  } else if (http_status < 200L || http_status >= 400L) {
    "http_error"
  } else if (!nzchar(parsed$text)) {
    "empty_text"
  } else if (signals$page_state == "thin") {
    "thin_content"
  } else {
    NA_character_
  }
  stage <- if (is.na(code) || code %in% c("empty_text", "thin_content")) "process" else "fetch"
  fetch_row(domain, input, started,
    status = if (is.na(code)) "ok" else "failed", stage = stage, error_code = code,
    http_status = http_status, final_url = final_url, content_bytes = nchar(html, type = "bytes"),
    parsed = parsed, signals = signals, robots_allowed = robots_allowed,
    from_cache = from_cache, source = source, snapshot_timestamp = snapshot_timestamp, html = html
  )
}
