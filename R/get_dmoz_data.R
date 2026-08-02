#' Get DMOZ Data
#'
#' Downloads archived DMOZ (Open Directory Project) data. DMOZ was discontinued in March 2017.
#' This function downloads our preserved copy of the final DMOZ dataset. For more details, check:
#' \url{https://github.com/themains/rdomains/tree/master/data-raw/dmoz/}
#'
#' @param outdir    Optional; folder to which you want to save the file; Default is same folder
#' @param overwrite Optional; default is FALSE. If TRUE, the file is overwritten.
#'
#' @export
#'
#' @references \url{https://archive.org/details/dmoz-rdf-20150327}
#'
#' @examples \dontrun{
#' get_dmoz_data()
#' }

get_dmoz_data <- function(outdir = ".", overwrite = FALSE) {

  # file.path, not paste0: with the documented default of outdir = "." the old form
  # produced ".dmoz_domain_category.csv" -- a hidden file that the matching dmoz_cat()
  # lookup would then fail to find. get_shalla_data() and get_stevenblack_data() were
  # already correct.
  dmoz_file <- file.path(outdir, "dmoz_domain_category.csv")

  if (file.exists(dmoz_file) & overwrite == FALSE) {
    stop(paste0("There already exists a file with the same name.\n
                The file was last updated on ",
                file.info(dmoz_file)$mtime,
                ".\n If you want to update the file, set overwrite to TRUE"))
  }

  tmp <- tempfile()
  curl_download(
    paste0("https://github.com/themains/rdomains/blob/master/data-raw/dmoz/",
           "dmoz_domain_category.zip?raw=TRUE"),
           tmp
           )
  unzip(tmp, exdir = outdir, overwrite = overwrite)
  unlink(tmp)

  cat("DMOZ Data saved to the following destination:", outdir, "\n")
}
