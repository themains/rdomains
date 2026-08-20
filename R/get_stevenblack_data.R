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
#' @export
#'
#' @references \url{https://github.com/StevenBlack/hosts}
#'
#' @examples \dontrun{
#' get_stevenblack_data()
#' get_stevenblack_data(variant = "all")
#' }
get_stevenblack_data <- function(outdir = "./", variant = "base", overwrite = FALSE) {
  # Define available variants and their URLs
  variants <- list(
    base = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts",
    porn = "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn/hosts",
    social = "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/social/hosts",
    gambling = paste0(
      "https://raw.githubusercontent.com/StevenBlack/hosts/master/",
      "alternates/gambling/hosts"
    ),
    all = paste0(
      "https://raw.githubusercontent.com/StevenBlack/hosts/master/",
      "alternates/porn-social-gambling/hosts"
    )
  )

  if (!variant %in% names(variants)) {
    stop("Invalid variant. Choose from: ", paste(names(variants), collapse = ", "))
  }

  # Create output filename
  output_file <- file.path(outdir, paste0("stevenblack_hosts_", variant, ".txt"))

  # Check if file already exists
  if (!overwrite && file.exists(output_file)) {
    stop(
      "File already exists: ", output_file,
      "\nSet overwrite=TRUE to replace it."
    )
  }

  # Create output directory if it doesn't exist
  if (!dir.exists(outdir)) {
    dir.create(outdir, recursive = TRUE)
  }

  # Download the hosts file
  tryCatch(
    {
      cat("Downloading Steven Black's hosts file (", variant, " variant)...\n")
      curl::curl_download(variants[[variant]], output_file)
      cat("Steven Black's hosts data saved to:", output_file, "\n")

      # Print some statistics
      hosts_lines <- readLines(output_file, warn = FALSE)
      blocked_count <- sum(grepl("^(0\\.0\\.0\\.0|127\\.0\\.0\\.1)\\s+", hosts_lines))
      cat("Total blocked domains:", blocked_count, "\n")
    },
    error = function(e) {
      stop("Failed to download hosts file: ", e$message)
    }
  )

  invisible(output_file)
}
