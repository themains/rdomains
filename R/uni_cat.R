#' Get Category from University Domain List
#'
#' Fetches university domain json from:
#' \url{https://raw.githubusercontent.com/Hipo/university-domains-list/master/world_universities_and_domains.json} # nolint: line_length_linter.
#'
#' @param domains Vector of domain names.
#' @param use_file Optional saved Hipo JSON file. Otherwise downloaded once per session.
#'
#' @return A tibble following [classification_results]. Source-specific data are
#'   retained in `details`; all source labels are retained in `labels`.
#'
#' @export
#' @importFrom dplyr bind_cols
#' @examples \dontrun{
#' uni_cat(domains = "http://www.google.com")
#' }
uni_cat <- function(domains, use_file = NULL) {
  validate_domains(domains)
  if (!length(domains)) {
    return(classification_result(domains, "uni", "list_membership", "lookup"))
  }
  path <- lookup_source_file("uni", use_file)
  data <- fromJSON(path)
  if (!is.data.frame(data) || !all(c("domains", "name") %in% names(data)) ||
        !is.list(data$domains)) {
    cli_abort("University data must contain names and domain lists.")
  }
  owner <- rep(seq_len(nrow(data)), lengths(data$domains))
  records <- data[owner, , drop = FALSE]
  records$hostname <- as.character(unlist(data$domains, use.names = FALSE))
  records$category <- rep("university", nrow(records))
  lookup_result(domains, records, "hostname", "category", "uni", load_source_metadata(path))
}
