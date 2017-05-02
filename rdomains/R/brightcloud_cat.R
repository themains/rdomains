#' Get Category from Brightcloud
#'
#' Returns category of content from Brighcloud
#' 
#' Get the API Consumer Key and Secret from \url{http://www.brightcloud.com/}. 
#' 
#' @param domain domain name
#' @param key brightcloud API consumer key
#' @param secret brightcloud API consumer secret
#' 
#' @return named list
#'  
#' @export
#' @references \url{http://www.brightcloud.com/}
#' 
#' @examples \dontrun{
#' brightcloud_cat("http://www.google.com", key = "XXXX", secret = "XXXX")
#' }
#' 

brightcloud_cat <- function(domain = NULL, key = NULL, secret = NULL) {

  rest_endpoint <- "http://thor.brightcloud.com:80/rest"
  uri_info_path <- "uris"
  domain_encode <- URLencode(domain)
  endpoint  <- paste0(rest_endpoint, "/", uri_info_path, "/", domain_encode)

  # OAuth Signature
  consumer  <- oauth_app("brightcloud", key, secret)
  oauth <- oauth_signature(url = endpoint,
                           method = "GET",
                           app = consumer, "", "")

  # make header from OAuth parameters
  oauth <- c(list("realm" = "http://thor.brightcloud.com/rest",
                  "oauth_consumer_key" = key,
                  "oauth_token" =  ""),
                   oauth)[c("realm", "oauth_version", "oauth_nonce",
                         "oauth_timestamp", "oauth_consumer_key", "oauth_token",
                         "oauth_signature_method", "oauth_signature")]

  h <- add_headers(Authorization = paste0("OAuth
                  realm=\"http://thor.brightcloud.com/rest\", ",
                  paste(names(oauth), paste0("\"", oauth, "\""),
                  sep = "=", collapse = ", ")))

  # request, with header
  as_list(read_xml(content(GET(endpoint, h), "raw")))
}


# API endpoint
rest_endpoint <- "http://thor.brightcloud.com:80/rest"
uri_info_path <- "uris"
domain_name <- "www.google.com"
domain_encode <- URLencode(domain_name)
endpoint  <- paste0(rest_endpoint, "/", uri_info_path, "/", domain_encode)

# OAuth Signature
consumer  <- oauth_app('brightcloud','987bac2c9988f4f49ff9ec352356a5',
'f97dae165bd5cf62f64e99af9db385b33edfec33')
oauth <- oauth_signature(url = endpoint, method = "GET", app = consumer, "", "")

# make header from OAuth parameters
oauth <- c(list("realm" = "http://thor.brightcloud.com/rest",
"oauth_consumer_key" = '987bac2c9988f4f49ff9ec352356a5', "oauth_token"
= ""), oauth)[c("realm", "oauth_version", "oauth_nonce",
"oauth_timestamp", "oauth_consumer_key", "oauth_token",
"oauth_signature_method", "oauth_signature")]

h <- add_headers(Authorization = paste0("OAuth
realm=\"http://thor.brightcloud.com/rest\", ", paste(names(oauth),
paste0("\"",oauth, "\""), sep = "=", collapse = ", ")))

# request, with header
library("xml2")
as_list(read_xml(content(GET(endpoint, h), "raw")))