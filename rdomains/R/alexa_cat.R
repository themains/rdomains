#' Get Category from Alexa
#'
#' 
#' Get the Access Key ID and Secret Access Key by logging into \url{https://console.aws.amazon.com/}, 
#' clicking on the username followed by security credentials. Either pass the access key and secret or 
#' set two environmental variables \code{AWS_ACCESS_KEY_ID} and \code{AWS_SECRET_ACCESS_KEY}. 
#' These environment variables persist within a R session. 
#'  
#' @param domain domain name
#' @param key  Alexa Access Key ID
#' @param secret Alexa Secret Access Key
#' 
#' @return data.frame with 2 columns Title and AbsolutePath 
#'  
#' @export
#' @references \url{https://docs.aws.amazon.com/AlexaWebInfoService/latest}
#' @examples \dontrun{
#' alexa_cat(domain = "http://www.google.com")
#' }

alexa_cat <- function(domain = NULL, key = NULL, secret = NULL) {
  
  if (identical(Sys.getenv("AWS_ACCESS_KEY_ID"), "") | (identical(Sys.getenv("AWS_SECRET_ACCESS_KEY"), ""))) {
    set_secret_key(key, secret)
  }

  a_cat <- url_info(url = "http://www.google.com", response_group = "Categories")

  res <- do.call(rbind, a_cat[[2]][[1]][[1]][[2]])
  return(as.data.frame(res, row.names = 1:length(res)))

}
