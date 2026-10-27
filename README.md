# rdomains: Classify website content and look up domain categories

[![CRAN version](https://www.r-pkg.org/badges/version/rdomains)](https://cran.r-project.org/package=rdomains)
[![Total CRAN downloads](https://cranlogs.r-pkg.org/badges/grand-total/rdomains)](https://cran.r-project.org/package=rdomains)
[![R-CMD-check](https://github.com/themains/rdomains/actions/workflows/R-CMD-check.yml/badge.svg)](https://github.com/themains/rdomains/actions/workflows/R-CMD-check.yml)

`rdomains` collects website content and classifies it with
[piedomains](https://github.com/themains/piedomains). It also provides domain-list
lookups, VirusTotal vendor reports, and domain-name inference through OpenAI and
Anthropic. Results retain the original input, source, labels, and failure reason.

Choose the source by the question you need answered:

| Question | Function | Evidence |
| --- | --- | --- |
| What does this page contain now? | `collect_content()` then `pie_cat()` | Fetched static HTML |
| What did this page contain by a date? | `collect_content(archive_date = ...)` then `pie_cat()` | An archived capture of the requested URL |
| Which lists contain this domain? | `ut1_cat()`, `stevenblack_cat()`, `shalla_cat()`, `dmoz_cat()` | Source-specific memberships |
| Is this a listed university domain? | `uni_cat()` | University directory records |
| What do security vendors report? | `virustotal_cat()` | Vendor labels |
| What category does a name suggest? | `openai_cat()`, `claude_cat()` | Name-only inference; no page fetch |

## Install

The current development version requires R 4.5 or newer. GitHub includes changes
not yet available on CRAN; [NEWS](NEWS.md) lists the changes and migration notes.

```r
install.packages("rdomains")
```

For the development version:

```r
install.packages("remotes")
remotes::install_github("themains/rdomains")
```

List lookups and API adapters do not require Python. For content classification,
install `reticulate` and declare the Python requirements before initializing Python:

```r
install.packages("reticulate")
reticulate::py_require("piedomains==0.15.0", python_version = ">=3.12")
```

Reticulate can create the environment. To use an existing environment instead, set
`RETICULATE_PYTHON` before loading Python; that environment must contain
`piedomains>=0.15.0`. Model weights download from Hugging Face on first use. After
one successful model load, `HF_HUB_OFFLINE=1` permits inference from cached weights.
Offline operation also requires saved HTML: collecting a live page needs a network.

## Classify current content

```r
library(rdomains)
pages <- collect_content(c("https://example.com/news", "wikipedia.org"))
results <- pie_cat(pages = pages)
results[c("input_id", "input", "category", "confidence", "status", "error_code")]
fetch_report(results)
saveRDS(results, "classifications.rds")
```

Collection preserves URL paths and query strings, follows robots rules, limits
response size, and returns failures as rows. Static HTML is retained for the Python
model's extractor. JavaScript-only pages may have insufficient content.

Archived fallback is off by default. Set `archive_fallback = TRUE` to allow recovery
from a bot block; successful recovered results identify their archived evidence.
Use `archive_date = "20200101"` to request the latest capture on or before that day.
The realized timestamp and collection details are retained in each result's
`details` entry. An archive outage is different from a missing capture.

The default model is the pinned 44-label
[`gojiberries/piedomains-text`](https://huggingface.co/gojiberries/piedomains-text)
checkpoint, based on `jhu-clsp/mmBERT-base`. Its model card documents drugs/retail
confusion. This release repairs software behavior; it does not establish new
classification accuracy or update those weights. Check labels against independent
evidence before using them as research outcomes.

`threshold` controls which alternative probabilities appear in `labels`; it is not
an abstention threshold and always retains the predicted category. Pass `model` to
select another checkpoint explicitly. Results record model identity and revision;
`details` retains extraction settings and the separate fetch outcome.

## Compare sources without losing their meaning

```r
path <- get_ut1_data(outdir = tempdir())
lookup <- ut1_cat(c("example.com", "wikipedia.org"), use_file = path)
lookup$labels
```

Every classifier returns the same 18-column result structure. `status` is `ok`,
`no_match`, or `failed`. `labels` is a list of tibbles containing `category`, `score`,
and `vendor`. Sources may report several labels; `category` stays missing when no
single category was selected. A list membership has no probability, so its score
is missing. `details` retains provider-specific records such as UT1 usage and
university names. Source taxonomies are preserved rather than silently mapped.

Steven Black reports `blocked` for listed hosts and `no_match` otherwise. It does
not infer malware, advertising, or tracking from fragments of the hostname.
Shallalist and DMOZ are historical snapshots from January 2022 and 2015.
Downloaders return the written path and save checksum-bound metadata. Publication
and retrieval dates are separate; an unverified file has unknown dates.

## Use name-only APIs

```r
web_categories()
openai_cat("example.com", categories = c("news", "shopping", "other"))
```

Set `OPENAI_API_KEY` or `ANTHROPIC_API_KEY`, or pass `api_key`. Explicit credentials
win over environment variables. Defaults are `gpt-6-luna` and `claude-haiku-5-5`.
`delay` is the minimum sleep between calls, in seconds. Failed, truncated, or invalid
responses retain a structured reason and no category. These functions infer from
the domain name; they do not inspect current content.

## Resume a batch

```r
results <- readRDS("classifications.rds")
pending <- which(results$retryable)
retried <- pie_cat(results$input[pending])
retried$input_id <- results$input_id[pending]
results[pending, ] <- retried
saveRDS(results, "classifications.rds")
```

Reuse the same collection options when retrying. The example uses default live
collection. Empty inputs return typed empty results without downloads or API calls.
For an inference-only retry, pass the saved piedomains results as `pages`; their
`details` retain the original HTML and fetch metadata. For API batches, apply the
same pattern with the original provider, vocabulary, and model. Checkpoint completed
chunks so restarting does not repeat successful paid calls. Input identifiers are
positions within a call; retain your original identifiers when combining chunks.

Page caching lasts for the session by default. Pass
`cache_dir = rdomains_cache_dir()` to persist pages. Cache hits retain the original
retrieval time. Lookup downloads for Steven Black and universities are cached for
the session; pass `use_file` to reproduce a run from a saved source.

## Historical name and URL heuristics

`adult_name_probability()` returns a probability from the unchanged 2017
name/suffix model. Its probabilities have not been validated on current domains.
`news_url_signals()` returns independent `soft_news` and `hard_news` keyword flags;
it is not a general news detector. These measurements are separate from the
classification-result contract.

## Development

```r
devtools::test()
lintr::lint_package()
devtools::check()
```

Paid API tests require `RDOMAINS_LIVE_API_TESTS=true` and credentials.
`RDOMAINS_TEST_PYTHON` selects an installed piedomains environment for bridge tests.
`RDOMAINS_REAL_MODEL_TESTS=true` enables the pinned-weight parity test. CI tests
R 4.5 with Python 3.12, verifies real-model parity, and repeats it offline.
Documentation is generated from R source; pkgdown uses this README as its homepage.

## License

[MIT](https://opensource.org/license/mit).
