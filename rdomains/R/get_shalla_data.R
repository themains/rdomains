#' Get Shalla Data
#'
#' Downloads, unzips and saves the latest version of shallalist data.
#'  
#' @param outdir    Optional; folder to which you want to save the file; Default is same folder
#' @param overwrite Optional; default is FALSE
#' 
#' @export
#' 
#' @references \url{http://www.shallalist.de/}
#' 
#' @examples \dontrun{
#' get_shalla_data()
#' }

get_shalla_data <- function(outdir="./", overwrite=FALSE) {

	tmp <- tempfile()
	curl_download("http://www.shallalist.de/Downloads/shallalist.tar.gz", tmp)
	untar(tmp, exdir=getwd())
	list_of_files <- untar(tmp, list=TRUE)
	unlink(tmp)

	# All the shallalist domain files
	all_files    <- list_of_files
	domain_files <- all_files[grepl("domains", all_files)]
	domain_cats  <- sapply(strsplit(domain_files, "/"), "[", 2)

	# Iterate through domain_files and get a list of data.frames
	j <- 1
	res <- list()
	for (i in paste0(outdir, domain_files)) {
		cat       <- domain_cats[j]
		domains   <- read.table(i)
		res[[j]]  <- data.frame(hostname=unlist(domains), category=cat)
		j <- j + 1
	}
	
	# rbind all the data.frames	
	res2 <- do.call(rbind, res)

	# Remove the 
	unlink(paste0(outdir, paste0(all_files)), recursive = TRUE, force = TRUE)
	unlink(paste0(outdir, "BL"), recursive = TRUE, force = TRUE)

	output_file <- paste0(outdir, "shalla_domain_cateory.csv")	

	# Write to file
	if (overwrite==FALSE & file.exists(output_file)) stop("There is already a file with that name in the location. Pick another name or location.")

	write.csv(res2, file=output_file, row.names=F)
	
	cat("Shallalist Data saved to the following destination:", outdir, "\n")

}