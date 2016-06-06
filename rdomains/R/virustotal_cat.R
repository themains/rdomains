#' Get Category from Virustotal
#'
#' Returns category of content from 6 major services including: BitDefender, Dr. Web, Alexa (DMOZ), Google, 
#' Websense, and Trendmicro
#' 
#' Get the API Access Key from \url{http://www.virustotal.com/}. Either pass the API Key to the function 
#' or set the environmental variables \code{VirustotalToken}. These environment variables persist within 
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

  res <-  domain_report(domain)

  cat_names <- c("BitDefender category", "Dr.Web category", "Alexa category", "categories", "Websense ThreatSeeker category", "TrendMicro category")

  # do.call(rbind, lapply(sapply(res[which(names(res) %in% cat_names)], cbind), as.data.frame)) (multiple cat by Google)

  d_res <- as.data.frame(do.call(cbind, sapply(res[which(names(res) %in% cat_names)], "[", 1)))
  names(d_res)[names(d_res) %in% cat_names] <- c("bitdefender", "dr_web", "alexa", "google", "websense", "trendmicro")

  data.frame(domain, d_res)         
    
}

