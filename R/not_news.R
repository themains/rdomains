#' Classify News and Non-News Based on keywords in the URL
#'
#' Based on a slightly amended version of the regular expression used to
#' classify news, and non-news in:
#' ``Exposure to ideologically diverse news and opinion on Facebook''
#' by Bakshy, Messing, and Adamic. Science. 2015.
#'
#' Amendment: sport rather than sports
#'
#' URL containing any of the following words is classified as soft news:
#' "sport|entertainment|arts|fashion|style|lifestyle|leisure|celeb|movie|music|gossip|food|travel|horoscope|weather|gadget" # nolint: line_length_linter.
#'
#' URL containing any of following words is classified as hard news:
#' "politi|usnews|world|national|state|elect|vote|govern|campaign|war|polic|econ|unemploy|racis|energy|abortion|educa|healthcare|immigration" # nolint: line_length_linter.
#'
#'
#' Note that it is based on patterns existing in a small set of domains. See paper for details.
#'
#' @param url_list vector of URLs
#'
#' @return data.frame with 3 columns: url, not_news, news
#'
#' @export
#' @references \url{https://www.science.org/doi/10.1126/science.aaa1160}
#'
#' @examples \dontrun{
#' not_news("http://www.bbc.com/sport")
#' not_news(c("http://www.bbc.com/sport", "http://www.washingtontimes.com/news/politics/"))
#' }
not_news <- function(url_list = NULL) {
  validate_domains(url_list, "url_list")

  soft_news_pattern <- paste0(
    "sport|entertainment|arts|fashion|style|lifestyle|leisure|celeb|",
    "movie|music|gossip|food|travel|horoscope|weather|gadget"
  )

  hard_news_pattern <- paste0(
    "politi|usnews|world|national|state|elect|vote|govern|campaign|war|",
    "polic|econ|unemploy|racis|energy|abortion|educa|healthcare|immigration"
  )

  tibble(
    url = url_list,
    not_news = str_detect(url_list, stringr::regex(soft_news_pattern, ignore_case = TRUE)),
    news = str_detect(url_list, stringr::regex(hard_news_pattern, ignore_case = TRUE))
  )
}
