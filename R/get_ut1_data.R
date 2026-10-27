#' Download the UT-Capitole blacklists
#'
#' Downloads and flattens the University of Toulouse (UT1) blacklists into a single
#' `domain,category,usage` CSV. These are the **maintained successor** to Shallalist: where
#' Shallalist last published in January 2022, UT1 is updated continuously.
#'
#' The archive carries ~69 categories under its own French-influenced vocabulary
#' (`drogue`, `publicite`, `tricheur`), which does not line up with Shallalist's names.
#' [ut1_cat()] therefore reports UT1's category verbatim rather than mapping it onto
#' another taxonomy and losing the distinction.
#'
#' A domain may appear in more than one category. Every membership is retained;
#' duplicate identical records are removed and rows are sorted by domain and category.
#'
#' @param outdir Optional; folder to save the file in. Default is the working directory.
#' @param overwrite Optional; default `FALSE`. If `TRUE`, an existing file is replaced.
#'
#' @return Invisibly, the path to the written CSV.
#'
#' @export
#' @references \url{https://dsi.ut-capitole.fr/blacklists/download/blacklists.tar.gz}
#' @seealso [ut1_cat()], and [source_vintage()] for how this compares with the
#'   discontinued sources.
#'
#' @examples \dontrun{
#' get_ut1_data()
#' ut1_cat("example.com")
#' }
get_ut1_data <- function(outdir = "./", overwrite = FALSE) {
  output_file <- source_destination(outdir, "ut1_domain_category.csv", overwrite)
  tmp <- tempfile(fileext = ".tar.gz")
  exdir <- tempfile()
  on.exit(unlink(c(tmp, exdir), recursive = TRUE), add = TRUE)

  cli_inform("Downloading UT-Capitole blacklists (~25 MB)...")
  metadata <- tryCatch(
    download_source(
      SOURCE_VINTAGE$ut1$url, tmp
    ),
    error = function(e) {
      cli_abort(c("Failed to download UT1 blacklists", "x" = conditionMessage(e)))
    }
  )

  untar(tmp, exdir = exdir)
  files <- list.files(exdir,
    pattern = "^domains$", recursive = TRUE,
    full.names = TRUE
  )
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
  CONTENTLESS <- c(
    "liste_blanche", "liste_bu", "exceptions_liste_bu",
    "update", "reaffected", "special", "examen_pix"
  )
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
    if (is.na(value) || startsWith(value, "#")) NA_character_ else value
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

  rows <- unique(rows)
  rows <- rows[order(rows$domain, rows$category, rows$usage), ]
  multi <- sum(duplicated(rows$domain))

  utils::write.csv(rows, output_file, row.names = FALSE)
  save_source_metadata(output_file, metadata)

  cli_inform(c(
    "v" = "UT1 data saved to {.file {output_file}}",
    "i" = "{nrow(rows)} domains across {length(unique(rows$category))} categories",
    "i" = "Source publication date: {metadata$source_last_published}",
    if (length(dropped_lists)) {
      c("i" = paste(
        "Skipped {length(dropped_lists)} list{?s} with no content meaning:",
        "{.val {dropped_lists}}"
      ))
    },
    if (multi > 0) {
      c("i" = "{multi} domain{?s} have additional category memberships; all are retained")
    }
  ))
  invisible(output_file)
}
