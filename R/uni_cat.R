#' Get Category from University Domain List
#'
#' Fetches university domain json from:
#' \url{https://raw.githubusercontent.com/Hipo/university-domains-list/master/world_universities_and_domains.json} # nolint: line_length_linter.
#'
#' @param domains vector of domain names
#'
#' @return data.frame with original list and all the other columns from the university json
#'
#' @export
#' @importFrom dplyr bind_cols
#' @examples \dontrun{
#' uni_cat(domains = "http://www.google.com")
#' }
uni_cat <- function(domains = NULL) {
  validate_domains(domains)
  c_domains <- clean_domains(domains)

  # One line on purpose: split across literals, the link checker only ever
  # sees the first fragment, which 404s.
  uni_list <- fromJSON(
    "https://raw.githubusercontent.com/Hipo/university-domains-list/master/world_universities_and_domains.json" # nolint: line_length_linter.
  )

  # `domains` is a list column -- 281 of the list's 10,256 universities give more than
  # one host. match() would coerce it with as.character(), turning a two-element entry
  # into the string 'c("student.wab.edu.pl", "wab.edu.pl")', which nothing can match.
  # Flattening first, and carrying each host's row number with it, matches every host.
  hosts <- tolower(unlist(uni_list$domains, use.names = FALSE))
  owner <- rep(seq_len(nrow(uni_list)), lengths(uni_list$domains))

  tibble(
    domain_name = c_domains
  ) |>
    bind_cols(
      uni_list[owner[match(c_domains, hosts)], ]
    )
}
