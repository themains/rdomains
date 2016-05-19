#' Get Alexa Data
#'
#' @param outdir    Optional; folder to which you want to save the file; Default is same folder
#' @param overwrite Optional; default is FALSE
#' 
#'  
#' @export
#' @references \url{https://support.alexa.com/hc/en-us/articles/200461990-Can-I-get-a-list-of-top-sites-from-an-API-}
#' @examples \dontrun{
#' get_alexa_cat()
#' }

get_alexa_data <- function(outdir=".", overwrite=FALSE) {

	tmp <- tempfile()
	curl_download("http://s3.amazonaws.com/alexa-static/top-1m.csv.zip", tmp)
	unzip(tmp, exdir=outdir, overwrite=overwrite)
	unlink(tmp)

	cat("Alexa Top 1M Domains saved to the following destination:", outdir, "\n")

}