## rdomains 0.3.0 - Major Update

This is a major version update adding LLM-based domain classification capabilities.

### New features in 0.3.0
* **NEW**: Added `openai_cat()` function for domain classification using OpenAI GPT models
* **NEW**: Added `claude_cat()` function for domain classification using Anthropic Claude models
* Support for custom category schemas - users can specify their own categories or use defaults
* Consistent API design matching existing `*_cat()` functions for seamless integration
* Built-in rate limiting and error handling for API calls
* **REMOVED**: BrightCloud support due to service unavailability
* Updated documentation URLs from HTTP to HTTPS where applicable
* Fixed Shallalist references to reflect service discontinuation

### API Dependencies
The new LLM functions require API keys from:
* OpenAI (https://openai.com) for `openai_cat()`  
* Anthropic (https://anthropic.com) for `claude_cat()`

These are optional features and the package functions normally without these keys (returning appropriate error messages when keys are missing).

## Test environments  
* local macOS, R 4.5.1
* GitHub Actions (ubuntu-latest, macOS-latest, windows-latest)

## R CMD check results
There were no ERRORs or WARNINGs in environments with all dependencies installed.

## Reverse dependencies
No reverse dependencies to check.
