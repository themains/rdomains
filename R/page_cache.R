#' Cache fetched pages on disk
#'
#' Mirrors the sibling Python package's `DataCollector` cache (`html/` plus a metadata
#' sidecar), with three fixes to defects in it:
#'
#' * **A TTL.** piedomains has none, so its cache is permanent by accident and a page
#'   fetched in 2022 is still served as current.
#' * **A size cap**, pruned oldest-first, so a large crawl cannot fill the disk.
#' * **Hits replay stored provenance.** `data_collector.py` synthesises
#'   `fetch_success: True` and a fresh timestamp on a hit -- it reports a fetch that never
#'   happened, at a time it did not happen. Here a hit returns the *stored* `fetched_at`,
#'   the *stored* `final_url` and the *stored* status, and flags `from_cache`.
#'
#' Nothing is written outside `tempdir()` unless the caller asks: CRAN policy forbids
#' writing to a user's home space without consent, so persistence is opt-in via
#' [rdomains_cache_dir()].
#'
#' @keywords internal
#' @noRd
NULL

#' A persistent cache directory for fetched pages
#'
#' Returns the conventional per-user cache location for the package. It deliberately does
#' **not** create the directory: pass it to [collect_content()] to opt in, and until you do
#' nothing is written outside the session's temporary directory.
#'
#' @return Path to the per-user cache directory, as a string.
#'
#' @export
#' @examples
#' rdomains_cache_dir()
#' \dontrun{
#' # opt in to caching that survives the session
#' collect_content("example.com", cache_dir = rdomains_cache_dir())
#' }
rdomains_cache_dir <- function() {
  tools::R_user_dir("rdomains", "cache")
}

#' Where the session cache lives when the caller has not chosen
#' @keywords internal
#' @noRd
default_cache_dir <- function() {
  file.path(tempdir(), "rdomains-cache")
}

#' Cache key for a URL
#'
#' Keyed on the URL rather than the domain: piedomains keys on the domain, so
#' `example.com/a` and `example.com/b` collide. `hash()` is already available --
#' no new dependency for a digest.
#'
#' @param url the requested URL
#' @return a hex key
#' @keywords internal
#' @noRd
cache_key <- function(url) {
  hash(tolower(trimws(url)))
}

#' Paths for one cache entry, sharded two levels deep
#'
#' Sharding matters at 100k domains; piedomains puts every file in one directory.
#'
#' @param dir cache root
#' @param key cache key
#' @return list(html, meta)
#' @keywords internal
#' @noRd
cache_paths <- function(dir, key) {
  shard <- substr(key, 1, 2)
  list(
    html = file.path(dir, "v1", "html", shard, paste0(key, ".html.gz")),
    meta = file.path(dir, "v1", "meta", shard, paste0(key, ".json"))
  )
}

#' Read a cache entry, or NULL when absent, stale or unreadable
#'
#' @param dir cache root
#' @param url requested URL
#' @param ttl seconds an entry stays fresh
#' @return list(meta, html) or NULL
#' @keywords internal
#' @noRd
cache_get <- function(dir, url, ttl) {
  paths <- cache_paths(dir, cache_key(url))
  if (!file.exists(paths$meta) || !file.exists(paths$html)) {
    return(NULL)
  }
  meta <- tryCatch(
    fromJSON(paths$meta),
    error = function(e) NULL
  )
  # A corrupt sidecar is a miss, not an error: the cache must never be the reason a run
  # fails.
  if (is.null(meta) || is.null(meta$fetched_at)) {
    return(NULL)
  }
  fetched <- tryCatch(
    as.POSIXct(meta$fetched_at, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    error = function(e) NA
  )
  if (is.na(fetched) || difftime(Sys.time(), fetched, units = "secs") > ttl) {
    return(NULL)
  }
  html <- tryCatch(
    {
      con <- gzfile(paths$html, "rt")
      on.exit(close(con), add = TRUE)
      paste(readLines(con, warn = FALSE), collapse = "\n")
    },
    error = function(e) NULL
  )
  if (is.null(html)) {
    return(NULL)
  }
  list(meta = meta, html = html, fetched_at = fetched)
}

#' Write a cache entry
#'
#' @param dir cache root
#' @param url requested URL
#' @param html response body
#' @param meta named list of provenance
#' @param max_size prune the cache above this many bytes
#' @keywords internal
#' @noRd
cache_put <- function(dir, url, html, meta, max_size = 1024^3) {
  paths <- cache_paths(dir, cache_key(url))
  dir.create(dirname(paths$html), recursive = TRUE, showWarnings = FALSE)
  dir.create(dirname(paths$meta), recursive = TRUE, showWarnings = FALSE)

  con <- gzfile(paths$html, "wt")
  on.exit(close(con), add = TRUE)
  writeLines(html, con)

  writeLines(toJSON(meta, auto_unbox = TRUE, null = "null"), paths$meta)
  cache_prune(dir, max_size)
  invisible(TRUE)
}

#' Keep the cache under a size budget, evicting oldest first
#'
#' @param dir cache root
#' @param max_size bytes
#' @return number of entries removed
#' @keywords internal
#' @noRd
cache_prune <- function(dir, max_size) {
  root <- file.path(dir, "v1", "html")
  if (!dir.exists(root)) {
    return(invisible(0L))
  }
  files <- list.files(root, recursive = TRUE, full.names = TRUE)
  if (!length(files)) {
    return(invisible(0L))
  }
  info <- file.info(files)
  if (sum(info$size, na.rm = TRUE) <= max_size) {
    return(invisible(0L))
  }
  order_oldest <- order(info$mtime)
  removed <- 0L
  running <- sum(info$size, na.rm = TRUE)
  for (i in order_oldest) {
    if (running <= max_size) break
    key <- sub("\\.html\\.gz$", "", basename(files[i]))
    p <- cache_paths(dir, key)
    unlink(c(p$html, p$meta))
    running <- running - info$size[i]
    removed <- removed + 1L
  }
  invisible(removed)
}

#' Empty the page cache
#'
#' @param dir Cache directory. Defaults to the session cache used when
#'   [collect_content()] is called without `cache_dir`.
#'
#' @return Invisibly, the number of cached pages removed.
#'
#' @export
#' @examples
#' \dontrun{
#' cache_clear()
#' cache_clear(rdomains_cache_dir())
#' }
cache_clear <- function(dir = NULL) {
  dir <- dir %||% default_cache_dir()
  root <- file.path(dir, "v1")
  n <- if (dir.exists(file.path(root, "html"))) {
    length(list.files(file.path(root, "html"), recursive = TRUE))
  } else {
    0L
  }
  unlink(root, recursive = TRUE)
  invisible(n)
}
