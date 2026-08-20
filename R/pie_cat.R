#' Classify domains with the piedomains model
#'
#' Fetches each domain's homepage and classifies its **current** content, rather than
#' looking the domain up in a list written years ago. This is the answer to the problem
#' [source_vintage()] documents: `shalla_cat()` reports what a domain was in January 2022,
#' `pie_cat()` reports what it is today.
#'
#' @section How it reaches the model:
#'
#' Through the Python package `piedomains`, via `reticulate`. That is deliberate rather
#' than convenient. The model input has four pieces that are easy to get subtly wrong and
#' impossible to notice when you do:
#'
#' * the text is prefixed with the domain minus its TLD -- training fed
#'   `domain + " " + text`, and a serving path once omitted it;
#' * probabilities are `softmax(logits / temperature)` with a temperature read from the
#'   checkpoint, not 1.0;
#' * merged classes have their probabilities **summed**, not overwritten;
#' * the text cleaner collapses whitespace and lowercases, and does *not* deduplicate or
#'   sort, which it used to.
#'
#' Reimplementing those in R would make this package a second place they can drift.
#' Calling the Python package means parity is structural: the weights come from the same
#' Hugging Face checkpoint and the input contract upgrades with a `pip` bump.
#'
#' @section Setup:
#'
#' ```r
#' install.packages("reticulate")
#' reticulate::py_install("piedomains", pip = TRUE)
#' ```
#'
#' The model weights (~1.2 GB) download from Hugging Face on first use and are cached by
#' `transformers` afterwards. Set `RETICULATE_PYTHON` to point at an existing environment
#' if you already have `piedomains` installed somewhere.
#'
#' @param domains Character vector of domains. Ignored when `pages` is supplied.
#' @param pages A tibble from [collect_content()], to classify pages you have already
#'   fetched. Rows that failed to fetch are returned untouched, so a partial run can be
#'   completed without refetching what already worked.
#' @param threshold Probability floor for the `pie_categories` list. The argmax is always
#'   included even when it falls below this. Applied to whatever piedomains returns; the
#'   model's own multi-label threshold is a piedomains setting.
#' @param ... Passed to [collect_content()] when `pages` is not supplied.
#'
#' @return The [collect_content()] tibble plus `pie_category`, `pie_confidence`,
#'   `pie_categories` (a list-column of category/probability tibbles), `label_source`
#'   (`"model"` or `"heuristic"`) and `model_repo`.
#'
#' @export
#' @seealso [collect_content()] for the fetch, [source_vintage()] for how a live answer
#'   compares with the static lists.
#' @examples \dontrun{
#' pie_cat(c("cnn.com", "wikipedia.org"))
#'
#' # fetch once, classify later, without refetching
#' pages <- collect_content(c("cnn.com", "wikipedia.org"))
#' pie_cat(pages = pages)
#' }
pie_cat <- function(domains = NULL, pages = NULL, threshold = 0.10, ...) {
  if (is.null(pages)) {
    validate_domains(domains)
    pages <- collect_content(domains, ...)
  }
  if (!is.data.frame(pages) || !all(c("domain_name", "text", "status") %in% names(pages))) {
    cli_abort("{.arg pages} must be a tibble from {.fn collect_content}")
  }

  pages$pie_category <- NA_character_
  pages$pie_confidence <- NA_real_
  pages$pie_categories <- vector("list", nrow(pages))
  pages$label_source <- NA_character_
  pages$model_repo <- NA_character_

  # parked and unavailable are answers, not failures, and the page states them plainly.
  # Labelling them here costs no model call at all.
  heuristic <- !is.na(pages$page_state) & pages$page_state %in% c("parked", "unavailable")
  pages$pie_category[heuristic] <- pages$page_state[heuristic]
  pages$label_source[heuristic] <- "heuristic"

  send <- pages$status == "ok" & !heuristic & !is.na(pages$text) & nzchar(pages$text)
  if (!any(send)) {
    return(pages)
  }

  classifier <- pie_backend()
  if (is.null(classifier)) {
    return(pages)
  }

  # The model window is 256 tokens; shipping whole pages across the bridge is waste.
  texts <- substr(pages$text[send], 1, 8000)
  scored <- classifier(pages$domain_name[send], texts, threshold)
  if (is.null(scored)) {
    return(pages)
  }

  pages$pie_category[send] <- scored$category
  pages$pie_confidence[send] <- scored$confidence
  pages$pie_categories[send] <- scored$categories
  pages$label_source[send] <- "model"
  pages$model_repo[send] <- scored$model_repo
  pages
}

#' Build a scoring function backed by the Python package
#'
#' Returns `NULL` with an informative message rather than erroring, so a run that cannot
#' reach the model still returns every fetched page with its provenance intact.
#'
#' @return A function of (domains, texts, threshold), or `NULL`.
#' @keywords internal
#' @noRd
pie_backend <- function() {
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    cli_warn(c(
      "{.pkg reticulate} is needed to reach the piedomains model.",
      "i" = 'Install it with {.code install.packages("reticulate")}.'
    ))
    return(NULL)
  }
  if (!reticulate::py_module_available("piedomains")) {
    cli_warn(c(
      "The Python package {.pkg piedomains} is not available.",
      "i" = 'Install it with {.code reticulate::py_install("piedomains", pip = TRUE)}.',
      "i" = "Or set {.envvar RETICULATE_PYTHON} to an environment that has it."
    ))
    return(NULL)
  }

  text_mod <- tryCatch(reticulate::import("piedomains.text"),
                       error = function(e) NULL)
  if (is.null(text_mod)) {
    cli_warn("Could not import {.pkg piedomains.text}.")
    return(NULL)
  }

  function(domains, texts, threshold) {
    tryCatch({
      # classify_from_paths() reads files and runs piedomains' *whole* pipeline --
      # extraction, the domain prefix, temperature scaling, label projection. Handing it
      # files rather than strings is what keeps all four on the Python side.
      #
      # The text written here has already been extracted and cleaned by
      # html_text_content(), and piedomains will extract again. On plain text that pass
      # is identity, and its cleaner (collapse whitespace, lowercase) is idempotent over
      # text that is already collapsed and lowercased -- so the double pass costs
      # nothing. The alternative, sending raw HTML, would mean carrying every page's
      # markup across the bridge for a 256-token window.
      dir <- file.path(tempfile("rdomains-pie-"), "html")
      dir.create(dir, recursive = TRUE)
      on.exit(unlink(dirname(dir), recursive = TRUE), add = TRUE)

      paths <- lapply(seq_along(domains), function(i) {
        writeLines(texts[i], file.path(dir, paste0(domains[i], ".html")))
        list(domain = domains[i], text_path = paste0("html/", domains[i], ".html"))
      })

      classifier <- text_mod$TextClassifier(cache_dir = dirname(dir))
      pie_tidy(classifier$classify_from_paths(paths))
    }, error = function(e) {
      cli_warn(c("piedomains could not classify these pages.",
                 "x" = conditionMessage(e)))
      NULL
    })
  }
}

#' Turn the Python result into columns
#'
#' @param out Whatever the Python classifier returned.
#' @return list(category, confidence, categories, model_repo) or NULL
#' @keywords internal
#' @noRd
pie_tidy <- function(out) {
  rows <- if (is.list(out) && !is.null(out$results)) out$results else out
  if (!length(rows)) {
    return(NULL)
  }
  list(
    category = vapply(rows, function(r) as.character(r$category %||% NA), character(1)),
    confidence = vapply(rows, function(r) as.numeric(r$confidence %||% NA), numeric(1)),
    categories = lapply(rows, function(r) {
      cats <- r$categories
      if (is.null(cats) || !length(cats)) {
        return(tibble(category = character(), probability = numeric()))
      }
      tibble(
        category = vapply(cats, function(c) as.character(c$category), character(1)),
        probability = vapply(cats, function(c) as.numeric(c$probability), numeric(1))
      )
    }),
    model_repo = "soodoku/piedomains-text"
  )
}
