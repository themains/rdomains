#' Get Shalla Data
#'
#' Shalla has discontinued. We downloaded the last copy (1/14/22).
#' For more information see data-raw folder on github
#' Downloads, unzips and saves the latest version of shallalist data. By default, saves shalla data  
#' as \code{shalla_domain_category.csv}.
#'  
#' @param outdir    Optional; folder to which you want to save the file; Default is same folder
#' @param overwrite Optional; default is FALSE. If TRUE, the file is overwritten.
#' 
#' @export
#' 
#' @references \url{http://www.shallalist.de/}
#' 
#' @examples \dontrun{
#' get_shalla_data()
#' }

get_shalla_data <- function(outdir = "./", overwrite = FALSE) {

  # Check if file already there
  output_file <- paste0(outdir, "shalla_domain_category.csv")
  if (overwrite == FALSE & file.exists(output_file)) {
    stop("There is already a file with that name in the location.
          Pick another name or location.")
  }

  tmp <- tempfile()
  curl_download("https://raw.githubusercontent.com/themains/rdomains/master/data-raw/shallalist/accomplist/shallalist.gz", tmp)
  gunzip(tmp, destname = output_file, overwrite = overwrite)
  unlink(tmp, force = TRUE)

  cat("Shallalist Data saved to the following destination:", outdir, "\n")
}
