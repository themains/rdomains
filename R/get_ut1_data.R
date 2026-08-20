#' Download the UT-Capitole blacklists
#'
#' Downloads and flattens the University of Toulouse (UT1) blacklists into a single
#' `domain,category` CSV. These are the **maintained successor** to Shallalist: where
#' Shallalist last published in January 2022, UT1 is updated continuously.
#'
#' The archive carries ~69 categories under its own French-influenced vocabulary
#' (`drogue`, `publicite`, `tricheur`), which does not line up with Shallalist's names.
#' [ut1_cat()] therefore reports UT1's category verbatim rather than mapping it onto
#' another taxonomy and losing the distinction.
#'
#' A domain may appear in more than one category; the first is kept and the number of
#' multi-category domains is reported, rather than the collision being silent.
#'
#' @param outdir Optional; folder to save the file in. Default is the working directory.
#' @param overwrite Optional; default `FALSE`. If `TRUE`, an existing file is replaced.
#'
#' @return Invisibly, the path to the written CSV.
#'
#' @export
#' @references \url{https://dsi.ut-capitole.fr/blacklists/}
#' @seealso [ut1_cat()], and [source_vintage()] for how this compares with the
#'   discontinued sources.
#'
#' @examples \dontrun{
#' get_ut1_data()
#' ut1_cat("example.com")
#' }
get_ut1_data <- function(outdir = "./", overwrite = FALSE) {
  outdir <- normalizePath(outdir, mustWork = FALSE)
  if (!dir.exists(outdir)) {
    dir.create(outdir, recursive = TRUE)
  }
  output_file <- file.path(outdir, "ut1_domain_category.csv")

  if (!overwrite && file.exists(output_file)) {
    cli_abort(c(
      "File already exists: {.file {output_file}}",
      "i" = "Set {.code overwrite = TRUE} to replace it."
    ))
  }

  tmp <- tempfile(fileext = ".tar.gz")
  exdir <- tempfile()
  on.exit(unlink(c(tmp, exdir), recursive = TRUE), add = TRUE)

  cli_inform("Downloading UT-Capitole blacklists (~25 MB)...")
  tryCatch(
    curl_download(
      "https://dsi.ut-capitole.fr/blacklists/download/blacklists.tar.gz", tmp
    ),
    error = function(e) {
      cli_abort(c("Failed to download UT1 blacklists", "x" = conditionMessage(e)))
    }
  )

  # The tarball's own modification time is the list's vintage, and the whole reason to
  # prefer it over Shallalist. Preserve it onto the CSV so ut1_cat() can report it.
  published <- file.info(tmp)$mtime

  untar(tmp, exdir = exdir)
  files <- list.files(exdir, pattern = "^domains$", recursive = TRUE,
                      full.names = TRUE)
  if (!length(files)) {
    cli_abort("No category lists found in the downloaded archive.")
  }

  # UT1 declares each directory's purpose in a `usage` file: 52 are `black` (blocklists)
  # and 14 are `white` (allowlists). Both are kept, because this package classifies
  # content rather than blocking it and a whitelist named `cooking` still tells you the
  # domain is a cooking site. The `usage` value is returned so the caller can tell which.
  #
  # What is dropped is the handful of lists whose names carry no content meaning at all:
  # generic university allowlists and housekeeping directories. Keeping those is what
  # made `wikipedia.org` come back as `liste_bu`.
  CONTENTLESS <- c("liste_blanche", "liste_bu", "exceptions_liste_bu",
                   "update", "reaffected", "special", "examen_pix")
  categories <- basename(dirname(files))
  keep <- !categories %in% CONTENTLESS
  dropped_lists <- categories[!keep]
  files <- files[keep]

  usages <- vapply(files, function(f) {
    usage_file <- file.path(dirname(f), "usage")
    if (!file.exists(usage_file)) {
      return(NA_character_)
    }
    value <- str_trim(readLines(usage_file, warn = FALSE)[1])
    # A leading # is a note, not a usage value -- `phishing` says "no longer maintained".
    if (startsWith(value, "#")) NA_character_ else value
  }, character(1))

  rows <- map_df(seq_along(files), function(i) {
    f <- files[i]
    category <- basename(dirname(f))
    domains <- tryCatch(readLines(f, warn = FALSE), error = function(e) character())
    domains <- str_trim(domains)
    domains <- domains[nzchar(domains) & !startsWith(domains, "#")]
    if (!length(domains)) {
      return(tibble(domain = character(), category = character(), usage = character()))
    }
    tibble(domain = domains, category = category, usage = unname(usages[i]))
  })

  # A domain in several categories keeps the **smallest** one, which is deterministic and
  # informative: `adult` alone is 4.6M domains, so a domain also listed in `shopping`
  # (37k) is better described by shopping. Keeping "the first" made millions of
  # order-dependent choices silently.
  sizes <- table(rows$category)
  rows <- rows[order(as.integer(sizes[rows$category])), ]
  multi <- sum(duplicated(rows$domain))
  rows <- rows[!duplicated(rows$domain), ]
  rows <- rows[order(rows$domain), ]

  utils::write.csv(rows, output_file, row.names = FALSE)
  Sys.setFileTime(output_file, published)

  cli_inform(c(
    "v" = "UT1 data saved to {.file {output_file}}",
    "i" = "{nrow(rows)} domains across {length(unique(rows$category))} categories",
    "i" = "List published {format(published, '%Y-%m-%d')}",
    if (length(dropped_lists)) {
      c("i" = "Skipped {length(dropped_lists)} list{?s} with no content meaning: {.val {dropped_lists}}")
    },
    if (multi > 0) {
      c("i" = "{multi} domain{?s} were in more than one category; kept the most specific")
    }
  ))
  invisible(output_file)
}
