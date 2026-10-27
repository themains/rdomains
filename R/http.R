#' Fetch one resource with address and redirect checks
#' @keywords internal
#' @noRd
guarded_get <- function(url, timeout, max_bytes, user_agent,
                        allow_hosts = character(), max_redirects = 5L,
                        obey_robots = FALSE, delay = 0, max_crawl_delay = 30) {
  current <- url
  allowed <- NA
  fail <- function(code, stage = "fetch", http_status = NA_integer_) {
    list(
      response = NULL, error_code = code, stage = stage, robots_allowed = allowed,
      http_status = http_status
    )
  }
  for (hop in seq_len(max_redirects + 1L)) {
    bad <- check_url(current, allow_hosts = allow_hosts)
    if (!is.null(bad)) {
      return(fail(bad, if (bad == "dns_error") "fetch" else "validate"))
    }
    parsed <- url_parse(current)
    crawl_delay <- delay
    if (obey_robots) {
      origin <- paste0(
        parsed$scheme, "://", parsed$hostname,
        if (!is.null(parsed$port)) paste0(":", parsed$port) else ""
      )
      rules <- robots_for_origin(origin,
        timeout = timeout, allow_hosts = allow_hosts,
        user_agent = user_agent
      )
      if (!is.null(rules$error_code)) {
        return(fail(rules$error_code, http_status = rules$status))
      }
      path <- sub("^[^:]+://[^/]+", "", httr2::url_build(parsed))
      if (!is.null(rules$error_code)) {
        return(fail(rules$error_code, http_status = rules$status))
      }
      path <- sub("#.*$", "", path)
      if (!nzchar(path)) path <- "/"
      allowed <- robots_path_allowed(rules$rules, path)
      if (!allowed || (!is.na(rules$crawl_delay) && rules$crawl_delay > max_crawl_delay)) {
        allowed <- FALSE
        return(fail("robots_blocked", "validate"))
      }
      if (!is.na(rules$crawl_delay)) crawl_delay <- max(crawl_delay, rules$crawl_delay)
    }
    resp <- tryCatch(
      {
        req <- request(current) |>
          req_user_agent(user_agent) |>
          req_timeout(timeout) |>
          req_retry(max_tries = 2, max_seconds = 30) |>
          req_error(is_error = function(resp) FALSE) |>
          req_options(maxfilesize_large = max_bytes, followlocation = FALSE)
        if (crawl_delay > 0) {
          req <- req_throttle(req,
            capacity = 1L, fill_time_s = crawl_delay,
            realm = paste0("rdomains:", tolower(parsed$hostname))
          )
        }
        req_perform(req)
      },
      error = function(e) e
    )
    if (inherits(resp, "condition")) {
      return(fail(classify_condition(resp)))
    }
    code <- resp_status(resp)
    location <- resp_header(resp, "location")
    has_location <- !is.null(location) && nzchar(location)
    if (!(code %in% c(301L, 302L, 303L, 307L, 308L)) || !has_location) {
      if (length(resp$body) > max_bytes) {
        return(fail("content_too_large"))
      }
      return(list(
        response = resp, error_code = NA_character_, stage = "fetch",
        robots_allowed = allowed
      ))
    }
    if (hop == max_redirects + 1L) {
      return(fail("too_many_redirects"))
    }
    current <- tryCatch(url_absolute(location, current), error = function(e) NA_character_)
    if (is.na(current)) {
      return(fail("invalid_domain", "validate"))
    }
  }
}
