#' Classify News and Non-News Based on keywords in the URL
#'
#' Based on a slightly amended version of the regular expression used to classify news, and non-news in:
#' ``Exposure to ideologically diverse news and opinion on Facebook''
#' by Bakshy, Messing, and Adamic. Science. 2015.
#'
#' Amendment: sport rather than sports
#'
#' URL containing any of the following words is classified as soft news:
#' "sport|entertainment|arts|fashion|style|lifestyle|leisure|celeb|movie|music|gossip|food|travel|horoscope|weather|gadget"
#'
#' URL containing any of following words is classified as hard news:
#' "politi|usnews|world|national|state|elect|vote|govern|campaign|war|polic|econ|unemploy|racis|energy|abortion|educa|healthcare|immigration"
#'
#'
#' Note that it is based on patterns existing in a small set of domains. See paper for details.
#'
#'
#' @param url_list vector of URLs
#'
#' @return data.frame with 3 columns: url, not_news, news
#'
#' @export
#' @references \url{https://science.sciencemag.org/content/348/6239/1130}
#'
#' @examples \dontrun{
#' not_news("http://www.bbc.com/sport")
#' not_news(c("http://www.bbc.com/sport", "http://www.washingtontimes.com/news/politics/"))
#' }

not_news <- function(url_list = NULL) {

  if (identical(url_list, NULL)) stop("Please provide a valid URL.")

   not_news <- grepl("sport|entertainment|arts|fashion|style|lifestyle|
       leisure|celeb|movie|music|gossip|food|travel|horoscope|weather|gadget",
       url_list, ignore.case = TRUE)

   news     <- grepl("politi|usnews|world|national|state|elect|vote|govern|
      campaign|war|polic|econ|unemploy|racis|energy|abortion|educa|healthcare|
      immigration", url_list, ignore.case = TRUE)

   data.frame(url_list, not_news, news)
}
