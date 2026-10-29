# rdomains 0.6.1

- Tests that start a local webfakes HTTP server are skipped on CRAN. CRAN's noLD check
  host was too slow to start the server subprocess within webfakes' 5 s limit, which
  failed 12 tests. The tests still run locally and in continuous integration. No
  package code changed.

# rdomains 0.6.0

## Result contracts and migration

- Explicit model selections and R environment changes reach an already initialized
  Python interpreter. Model loading restores both runtimes' prior environment values,
  including when a checkpoint fails to load.

- Classifiers now return a common result with `input_id`, original `input`, provider,
  evidence type, structured outcomes, typed `labels`, and source-specific `details`.
  Provider-specific category columns become `category`; `pie_confidence` becomes
  `confidence`. Vendor labels and multiple list memberships are retained in `labels`.
  University records, UT1 usage, and piedomains fetch/model metadata move into `details`.
- Empty domain vectors return typed empty results without I/O. `no_match` distinguishes
  absent memberships from execution failures. All download helpers return a path invisibly.
- `rate_limit` is renamed `delay`, measured in seconds. `web_categories()` exposes the
  shared default LLM vocabulary. API failures retain status, reason and model identity.
- `not_news()` is replaced by `news_url_signals()` with independent `soft_news` and
  `hard_news` flags. `adult_ml1_cat()` is replaced by `adult_name_probability()`; its
  fitted model and training-era feature encoding are unchanged. No compatibility aliases
  are retained.
- Steven Black results describe membership only: `blocked` or `no_match`. Hostname
  fragments no longer imply advertising or malware. UT1 retains every category membership.
- `uni_cat()` accepts a saved JSON file and caches its automatic download for the session.
- Current-content collection defaults to `archive_fallback = FALSE`. Historical and fallback
  requests preserve the full URL. Archive outages and robots transport failures have
  distinct retryable outcomes; not-found pages and unresolved redirects do not report success.
- Corrupt cache records are misses. Substantive articles mentioning parking marketplaces
  are not classified as parked by that mention alone. Acquired pages share one processing path.
- VirusTotal preserves typed authentication, quota and HTTP failures; invalid vendor
  labels fail the affected row. Archive resource guards retain their permanent failure reasons.
- Inference-only retries preserve caller-restored batch IDs. Mocked model tests restore
  the session cache, so mocked and real-model checks can run together.
- `pie_cat(model = ...)` selects a checkpoint explicitly. The pinned default is reused
  within a session; custom checkpoints are loaded afresh. Saved results support inference-only retry.
- R 4.5 is the tested minimum. A dedicated R/Python job exercises the bridge and verifies
  pinned-weight parity both online and offline. The unused XML dependency is removed.

This is an API and correctness release, not a newly trained classifier. The pinned
piedomains checkpoint's drugs/retail limitations and the historical adult model's lack
of current calibration remain documented. No new model-quality claim is made.

## October 2026 audit repairs

- Pass original HTML to piedomains >=0.15.0; preserve duplicate inputs, apply thresholds
  to the full distribution, report actual checkpoint provenance and separate fetch
  outcomes from inference failures. Text-only `pages` inputs must be fetched again.
- Preserve path/query case in cache keys and start a new cache namespace. Check robots
  against the requested path and every content redirect; guard robots redirects too.
  Validate crawler limits before making requests. Retain bounded retries for transient
  HTTP failures, and return malformed URLs as failed rows without aborting the batch.
  Empty redirect locations are not followed; fail-closed robots outcomes respect cache TTL.
- Reject empty CDX results and select historical captures at or before the requested date.
- Default to `gpt-6-luna` and `claude-haiku-5-5` with their supported request parameters.
  Reject invalid/truncated categories and preserve explicit VirusTotal key precedence.
  Live paid-API tests now require explicit opt-in.
- Standardize Steven Black input to `domains` and both Steven Black and VirusTotal
  output to `domain_name`. VirusTotal credentials now use `api_key`.
- Separate publication dates from retrieval times using checksum-bound metadata.
  Unverified caller files have unknown dates. Correct the DMOZ snapshot year to 2015.
  Steven Black absence returns `no_match`; it is not a safety assessment.
- Document the bundled 2017 adult model and the piedomains checkpoint's known label
  contamination. These repairs do not retrain either model.

## Earlier development changes

- `collect_content()` now caches fetched pages. A cache hit **replays the stored
  provenance** -- the time the page was really fetched, the URL it really resolved
  to -- rather than synthesising a fresh timestamp, so a cached row still says when
  it is from. Entries expire (`cache_ttl`), the cache is pruned to a size budget
  (`cache_max_size`), and a corrupt entry is a miss rather than an error.
  Nothing persists past the session unless you pass `rdomains_cache_dir()`.
- New `rdomains_cache_dir()` and `cache_clear()`.
- `collect_content()` and `pie_cat()` take an `archive_date`, fetching each domain as it
  was on or before that date. Rows carry the *realised*
  `snapshot_timestamp`, which is the capture found and rarely the date asked for.
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
