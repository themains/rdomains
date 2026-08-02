#' Provenance for the category sources
#'
#' A label has a date. Serving it without one is the bug this file exists to fix.
#'
#' Two of the lookup sources in this package are no longer published: DMOZ closed in
#' March 2017 and Shallalist stopped in 2022. Their labels were correct when they were
#' assigned, but domains expire and get re-registered, so a lookup today can return a
#' category that describes a site which no longer exists. Before this, that answer was
#' presented identically to one from a list updated last week.
#'
#' The sibling project piedomains measured the cost of exactly this confusion: its worst
#' class disagreed with its own page content 71% of the time, and the cause was not bad
#' annotation but a decade between the label and the page. Only 60% of the domains it
#' trained on still resolve.
#'
#' @keywords internal
#' @noRd
.rdomains_env <- new.env(parent = emptyenv())

#' Known vintage of each category source
#'
#' @keywords internal
#' @noRd
SOURCE_VINTAGE <- list(
  shalla = list(
    # get_shalla_data() preserves the final release, dated 2022-01-14.
    source = "Shallalist",
    last_published = "2022-01",
    status = "discontinued",
    note = paste(
      "Shallalist stopped publishing in 2022 and individual entries may be",
      "considerably older. A domain that has changed hands since will carry the",
      "previous registrant's category."
    ),
    successor = "UT-Capitole blacklists (https://dsi.ut-capitole.fr/blacklists/)"
  ),
  dmoz = list(
    source = "DMOZ / Open Directory Project",
    last_published = "2017-03",
    status = "discontinued",
    note = paste(
      "DMOZ closed in March 2017. These labels are at least that old, and the",
      "archived snapshot this package ships is from 2015."
    ),
    successor = "Curlie (https://curlie.org)"
  ),
  stevenblack = list(
    source = "Steven Black unified hosts",
    last_published = NA_character_,
    status = "maintained",
    note = "Updated frequently; the returned date is the fetched file's own.",
    successor = NA_character_
  ),
  uni = list(
    source = "Hipo university-domains-list",
    last_published = NA_character_,
    status = "maintained",
    note = "Community-maintained; no formal release cadence.",
    successor = NA_character_
  )
)

#' Report what each category source is and when it was last published
#'
#' Every lookup in this package answers from a static list, and those lists have very
#' different vintages. Two of them are no longer published at all. Use this to see which
#' answers can be trusted to describe a domain as it is today.
#'
#' @param source Optional; one of \code{"shalla"}, \code{"dmoz"}, \code{"stevenblack"},
#'   \code{"uni"}. If \code{NULL}, every source is returned.
#'
#' @return A tibble with one row per source: \code{key}, \code{source},
#'   \code{last_published}, \code{status}, \code{successor} and \code{note}.
#'
#' @export
#' @examples
#' source_vintage()
#' source_vintage("dmoz")
source_vintage <- function(source = NULL) {
  keys <- names(SOURCE_VINTAGE)
  if (!is.null(source)) {
    assert_character(source, len = 1)
    if (!source %in% keys) {
      cli_abort(c(
        "Unknown source: {.val {source}}",
        "i" = "Known sources: {.val {keys}}"
      ))
    }
    keys <- source
  }

  map_df(keys, function(key) {
    entry <- SOURCE_VINTAGE[[key]]
    tibble(
      key = key,
      source = entry$source,
      last_published = entry$last_published,
      status = entry$status,
      successor = entry$successor,
      note = entry$note
    )
  })
}

#' Warn once per session that a source is no longer published
#'
#' Once per session rather than once per call: a warning on every lookup is a warning
#' people learn to filter out, which leaves them no better informed than no warning at all.
#'
#' @param source key into \code{SOURCE_VINTAGE}
#' @return invisibly, whether a warning was emitted
#' @keywords internal
#' @noRd
warn_source_vintage <- function(source) {
  entry <- SOURCE_VINTAGE[[source]]
  if (is.null(entry) || !identical(entry$status, "discontinued")) {
    return(invisible(FALSE))
  }

  flag <- paste0("warned_", source)
  if (isTRUE(.rdomains_env[[flag]])) {
    return(invisible(FALSE))
  }
  .rdomains_env[[flag]] <- TRUE

  cli_warn(c(
    "{entry$source} is no longer published (last: {entry$last_published}).",
    "!" = entry$note,
    "i" = if (!is.na(entry$successor)) "Successor: {entry$successor}" else NULL,
    "i" = "See {.fn source_vintage}. This warning appears once per session."
  ))
  invisible(TRUE)
}

#' Reset the once-per-session warning state
#'
#' Exists so tests can assert the warning fires, and fires only once.
#'
#' @keywords internal
#' @noRd
reset_vintage_warnings <- function() {
  rm(list = ls(envir = .rdomains_env), envir = .rdomains_env)
  invisible(NULL)
}
