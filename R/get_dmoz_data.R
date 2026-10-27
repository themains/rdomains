#' Get DMOZ Data
#'
#' Downloads archived DMOZ (Open Directory Project) data. DMOZ was discontinued in March 2017.
#' This function downloads our preserved 2015 DMOZ snapshot. For more details, check:
#' \url{https://github.com/themains/rdomains/tree/master/data-raw/dmoz/}
#'
#' @param outdir    Optional; folder to which you want to save the file; Default is same folder
#' @param overwrite Optional; default is FALSE. If TRUE, the file is overwritten.
#'
#' @return Invisibly, the absolute path to the downloaded file.
#' @export
#'
#' @references \url{https://archive.org/details/dmoz-rdf-20150327}
#'
#' @examples \dontrun{
#' get_dmoz_data()
#' }
get_dmoz_data <- function(outdir = ".", overwrite = FALSE) {
  output <- source_destination(outdir, "dmoz_domain_category.csv", overwrite)
  tmp <- tempfile(fileext = ".zip")
  on.exit(unlink(tmp), add = TRUE)
  metadata <- download_source(SOURCE_VINTAGE$dmoz$url, tmp)
  unzip(tmp, exdir = dirname(output), overwrite = overwrite)
  metadata$source_last_published <- SOURCE_VINTAGE$dmoz$last_published
  save_source_metadata(output, metadata)
  invisible(output)
}
