#' Get Steven Black's Host List Data
#'
#' Downloads the latest version of Steven Black's unified hosts file.
#' The hosts file contains domains known for serving ads, malware, and tracking.
#'
#' @param outdir    Optional; folder to save the file in. Default is the
#'   current directory
#' @param variant   Optional; which variant to download. Options: "base",
#'   "porn", "social", "gambling", "all"
#' @param overwrite Optional; default is FALSE. If TRUE, the file is overwritten.
#'
#' @return Invisibly, the absolute path to the downloaded file.
#' @export
#'
#' @references \url{https://github.com/StevenBlack/hosts}
#'
#' @examples \dontrun{
#' get_stevenblack_data()
#' get_stevenblack_data(variant = "all")
#' }
get_stevenblack_data <- function(outdir = ".", variant = "base", overwrite = FALSE) {
  variants <- c("base", "porn", "social", "gambling", "all")
  assert_character(variant, len = 1, any.missing = FALSE)
  if (!variant %in% variants) cli_abort("Unknown {.arg variant}: {.val {variant}}.")
  output <- source_destination(outdir, paste0("stevenblack_hosts_", variant, ".txt"), overwrite)
  suffix <- if (variant == "base") {
    "hosts"
  } else {
    paste0(
      "alternates/",
      if (variant == "all") "gambling-porn-social" else variant, "/hosts"
    )
  }
  metadata <- download_source(sub("hosts$", suffix, SOURCE_VINTAGE$stevenblack$url), output)
  save_source_metadata(output, metadata)
  invisible(output)
}
