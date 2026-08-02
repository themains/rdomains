#' Turn HTML into the text a classifier sees
#'
#' Mirrors the sibling Python package piedomains
#' (`src/piedomains/text_processor.py::clean_and_normalize_text`), whose contract as of
#' 0.12.0 is: **collapse runs of whitespace, trim, lowercase. Nothing else.**
#'
#' Two things it deliberately does *not* do, both of which were measured:
#'
#' * **Punctuation is kept.** Table pipes and layout dashes are 4.8% of tokens. Dropping
#'   them looked obviously right and measured worse -- held-out macro-F1 fell 0.7267 to
#'   0.7134 and Curlie agreement 0.543 to 0.523. Structural punctuation evidently says
#'   something about what kind of page this is.
#' * **No deduplication, sorting or stopword removal.** The pre-0.12.0 cleaner did all
#'   three; a transformer wants sentences, not a bag of sorted unique words.
#'
#' Do not "improve" this without retraining. The model is fitted to whichever form it was
#' shown, and a serving-side change silently degrades it -- which is a mistake this
#' project has already shipped once.
#'
#' @keywords internal
#' @noRd
NULL

#' Extract text, title, description and language from HTML
#'
#' @param html Raw HTML as a single string.
#'
#' @return A list with `text` (cleaned, lowercased), `title`, `description` and `lang`.
#'   Missing elements are `NA_character_`; `text` is `""` when nothing could be extracted.
#'
#' @export
#' @seealso [page_signals()], which uses this to decide whether a page is classifiable.
#' @examples
#' html <- "<html lang='en'><head><title>Example</title>
#'   <meta name='description' content='A demo page'>
#'   <script>ignored()</script></head>
#'   <body><p>Hello   World</p><style>p{}</style></body></html>"
#' html_text_content(html)
html_text_content <- function(html) {
  assert_character(html, len = 1, any.missing = FALSE)

  empty <- list(
    text = "", title = NA_character_,
    description = NA_character_, lang = NA_character_
  )
  if (!nzchar(str_trim(html))) {
    return(empty)
  }

  doc <- tryCatch(
    xml2::read_html(html),
    error = function(e) NULL
  )
  if (is.null(doc)) {
    return(empty)
  }

  # Remove what is not page text. Comments too: they carry build metadata and
  # occasionally whole alternate versions of the page.
  drop <- xml2::xml_find_all(
    doc, "//script | //style | //noscript | //template | //svg | //comment()"
  )
  if (length(drop)) {
    xml2::xml_remove(drop)
  }

  title <- first_text(doc, "//title")
  description <- first_attr(doc, "//meta[translate(@name,'DESCRIPTION','description')='description']", "content")
  lang <- first_attr(doc, "/html", "lang")

  body <- xml2::xml_find_first(doc, "//body")
  node <- if (inherits(body, "xml_missing")) doc else body
  raw_text <- xml2::xml_text(node)

  list(
    text = clean_page_text(raw_text),
    title = title,
    description = description,
    lang = lang
  )
}

#' Collapse whitespace, trim, lowercase -- and nothing else
#'
#' @param text raw extracted text
#' @return character(1)
#' @keywords internal
#' @noRd
clean_page_text <- function(text) {
  if (!length(text) || all(is.na(text))) {
    return("")
  }
  tolower(str_trim(stringr::str_replace_all(paste(text, collapse = " "), "\\s+", " ")))
}

#' First matching node's text, or NA
#' @keywords internal
#' @noRd
first_text <- function(doc, xpath) {
  node <- xml2::xml_find_first(doc, xpath)
  if (inherits(node, "xml_missing")) {
    return(NA_character_)
  }
  value <- str_trim(xml2::xml_text(node))
  if (nzchar(value)) value else NA_character_
}

#' First matching node's attribute, or NA
#' @keywords internal
#' @noRd
first_attr <- function(doc, xpath, attr) {
  node <- xml2::xml_find_first(doc, xpath)
  if (inherits(node, "xml_missing")) {
    return(NA_character_)
  }
  value <- xml2::xml_attr(node, attr)
  if (!is.na(value) && nzchar(str_trim(value))) str_trim(value) else NA_character_
}
