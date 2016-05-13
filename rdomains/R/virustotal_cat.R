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
#' virustotal_cat(domain="http://www.google.com")
#' }

virustotal_cat <- function(domain = NULL, apikey=NULL) {
    
    params <- list(domain = domain, apikey=apikey)
    
    res <- GET("http://www.virustotal.com/vtapi/v2/domain/report", body = params)

    if (identical(content(res), NULL)) return(NULL)

    as.data.frame(do.call(cbind, content(res)))
}

