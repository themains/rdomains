#' Get Alexa Category
#'
#' @param domain domain name
#' @param apikey virustotal API key
#' 
#' @return data frame
#'  
#' @export
#' @references \url{https://docs.aws.amazon.com/AlexaWebInfoService/latest/index.html?ApiReference_UrlInfoAction.html}
#' @examples \dontrun{
#' alexa_cat(domain="http://www.google.com")
#' }

alexa_cat <- function(domain = NULL, apikey=NULL) {
    
    params <- list(Action="UrlInfo", AWSAccessKeyId=apikey, Url=domain, SignatureVersion=2, SignatureMethod='HmacSHA256', ResponseGroup="Categories")
    
     #           &=[Your AWS Access Key ID]
     #           &Signature=[signature calculated from request]
     #           &SignatureMethod=[HmacSha1 or HmacSha256]
     #           &SignatureVersion=2
     #          &Timestamp=[timestamp used in signature]
      #          &Url=[Valid URL]
       #         &ResponseGroup=[Valid Response Group]

    res <- GET("http://awis.amazonaws.com/", body = params)

    if (identical(content(res), NULL)) return(NULL)

    as.data.frame(do.call(cbind, content(res)))
}

apikey="AKIAJCDLSOSH5N4XBGLA"