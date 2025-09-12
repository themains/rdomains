#' Get Category from Steven Black's Host List
#'
#' Classifies domains based on Steven Black's unified host list which blocks
#' ads, malware, and tracking domains. The function checks if a domain appears
#' in the blocklist and categorizes it accordingly.
#' 
#' Steven Black's host list is a consolidated list from multiple sources including
#' adaway.org, mvps.org, malwaredomainlist.com, and someonewhocares.org.
#' 
#' @param domain domain names as character vector
#' @param use_file path to a local Steven Black hosts file. If NULL, downloads from GitHub
#' 
#' @return data.frame with original domain name and category
#'  
#' @export
#' @references \url{https://github.com/StevenBlack/hosts}
#' 
#' @examples \dontrun{
#' stevenblack_cat("doubleclick.net")
#' stevenblack_cat(c("google.com", "googleadservices.com", "malware-example.com"))
#' }

stevenblack_cat <- function(domain = NULL, use_file = NULL) {
  
  if (is.null(domain)) {
    stop("Please provide at least one domain.")
  }
  
  # Clean domains
  clean_domains <- gsub("^https?://", "", domain)
  clean_domains <- gsub("^www\\.", "", clean_domains)
  clean_domains <- gsub("/.*$", "", clean_domains)
  
  # Get or load hosts data
  if (is.null(use_file)) {
    hosts_file <- tempfile()
    tryCatch({
      cat("Downloading Steven Black's hosts file...\n")
      curl::curl_download(
        "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts",
        hosts_file
      )
    }, error = function(e) {
      stop("Failed to download hosts file: ", e$message)
    })
  } else {
    if (!file.exists(use_file)) {
      stop("File not found: ", use_file)
    }
    hosts_file <- use_file
  }
  
  # Read and parse hosts file
  tryCatch({
    hosts_lines <- readLines(hosts_file, warn = FALSE)
  }, error = function(e) {
    stop("Failed to read hosts file: ", e$message)
  })
  
  # Extract blocked domains (lines starting with 0.0.0.0 or 127.0.0.1)
  blocked_lines <- hosts_lines[grepl("^(0\\.0\\.0\\.0|127\\.0\\.0\\.1)\\s+", hosts_lines)]
  
  # Parse domain names from blocked lines
  blocked_domains <- sub("^(0\\.0\\.0\\.0|127\\.0\\.0\\.1)\\s+", "", blocked_lines)
  blocked_domains <- trimws(blocked_domains)
  
  # Remove comments and empty lines
  blocked_domains <- blocked_domains[!grepl("^#", blocked_domains)]
  blocked_domains <- blocked_domains[blocked_domains != ""]
  blocked_domains <- blocked_domains[blocked_domains != "localhost"]
  
  # Classify domains
  results <- data.frame(
    domain = domain,
    stevenblack = "safe",
    stringsAsFactors = FALSE
  )
  
  # Check each clean domain against blocklist
  for (i in seq_along(clean_domains)) {
    if (clean_domains[i] %in% blocked_domains) {
      # Categorize based on common patterns
      if (grepl("(ad|ads|doubleclick|googleadservices|googlesyndication)", clean_domains[i], ignore.case = TRUE)) {
        results$stevenblack[i] <- "ads"
      } else if (grepl("(malware|virus|trojan|phishing)", clean_domains[i], ignore.case = TRUE)) {
        results$stevenblack[i] <- "malware"
      } else if (grepl("(track|analytics|metric|stats)", clean_domains[i], ignore.case = TRUE)) {
        results$stevenblack[i] <- "tracking"
      } else {
        results$stevenblack[i] <- "blocked"
      }
    }
  }
  
  # Clean up temp file if we downloaded it
  if (is.null(use_file)) {
    unlink(hosts_file)
  }
  
  return(results)
}