#' Get Shalla Data
#'
#' Shallalist service was discontinued in January 2022. This function downloads
#' the last archived copy (from 1/14/22) that we have preserved on GitHub.
#' The original service at shallalist.de is no longer available.
#' Downloads, unzips and saves the final version of shallalist data. By default, saves shalla data
#' as \code{shalla_domain_category.csv}.
#'
#' @param outdir    Optional; folder to which you want to save the file; Default is same folder
#' @param overwrite Optional; default is FALSE. If TRUE, the file is overwritten.
#'
#' @export
#'
#' @references \url{https://web.archive.org/web/20210502020725/http://www.shallalist.de/}
#'
#' @examples \dontrun{
#' get_shalla_data()
#' }
get_shalla_data <- function(outdir = ".", overwrite = FALSE) {
  output <- source_destination(outdir, "shalla_domain_category.csv", overwrite)
  tmp <- tempfile(fileext = ".gz")
  on.exit(unlink(tmp), add = TRUE)
  metadata <- download_source(SOURCE_VINTAGE$shalla$url, tmp)
  R.utils::gunzip(tmp, destname = output, overwrite = overwrite)
  metadata$source_last_published <- SOURCE_VINTAGE$shalla$last_published
  save_source_metadata(output, metadata)
  invisible(output)
}
