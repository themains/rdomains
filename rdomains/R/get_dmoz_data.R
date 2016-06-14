#' Get DMOZ Data
#'
#' Downloads, unzips and saves archived version of the DMOZ data. For more details, check:
#' \url{https://github.com/soodoku/domain_classifier/tree/master/rdomains/data-raw/dmoz}
#'  
#' @param outdir    Optional; folder to which you want to save the file; Default is same folder
#' @param overwrite Optional; default is FALSE. If TRUE, the file is overwritten.
#' 
#' @export
#' 
#' @references \url{http://www.dmoz.org/}
#' 
#' @examples \dontrun{
#' get_dmoz_data()
#' }

get_dmoz_data <- function(outdir=".", overwrite=FALSE) {

	tmp <- tempfile()
	curl_download("https://github.com/soodoku/domain_classifier/blob/master/rdomains/data-raw/dmoz/dmoz_domain_cateory.csv.zip?raw=true", tmp)

	dmoz_file <- paste0(outdir, "dmoz_domain_cateory.csv")	

	if (file.exists(dmoz_file) & overwrite==FALSE) stop(paste0("There already exists a file with the same name.\n The file was last updated on ", 
																file.info(dmoz_file)$mtime,
																".\n If you want to update the file, set overwrite to TRUE"))

	unzip(tmp, exdir=outdir, overwrite=overwrite)
	unlink(tmp)
	
	cat("DMOZ Data saved to the following destination:", outdir, "\n")

}