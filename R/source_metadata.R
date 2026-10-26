#' Download a source while keeping retrieval and publication dates separate
#' @keywords internal
#' @noRd
download_source <- function(url, path) {
  temporary <- tempfile(tmpdir = dirname(path))
  on.exit(unlink(temporary), add = TRUE)
  response <- request(url) |>
    req_timeout(120) |>
    req_user_agent(rdomains_user_agent()) |>
    req_perform(path = temporary)
  modified <- resp_header(response, "last-modified")
  date <- if (is.null(modified)) {
    NA_character_
  } else {
    parsed <- suppressWarnings(curl::parse_date(modified))
    if (is.na(parsed)) NA_character_ else format(parsed, "%Y-%m-%d", tz = "UTC")
  }
  if (!file.copy(temporary, path, overwrite = TRUE)) cli_abort("Could not save {.file {path}}.")
  list(
    source_url = url, source_last_published = date,
    source_fetched_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
}

#' Bind source metadata to the exact downloaded or transformed file
#' @keywords internal
#' @noRd
save_source_metadata <- function(path, metadata) {
  metadata$checksum <- unname(tools::md5sum(path))
  writeLines(toJSON(metadata, auto_unbox = TRUE, na = "null"), paste0(path, ".metadata.json"))
}

#' Read verified source metadata without substituting a filesystem timestamp
#' @keywords internal
#' @noRd
load_source_metadata <- function(path) {
  empty <- list(source_last_published = NA_character_, source_fetched_at = NA_character_)
  sidecar <- paste0(path, ".metadata.json")
  if (!file.exists(sidecar)) {
    return(empty)
  }
  meta <- tryCatch(fromJSON(sidecar), error = function(e) NULL)
  if (!is.list(meta) || !identical(meta$checksum, unname(tools::md5sum(path)))) {
    return(empty)
  }
  for (name in names(empty)) {
    value <- meta[[name]]
    if (!is.character(value) || length(value) != 1L) value <- NA_character_
    empty[[name]] <- value
  }
  empty
}

#' Check a downloaded lookup table before matching its rows
#' @keywords internal
#' @noRd
validate_lookup <- function(data, columns) {
  if (!all(columns %in% names(data))) {
    cli_abort("The lookup file must contain columns {.val {columns}}.")
  }
}
