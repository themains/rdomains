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
#' @return data.frame with 86 columns: domain, bitdefender, dr_web, alexa, google, websense, trendmicro
#'  
#' @export
#' @references \url{https://developers.virustotal.com/v2.0/reference}
#' 
#' @examples \dontrun{
#' virustotal_cat("http://www.google.com")
#' }

virustotal_cat <- function(domain = NULL, apikey = NULL) {

  if (identical(domain, NULL)) stop("Please provide a valid domain.")

  if (identical(Sys.getenv("VirustotalToken"), "")) {
    set_key(apikey)
  }

  # Get domain report
  res <-  tryCatch(
    get_domain_info(domain),
    error = function(e) {
      message("An error occurred: ", conditionMessage(e))
      data.frame()
  })

  if (nrow(res) != 0){
    # If results are returned
    d_res <- as.data.frame(
      lapply(res$data$attributes$last_analysis_results, function(x) x$category))
    
    return(data.frame(domain, res))
  } else {
    return(data.frame(domain))
  }

}
