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

get_shalla_data <- function(outdir = "./", overwrite = FALSE) {

  # Normalize and create output directory path
  outdir <- normalizePath(outdir, mustWork = FALSE)
  if (!dir.exists(outdir)) {
    tryCatch({
      dir.create(outdir, recursive = TRUE)
    }, error = function(e) {
      stop("Cannot create output directory: ", outdir, "\n", 
           "Error: ", e$message, "\n",
           "Please check directory permissions.")
    })
  }
  
  # Use proper file path construction
  output_file <- file.path(outdir, "shalla_domain_category.csv")
  
  # Check if file already exists
  if (!overwrite && file.exists(output_file)) {
    stop("File already exists: ", output_file, "\n",
         "Set overwrite=TRUE to replace it or choose a different location.")
  }

  # Create temporary file in a writable location
  tmp_dir <- tempdir()
  tmp <- tempfile(tmpdir = tmp_dir, fileext = ".gz")
  
  tryCatch({
    # Download file
    cat("Downloading Shallalist data...\n")
    curl::curl_download(
      "https://raw.githubusercontent.com/themains/rdomains/master/data-raw/shallalist/accomplist/shallalist.gz", 
      tmp
    )
    
    # Extract to destination with proper error handling
    R.utils::gunzip(tmp, destname = output_file, overwrite = overwrite)
    
    # Verify the file was created successfully
    if (!file.exists(output_file)) {
      stop("Failed to create output file. Please check write permissions for: ", outdir)
    }
    
    cat("Shallalist data saved to:", output_file, "\n")
    
  }, error = function(e) {
    # Clean up temp file on error
    if (file.exists(tmp)) unlink(tmp, force = TRUE)
    
    if (grepl("permission", e$message, ignore.case = TRUE)) {
      stop("Permission denied. Please ensure you have write access to: ", outdir, "\n",
           "On Windows, try running R as administrator or choose a different output directory.")
    } else {
      stop("Error downloading or extracting Shallalist data: ", e$message)
    }
  })
  
  # Clean up temp file
  if (file.exists(tmp)) unlink(tmp, force = TRUE)
  
  invisible(output_file)
}
