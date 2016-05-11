#' Get Virustotal Category
#'
#' @param domain domain name
#' @param apikey virustotal API key
#' 
#' @return data frame
#'  
#' @export
#' @references \url{https://www.virustotal.com/en/documentation/public-api/}
#' @examples \dontrun{
#' domain_report(url="http://www.google.com")
#' }

domain_report <- function(domain = NULL, apikey=NULL) {
    
    params <- list(domain = domain, apikey=apikey)
    
    res <- GET("http://www.virustotal.com/vtapi/v2/domain/report", body = params)

    if (identical(content(res), NULL)) return(NULL)

    as.data.frame(do.call(cbind, content(res)))
}

