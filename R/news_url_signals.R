#' Detect soft- and hard-news keywords in URLs
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
#' @param urls vector of URLs
#'
#' @return A tibble with `input_id`, `input`, `soft_news` and `hard_news`.
#'   The two flags are independent; neither is a general news/non-news decision.
#'
#' @export
#' @references \url{https://www.science.org/doi/10.1126/science.aaa1160}
#'
#' @examples \dontrun{
#' news_url_signals("http://www.bbc.com/sport")
#' news_url_signals(c("http://www.bbc.com/sport", "http://www.washingtontimes.com/news/politics/"))
#' }
news_url_signals <- function(urls) {
  validate_domains(urls, "urls")

  soft_news_pattern <- paste0(
    "sport|entertainment|arts|fashion|style|lifestyle|leisure|celeb|",
    "movie|music|gossip|food|travel|horoscope|weather|gadget"
  )

  hard_news_pattern <- paste0(
    "politi|usnews|world|national|state|elect|vote|govern|campaign|war|",
    "polic|econ|unemploy|racis|energy|abortion|educa|healthcare|immigration"
  )

  tibble(
    input_id = seq_along(urls), input = urls,
    soft_news = str_detect(urls, stringr::regex(soft_news_pattern, ignore_case = TRUE)),
    hard_news = str_detect(urls, stringr::regex(hard_news_pattern, ignore_case = TRUE))
  )
}
