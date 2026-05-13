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
- Modern tibble usage internally (returned as data.frame for backward compatibility)
- Added checkmate for robust input validation
- Added readr for faster CSV reading
- Extracted domain cleaning logic to single function
- Improved string operations with stringr

## Backward Compatibility
All existing functions maintain their original return structures and behaviors, with the following exceptions:
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
