#' Get Alexa Traffic Data
#' 
#' Get Top 1M most visited domains list from Alexa. These data can be used to weight the 
#' classification error.
#'
#' @param outdir    Optional; folder to which you want to save the file; Default is same folder
#' @param overwrite Optional; default is FALSE. If TRUE, the file is overwritten.
#' 
#'  
#' @export
#' @references \url{https://support.alexa.com/hc/en-us/articles/200461990-Can-I-get-a-list-of-top-sites-from-an-API-}
#' @examples \dontrun{
#' get_alexa_data()
#' }

get_alexa_data <- function(outdir=".", overwrite=FALSE) {

  alexa_file <- paste0(outdir, "/", "top-1m.csv")

  if (file.exists(alexa_file) & overwrite == FALSE) stop(paste0("There already exists a file with the same name.\n The file was last updated on ", 
                                file.info(alexa_file)$mtime,
                                ".\n If you want to update the file, set overwrite to TRUE"))

  tmp <- tempfile()
  curl_download("http://s3.amazonaws.com/alexa-static/top-1m.csv.zip", tmp)
  unzip(tmp, exdir = outdir, overwrite = overwrite)
  unlink(tmp)

  cat("Alexa Top 1M Domains saved to the following destination:", outdir, "\n")

}
