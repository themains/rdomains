# rdomains 0.5.0 (development)

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
