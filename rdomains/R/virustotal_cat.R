#' Get Category from Virustotal
#'
#' Returns category of content from 6 major services including: BitDefender, Dr. Web, Alexa (DMOZ), Google, 
#' Websense, and Trendmicro. Not all services will have categories for all the domains. When the categories are
#' not returned for a particular domain, we return a NA.
#' 
#' Get the API Access Key from \url{http://www.virustotal.com/}. Either pass the API Key to the function 
#' or set the environmental variable: \code{VirustotalToken}. Environment variables persist within 
#' a R session. 
#' 
#' @param domain domain name
#' @param apikey virustotal API key
#' 
#' @return data.frame with 7 columns: domain, bitdefender, dr_web, alexa, google, websense, trendmicro
#'  
#' @export
#' @references \url{https://www.virustotal.com/en/documentation/public-api/}
#' 
#' @examples \dontrun{
#' virustotal_cat("http://www.google.com")
#' }

virustotal_cat <- function(domain = NULL, apikey=NULL) {
  
  if (identical(domain, NULL)) stop("Please provide a valid domain.")

  if (identical(Sys.getenv("VirustotalToken"), "")) {
      set_key(apikey)
   } 

  # Get domain report 
  res <-  domain_report(domain)

  # Companies from which virustotal returns domain categories 
  cat_names <- c("BitDefender category" = "bitdefender", 
                 "Dr.Web category" = "dr_web", 
                 "Alexa category" ="alexa", 
                 "categories" ="google", 
                 "Websense ThreatSeeker category" ="websense", 
                 "TrendMicro category"="trendmicro")

  # If domain not found, return a data.frame with domain name + NAs
  if (res$verbose_msg=="Domain not found") {
      d_res     <- read.table(text = "", col.names=cat_names)
      d_res[1,] <- NA
  } else {
    # If results are returned
    # do.call(rbind, lapply(sapply(res[which(names(res) %in% cat_names)], cbind), as.data.frame)) (multiple cat by Google)
    d_res <- as.data.frame(do.call(cbind, sapply(res[which(names(res) %in% names(cat_names))], "[", 1)))
    names(d_res) <- cat_names[match(names(d_res), names(cat_names))]
    d_res[,cat_names[!(cat_names %in% names(d_res))]] <- NA
    d_res <- d_res[,names(d_res)[order(cat_names)]] # Reorder so that we always get same order of columns
  }

  # Return
  data.frame(domain, d_res)         
  
}

