#' Detect anti-bot interstitials, parking pages and empty placeholders
#'
#' Ported from the sibling Python package piedomains (`src/piedomains/blocking.py`). The
#' signatures were taken from pages that project actually received, not from documentation:
#' etsy.com, monster.com and reuters.com return a ~1470-byte DataDome interstitial whose
#' only visible text is the domain name; indeed.com returns Cloudflare's "Just a moment...";
#' mayoclinic.org returns a 296-byte Akamai "Access Denied ... Reference #".
#'
#' **Markers are tiered, because the presence of a vendor is not a block.** reddit, walmart,
#' tinyurl and quora all serve real pages while embedding reCAPTCHA, PerimeterX or a
#' Cloudflare Turnstile widget. Treating those as blocks silently discards good
#' classifications, so a weak marker only counts when the page also looks like an
#' interstitial. The tests carry those four as negative controls -- porting the tiers
#' without the counterexamples would port the bug back in.
#'
#' Everything here is a pure string heuristic over already-fetched HTML. No network.
#'
#' @keywords internal
#' @noRd
NULL

#' Unambiguous markers: these appear only on an actual challenge or denial page
#' @keywords internal
#' @noRd
RD_STRONG_MARKERS <- list(
  datadome   = c("captcha-delivery.com", "geo.captcha-delivery"),
  cloudflare = c("cf_chl_opt", "cf-browser-verification", "cf-please-wait"),
  imperva    = "incapsula incident id",
  akamai     = "reference #18."
)

#' Ambiguous markers: the vendor's script is present, but healthy pages embed these too
#' @keywords internal
#' @noRd
RD_WEAK_MARKERS <- list(
  cloudflare = "challenges.cloudflare.com",
  perimeterx = c("perimeterx", "px-captcha"),
  datadome   = "datadome",
  recaptcha  = c("g-recaptcha", "recaptcha/api.js")
)

#' Titles that are themselves the tell
#' @keywords internal
#' @noRd
RD_CHALLENGE_TITLES <- c(
  "just a moment...",
  "attention required! | cloudflare",
  "access denied",
  "security check",
  "are you a robot?",
  "verifying you are human"
)

#' HTTP statuses that usually mean "blocked", not "broken"
#' @keywords internal
#' @noRd
RD_BLOCK_STATUSES <- c(401L, 403L, 429L, 503L)

#' Deliberately narrow, and only applied to short pages: phrases like "permission to
#' access" appear in the legal copy of healthy sites (bankofamerica.com, 491 tokens,
#' matched an earlier looser pattern).
#' @keywords internal
#' @noRd
RD_DENIAL_TEXT <- paste0(
  "(you don'?t have permission to access|access denied",
  "|enable javascript and cookies to continue",
  "|verify you are (a )?human)"
)

#' Above this size a page is substantive enough that a weak marker is almost certainly an
#' embedded widget rather than an interstitial.
#' @keywords internal
#' @noRd
RD_INTERSTITIAL_MAX_BYTES <- 60000L

#' Registrars and parking services whose landing pages are unmistakable
#' @keywords internal
#' @noRd
RD_PARKING_SERVICES <- c(
  "dan.com", "sedo.com", "hugedomains", "afternic", "bodis.com",
  "parkingcrew", "wc_landing", "domainmarket", "undeveloped.com", "namesilo.com"
)

#' Phrases a parking page uses about itself. Held to a length limit because a real shop
#' legitimately says "for sale" while running to thousands of words.
#' @keywords internal
#' @noRd
RD_PARKING_PHRASES <- c(
  "is for sale", "buy this domain", "may be for sale", "domain for sale",
  "this domain is parked", "domain parking", "inquire about this domain",
  "domain name is for sale", "the domain you are looking for is for sale",
  # Found by sampling what the first version missed: orderwith.com, a parked page
  # labelled `drugs`, said "available for sale" rather than "is for sale".
  "available for sale", "available to purchase", "parked free of charge",
  "is available -- inquire"
)

#' A parked page is a placeholder. Above this it is a real site that mentions a sale.
#' @keywords internal
#' @noRd
RD_PARKED_MAX_WORDS <- 250L

#' What a web server emits when there is no site behind the domain
#' @keywords internal
#' @noRd
RD_SERVER_ARTIFACTS <- c(
  "index of /", "parent directory", "proudly served by", "litespeed web server",
  "welcome to nginx", "default web page", "it works!", "object not found!"
)

#' What a site says when it exists on paper but has no content yet.
#'
#' Multilingual because the corpus is. The Spanish and German entries are deliberately
#' truncated ("en construcci", not "en construccion" with an accent) -- that is how the
#' Python original handles the accent, and it also keeps this file pure ASCII, which
#' avoids an R CMD check note.
#' @keywords internal
#' @noRd
RD_UNAVAILABLE_PHRASES <- c(
  "coming soon", "under construction", "im aufbau", "en construcci", "en travaux",
  "account suspended", "site is offline", "seite ist offline", "maintenance page",
  "we will be back", "website expired", "bandwidth limit exceeded",
  "site temporarily unavailable", "page is under maintenance"
)

#' Far tighter than the parking limit, and it has to be. "Coming soon" and "under
#' construction" are things live sites say in passing: a 319-word breeder site saying
#' puppies are coming soon, an 877-word games portal. Sampled at 100 words the rule still
#' swept in a riding school; at 60 the first thirty hits were all genuine. Precision
#' matters more than recall, because a false positive relabels a real page.
#' @keywords internal
#' @noRd
RD_UNAVAILABLE_MAX_WORDS <- 60L

#' Extract a page title, lowercased
#' @param html raw response body
#' @return character(1), "" when absent
#' @keywords internal
#' @noRd
html_title <- function(html) {
  m <- str_match(html, regex("<title[^>]*>(.*?)</title>",
                                               ignore_case = TRUE, dotall = TRUE))
  if (is.na(m[1, 2])) "" else tolower(str_trim(m[1, 2]))
}

#' Does any marker appear in the body?
#' @param lowered lowercased html
#' @param markers named list of character vectors
#' @return the matching name, or NA
#' @keywords internal
#' @noRd
first_marker <- function(lowered, markers) {
  for (vendor in names(markers)) {
    if (any(vapply(markers[[vendor]], function(m) grepl(m, lowered, fixed = TRUE),
                   logical(1)))) {
      return(vendor)
    }
  }
  NA_character_
}

#' Corroborate a weak marker: does this page look like a challenge?
#' @param html raw response body
#' @param domain requested domain
#' @return logical
#' @keywords internal
#' @noRd
looks_like_interstitial <- function(html, domain = "") {
  title <- html_title(html)
  if (title %in% RD_CHALLENGE_TITLES) {
    return(TRUE)
  }
  if (nzchar(domain) && identical(title, tolower(str_trim(domain))) &&
      nchar(html) < 4000) {
    return(TRUE)
  }
  nchar(html) < RD_INTERSTITIAL_MAX_BYTES &&
    grepl(RD_DENIAL_TEXT, html, ignore.case = TRUE, perl = TRUE)
}

#' Is the extracted text too short to classify honestly?
#'
#' @param text Extracted page text.
#' @param min_tokens Floor, in whitespace-separated tokens.
#'
#' @return `TRUE` when the text falls below the floor.
#' @keywords internal
#' @noRd
is_thin <- function(text, min_tokens = 30L) {
  length(strsplit(str_trim(text), "\\s+")[[1]][nzchar(
    strsplit(str_trim(text), "\\s+")[[1]]
  )]) < min_tokens
}

#' Is this page a domain-parking placeholder rather than a site?
#'
#' 7.9% of the piedomains training corpus turned out to be parking pages, unevenly spread:
#' 42% of the `drugs` class, 23% of `webmail`, 18% of `downloads`, because expired domains
#' in those niches get parked. The model consequently learned that a "this domain is for
#' sale" template *means* drugs, which is why zappos.com came back as drugs.
#'
#' @param text Extracted page text.
#' @return `TRUE` when the page is a parking placeholder.
#' @keywords internal
#' @noRd
looks_parked <- function(text) {
  lowered <- tolower(text)
  if (any(vapply(RD_PARKING_SERVICES, function(s) grepl(s, lowered, fixed = TRUE),
                 logical(1)))) {
    return(TRUE)
  }
  # A phrase alone is not enough: length separates a placeholder from a shop.
  if (word_count(lowered) > RD_PARKED_MAX_WORDS) {
    return(FALSE)
  }
  any(vapply(RD_PARKING_PHRASES, function(p) grepl(p, lowered, fixed = TRUE), logical(1)))
}

#' Does the domain resolve but have no site behind it?
#'
#' Distinct from parked, which is specifically *for sale*. This is the other way a domain
#' serves bytes without being a website: an Apache autoindex, a registrar's "coming soon",
#' a suspended account.
#'
#' @param text Extracted page text.
#' @return `TRUE` when the page is a no-site placeholder.
#' @keywords internal
#' @noRd
looks_unavailable <- function(text) {
  lowered <- tolower(text)
  # Length first: these phrases are common inside real pages, and the guard is what
  # separates "we will be back after maintenance" from a shop mentioning a new line.
  if (word_count(lowered) > RD_UNAVAILABLE_MAX_WORDS) {
    return(FALSE)
  }
  any(vapply(RD_SERVER_ARTIFACTS, function(m) grepl(m, lowered, fixed = TRUE),
             logical(1))) ||
    any(vapply(RD_UNAVAILABLE_PHRASES, function(p) grepl(p, lowered, fixed = TRUE),
               logical(1)))
}

#' Count whitespace-separated words
#' @param x character(1)
#' @return integer
#' @keywords internal
#' @noRd
word_count <- function(x) {
  parts <- strsplit(str_trim(x), "\\s+")[[1]]
  sum(nzchar(parts))
}

#' What kind of page is this?
#'
#' Inspects already-fetched HTML for the three things that are not a classifiable site: an
#' anti-bot interstitial, a domain-parking placeholder, and a server's "nothing here"
#' page. No network access.
#'
#' `parked` and `unavailable` are **answers, not failures** -- they are facts about the
#' domain, plainly stated in the page, that a caller can act on. They are also free: no
#' classification service needs to be consulted.
#'
#' @param html Raw response body.
#' @param text Extracted page text. If `NULL`, derived from `html`.
#' @param domain The domain requested, used to spot a page whose only content is its own
#'   name.
#' @param status HTTP status code, if known.
#'
#' @return A one-row tibble: `page_state` (one of `"content"`, `"blocked"`, `"parked"`,
#'   `"unavailable"`, `"thin"`), `blocked`, `block_vendor`, `block_reason`, `parked`,
#'   `unavailable`, `thin`, `n_tokens`.
#'
#' @export
#' @seealso [fetch_error_codes()] for how these map onto run outcomes.
#' @examples
#' # A Cloudflare challenge, not a website
#' page_signals("<html><title>Just a moment...</title><body>cf_chl_opt</body></html>")
#'
#' # A parking page
#' page_signals("<html><body>This domain is for sale. Inquire now.</body></html>")
#'
#' # A real page that merely embeds reCAPTCHA is not blocked
#' page_signals(paste0("<html><title>Reddit</title><body>",
#'                     paste(rep("real discussion content", 200), collapse = " "),
#'                     "<script src='recaptcha/api.js'></script></body></html>"))
page_signals <- function(html, text = NULL, domain = "", status = NULL) {
  assert_character(html, len = 1, any.missing = FALSE)
  if (is.null(text)) {
    text <- html_text_content(html)$text
  }
  if (is.null(domain) || is.na(domain)) domain <- ""

  lowered <- tolower(html)

  vendor <- first_marker(lowered, RD_STRONG_MARKERS)
  blocked <- !is.na(vendor)
  reason <- if (blocked) "strong anti-bot marker" else NA_character_

  if (!blocked && !is.null(status) && !is.na(status) &&
      as.integer(status) %in% RD_BLOCK_STATUSES &&
      looks_like_interstitial(html, domain)) {
    blocked <- TRUE
    vendor <- "status"
    reason <- paste0("HTTP ", status, " with an interstitial body")
  }

  if (!blocked) {
    weak <- first_marker(lowered, RD_WEAK_MARKERS)
    if (!is.na(weak) && looks_like_interstitial(html, domain)) {
      blocked <- TRUE
      vendor <- weak
      reason <- "weak marker corroborated by interstitial shape"
    }
  }

  parked <- looks_parked(text)
  unavailable <- !parked && looks_unavailable(text)
  n_tokens <- word_count(text)
  thin <- n_tokens < 30L

  state <- if (blocked) {
    "blocked"
  } else if (parked) {
    "parked"
  } else if (unavailable) {
    "unavailable"
  } else if (thin) {
    "thin"
  } else {
    "content"
  }

  tibble(
    page_state = state,
    blocked = blocked,
    block_vendor = if (is.na(vendor)) NA_character_ else vendor,
    block_reason = reason,
    parked = parked,
    unavailable = unavailable,
    thin = thin,
    n_tokens = n_tokens
  )
}
