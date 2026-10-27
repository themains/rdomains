# rdomains: Classify website content and look up domain categories

[![CRAN version](https://www.r-pkg.org/badges/version/rdomains)](https://cran.r-project.org/package=rdomains)
[![R-CMD-check](https://github.com/themains/rdomains/actions/workflows/R-CMD-check.yml/badge.svg)](https://github.com/themains/rdomains/actions/workflows/R-CMD-check.yml)

`rdomains` fetches website content, classifies it through
[piedomains](https://github.com/themains/piedomains), and provides lookups against
UT-Capitole, Steven Black, university, Shallalist and DMOZ lists. It also supports
VirusTotal and domain-name inference through OpenAI and Anthropic.

This README describes the development version. See [NEWS](NEWS.md) for release history.

## Install

```r
install.packages("rdomains")
```

For the development version, including `pie_cat()`:

```r
install.packages("remotes")
remotes::install_github("themains/rdomains")
```

## Classify fetched content

The Python bridge requires `reticulate`, Python 3.12 or newer, and `piedomains>=0.15.0`.
Select an existing environment with `RETICULATE_PYTHON`, or install one through reticulate:

```r
install.packages("reticulate")
reticulate::py_install("piedomains>=0.15.0", pip = TRUE)

library(rdomains)
pages <- collect_content(c("cnn.com", "wikipedia.org"))
classified <- pie_cat(pages = pages, threshold = 0.10)
classified[c("domain_name", "pie_category", "pie_confidence", "status", "error_code")]
fetch_report(classified)
```

`collect_content()` retains raw HTML for piedomains' own extractor. It checks robots.txt
for each requested path and redirect, caps response sizes, and returns failures as rows.
It fetches static HTML; sites requiring JavaScript may have insufficient content.
`pie_cat()` preserves the collection outcome in `fetch_*` columns and reports inference
failures in `status`, `stage` and `error_code`. Duplicate inputs retain separate rows.

The bridge uses the text classifier. In piedomains 0.15.0, the default is
[`gojiberries/piedomains-text`](https://huggingface.co/gojiberries/piedomains-text),
a fine-tuned multilingual ModernBERT model based on `jhu-clsp/mmBERT-base`, with 44 labels.
Results include the resolved model repository, revision, package version, extractor,
cleaning mode and calibration temperature. `PIEDOMAINS_TEXT_MODEL` selects an alternative.

The checkpoint's [model card](https://huggingface.co/gojiberries/piedomains-text#known-defect-drugs-absorbs-retail)
documents contaminated `drugs` training labels and confusion with retail. A current
fetch does not establish that the predicted category is correct. Additional categories
above `threshold` are drawn from a single-label probability distribution; their presence
is not validation of multiple independent labels. The bundled `adult_ml1_cat()` model
is a separate name-based model whose artifact dates to 2017 and lacks current calibration.

## Dates and sources

```r
source_vintage()
get_ut1_data(outdir = tempdir())
ut1_cat("example.com", use_file = file.path(tempdir(), "ut1_domain_category.csv"))
```

Download helpers save a checksum-bound metadata sidecar. `source_last_published` records
an available source date; `source_fetched_at` records download time. Files without matching
metadata have unknown dates. Filesystem modification times are not publication dates.
The preserved DMOZ snapshot dates to 2015; Shallalist dates to January 2022. These historical
labels can describe a previous owner of a domain. A Steven Black result of `not_listed`
only means that the domain was absent from the supplied list.

For historical content:

```r
historical <- collect_content("example.com", archive_date = "20200101")
```

This selects the latest available capture **on or before** the requested day. The actual
capture time is in `snapshot_timestamp`. Automatic recovery from a live bot block also
sets `source = "archive"`; it does not establish the current site's content.

Caching lasts for the R session by default. Pass `cache_dir = rdomains_cache_dir()` to
persist it. Cached rows retain their original retrieval times, and URL paths and query
values remain case-sensitive.

## API classifications

`openai_cat()` and `claude_cat()` infer categories from domain names; they do not fetch
page content. Set `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` and pass your allowed categories:

```r
openai_cat("example.com", categories = c("news", "shopping", "other"))
```

The defaults are `gpt-6-luna` and `claude-haiku-5-5`. Invalid, truncated or failed provider
responses return `NA` with a warning. Explicit credentials take precedence over environment
variables, including `api_key` for `virustotal_cat()`. All category lookups accept
`domains`; Steven Black and VirusTotal now return `domain_name` like the other lookups.

## Development

```r
devtools::test()
lintr::lint_package()
devtools::check()
```

Tests use local fixtures. Paid API smoke tests require the explicit
`RDOMAINS_LIVE_API_TESTS=true` opt-in as well as credentials. Set `RDOMAINS_TEST_PYTHON`
to an installed piedomains environment to exercise the Python bridge locally.
Documentation is generated from R source, and pkgdown uses this README for its homepage.

## License

[MIT](https://opensource.org/license/mit).
