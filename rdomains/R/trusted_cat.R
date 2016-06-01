#' Get Trusted (McAfee) Category
#'
#' There is no API, so the function uses Selenium to open a browser, and the scrape the content.
#' 
#' @param domain domain name (string)
#' 
#' @return data.frame
#'  
#' @export
#' @references \url{https://www.trustedsource.org/}
#' @examples \dontrun{
#' trusted_cat(domain="http://www.google.com")
#' }

trusted_cat <- function(domain = NULL) {
    
    domain_f <- URLencode(domain, reserved=TRUE)

	checkForServer()
	startServer() # run Selenium Server binary
	remDr <- remoteDriver(browserName="firefox", port=4444) # instantiate remote driver to connect to Selenium Server
	remDr$open(silent=T) # open web browser
	site <- paste0("https://www.trustedsource.org/en/feedback/url?action=checksingle&url=", domain_f, "&product=12-ts-3") 
    remDr$navigate(site) # navigates to webpage
	form <- remDr$findElement("class", "contactForm")
	form$submitElement()
	res_table <- remDr$findElement(using="class", value = "result-table")
 	html_tab <- res_table$getElementAttribute("outerHTML")[[1]]
	tab      <- readHTMLTable(html_tab)

	res <- as.data.frame(tab)[-1,-1]
   
	res
}
