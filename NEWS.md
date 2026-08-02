# rdomains 0.5.0.9000 (development)

- `collect_content()` now caches fetched pages. A cache hit **replays the stored
  provenance** -- the time the page was really fetched, the URL it really resolved
  to -- rather than synthesising a fresh timestamp, so a cached row still says when
  it is from. Entries expire (`cache_ttl`), the cache is pruned to a size budget
  (`cache_max_size`), and a corrupt entry is a miss rather than an error.
  Nothing persists past the session unless you pass `rdomains_cache_dir()`.
- New `rdomains_cache_dir()` and `cache_clear()`.
- `collect_content()` recovers pages from the Internet Archive when a host serves an
  anti-bot interstitial -- detection plus a fallback rather than an evasion arms race.
  Recovered rows carry `source = "archive"` and a `snapshot_timestamp`, so the vintage is
  never hidden. A domain that no longer resolves is deliberately **not** recovered this
  way: answering "what was this" while looking like "what is this" is the staleness this
  package exists to surface.
- New `pie_cat()`: fetches a domain's homepage and classifies its **current** content
  with the piedomains model, rather than looking the domain up in a list written years
  ago. It reaches the model through the Python package via `reticulate`, so the four
  fragile pieces of the model input -- the domain prefix, temperature scaling, label
  projection and the text cleaner -- stay on the Python side rather than becoming a
  second place they can drift. `parked` and `unavailable` pages are labelled from the
  page itself and cost no model call.
- `collect_content()`'s `max_bytes` default is now 10 MB, matching piedomains. At 2 MB
  it rejected cnn.com -- roughly 6 MB of homepage -- as `content_too_large` while the
  server returned 200.
- New `ut1_cat()` and `get_ut1_data()`: the UT-Capitole blacklists, the **maintained
  successor to Shallalist**. Where `shalla_cat()` answers from a list that stopped in
  January 2022, this one is updated continuously. Categories are UT1's own and are
  reported verbatim, with `ut1_usage` saying whether UT1 maintains the list for blocking
  or for allowing -- both describe content.
- `collect_content()` honours an explicit `http://` or `https://` in the input, keeping
  its port and path. Forcing `https://` meant http-only hosts were unreachable.
- An oversized response is now reported as `content_too_large` rather than
  `connection_error`. curl aborts the transfer, so the limit surfaced as a request
  failure -- and `connection_error` is retryable, so callers would have retried a
  too-large page forever.
- End-to-end tests run against a real local HTTP server (`webfakes`), covering redirects
  to private addresses, robots.txt refusal, oversized bodies, bot walls, and whether the
  cache actually prevents a second request.

# rdomains 0.5.0

## A label has a date, and now the package says so

Two of the four lookup sources are no longer published: DMOZ closed in March 2017 and
Shallalist stopped in 2022. Their labels were correct when assigned, but domains expire
and change hands, so a lookup today can return the previous registrant's category. Until
now that answer was presented identically to one from a list updated last week.

- New `source_vintage()` reports every category source, when it was last published,
  whether it is still maintained, and its successor where one exists.
- `shalla_cat()`, `dmoz_cat()` and `stevenblack_cat()` now return a
  `source_last_published` column. For the two dead lists this is a constant; for Steven
  Black's actively-maintained hosts file it is the fetched file's own date.
- Looking up against a discontinued source warns **once per session** — not once per
  call, which is a warning people learn to filter out.

The sibling project `piedomains` measured what this confusion costs: its worst class
disagreed with its own page content 71% of the time, and the cause was not bad annotation
but roughly a decade between the label and the page. Only 60% of the domains it trained
on still resolve.

## Fetch page content, not just look domains up

New `collect_content()` fetches homepage HTML and text, so a domain can be
classified on what it says **today** rather than on what a list said years ago.
It returns one row per requested domain, never dropped, each carrying `status`,
`stage`, `error_code` and `retryable` -- so a transient failure is
distinguishable from a permanent one and only the right rows get retried.
`fetch_error_codes()` documents the closed set of reasons; `fetch_report()`
summarises a run.

Supporting functions, all usable on their own if you already hold HTML:

- `page_signals()` reports whether a page is an anti-bot interstitial, a
  domain-parking placeholder, a server's "nothing here" page, or too thin to
  classify. Vendor presence alone is not a block: reddit, walmart and quora all
  serve real pages while embedding reCAPTCHA.
- `html_text_content()` extracts text, title, description and language.

The crawler identifies itself as `rdomains/<version>` with a contact URL, obeys
`robots.txt` including `Crawl-delay`, spaces requests to the same host, caps the
response body, follows redirects by hand so every hop is re-validated, and
refuses hosts resolving to private or link-local addresses.

Static HTML only -- no headless browser, so a JavaScript-rendered page comes back
thin and says so.

## Bug fixes

- `get_dmoz_data()` built its output path with `paste0()`, so the documented default
  `outdir = "."` produced a hidden `.dmoz_domain_category.csv` that `dmoz_cat()` would
  then fail to find. It now uses `file.path()`, matching its two siblings.
- `stevenblack_cat(use_file = NULL)` re-downloaded roughly 4 MB on **every call**. The
  file is now cached for the session.

## Testing

- The Shallalist and DMOZ tests download real files; they now carry `skip_on_cran()` and
  `skip_if_offline()` guards, as CRAN policy requires.

# rdomains 0.4.0

## Breaking Changes
- Removed `get_alexa_data()` function (Alexa service discontinued by Amazon)

## Major Changes
- Removed unused aws.alexa dependency
- Removed devtools from Imports (incorrect usage)
- Added modern tidyverse-style API with comprehensive input validation
- Significant code deduplication through shared helper functions

## API Updates
- Updated `virustotal_cat()` to use VirusTotal API v3 (previously v2.0)
- Updated documentation references to v3 API endpoints
- Fixed `virustotal_cat()` implementation to properly extract categories from v3 API response structure

## Improvements
- All categorization functions now validate inputs with helpful error messages using cli package
- Standardized parameter naming (virustotal_cat now uses 'domains' instead of 'domain')
- Better error messages with clear guidance on how to fix issues
- Modernized code style (pipes, purrr, tibble internally with data.frame output for compatibility)
- Improved file path handling with informative errors
- Enhanced rate limiting in LLM functions
- Cleaner domain preprocessing logic shared across all functions

## Internal Changes
- Added helper functions for common operations:
  - `clean_domains()` - standardized domain cleaning
  - `validate_domains()` - comprehensive input validation
  - `validate_data_file()` - consistent file validation
  - `get_api_key()` - unified API key retrieval
  - `build_categorization_prompt()` - LLM prompt construction
  - `apply_rate_limit()` - rate limiting logic
- Refactored to use purrr instead of for-loops where appropriate
- All functions now return tibbles for modern data handling
- Added checkmate for robust input validation
- Added readr for faster CSV reading
- Extracted domain cleaning logic to single function
- Improved string operations with stringr
- Removed redundant `::` notation for imported functions (cleaner code, consistent with @importFrom)

## Breaking Changes
- All categorization functions now return tibbles instead of data.frames
- `get_alexa_data()` has been removed (service discontinued)
- Input validation is now stricter (NULL and empty strings are properly rejected)
- `virustotal_cat()` parameter renamed from `domain` to `domains` for consistency

# rdomains 0.3.0

* **NEW**: Added LLM-based domain classification with `openai_cat()` and `claude_cat()` functions
* Support for OpenAI GPT models and Anthropic Claude models for domain categorization
* Flexible custom category schemas - users can specify their own categories or use defaults
* Consistent API design matching existing `*_cat()` functions for seamless integration
* Built-in rate limiting and error handling for API calls
* **REMOVED**: BrightCloud support due to service unavailability
* Updated documentation URLs from HTTP to HTTPS where applicable
* Fixed Shallalist references to reflect service discontinuation

# rdomains 0.2.1

* shallalist stopped its service so downloaded latest shalla db and changed the URL from which we fetch the shallalist file

# rdomains 0.2.0

* URL fixes. in resubmission now because site from which data was downloaded went down which broke some tests

# rdomains 0.1.9

* R package supporting headless browsing has been abandoned. So removing trusted_cat. Sigh.

# rdomains 0.1.8

* Function for checking if domain a university domain using https://github.com/Hipo/university-domains-list

# rdomains 0.1.7

* Changes due to move to a new repo.
* Basic brightcloud function added

# rdomains 0.1.6

* Adds not_news classifier that classifies not news based on published work.
* passes expect_lint_free

# rdomains 0.1.5

* Shallalist and DMOZ data read in with stringAsFactors as FALSE.
* Swapped the DMOZ data to domain level category data, included English translations of non-English categories, quote protection of multiple categories.
* Accounting for changes in RSelenium --- startServer() for instance is deprecated. But currently only allow for passing of log for trusted_cat.
* Fixed bug in shalla_cat for multiple domain names arguments
* Fixed small issue with adult_ml1_cat() whose returned data.frame had a column that was a named list. The column is now a vector.
* If an unknown domain is passed to virustotal, it will return an empty data.frame rather than throw an error.

# rdomains 0.1.0

* Initial release
