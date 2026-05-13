# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

rdomains is an R package that classifies domains based on their content. It provides access to multiple domain categorization services including Shallalist, VirusTotal, DMOZ, Alexa API, and machine learning models trained on Shallalist data.

## Development Commands

### Testing
```bash
# Run all tests
R -e "library(testthat); test_dir('tests/testthat')"

# Run specific test
R -e "library(testthat); test_file('tests/testthat/test-dmoz-cat.R')"

# Run tests with devtools
R -e "devtools::test()"
```

### Package Building and Checking
```bash
# Build package
R CMD build .

# Check package
R CMD check rdomains_*.tar.gz

# Install locally for testing
R CMD INSTALL .
```

### Documentation
```bash
# Build documentation with roxygen2
R -e "devtools::document()"

# Build pkgdown site
R -e "pkgdown::build_site()"

# Build vignettes
R -e "devtools::build_vignettes()"
```

### Code Quality
```bash
# Run lintr for code style checking
R -e "lintr::lint_package()"
```

## Architecture

The package is organized into several main functional areas:

### Core Functions (R/)
- **Categorization Functions**: Each service has its own `*_cat()` function:
  - `shalla_cat()`: Categories from Shallalist
  - `dmoz_cat()`: Categories from DMOZ
  - `virustotal_cat()`: Categories from VirusTotal API
  - `uni_cat()`: University domain classification
  - `adult_ml1_cat()`: ML-based adult content classification
  - `openai_cat()`: Categories from OpenAI GPT models
  - `claude_cat()`: Categories from Anthropic Claude models
  
- **Data Download Functions**: 
  - `get_shalla_data()`: Downloads Shallalist data
  - `get_dmoz_data()`: Downloads DMOZ data
  - `get_alexa_data()`: Downloads Alexa data

- **Utility Functions**:
  - `not_news()`: Predicts if domain content is not news-related

### Data (data-raw/)
- Contains raw data files and processing scripts for different categorization sources
- Models are stored in `data-raw/models/` including the GLM Shallalist model

### Key Dependencies
- **urltools**: URL parsing and manipulation
- **glmnet**: Machine learning model implementation
- **virustotal**: VirusTotal API access
- **aws.alexa**: Alexa API access
- **httr/curl**: HTTP requests and API calls
- **XML/xml2**: XML parsing
- **jsonlite**: JSON parsing for LLM APIs

## Common Patterns

### Domain Preprocessing
All categorization functions follow a common pattern for cleaning domain inputs:
1. Remove leading/trailing spaces
2. Remove "http://" prefix
3. Remove "www." prefix
4. Extract domain from full URLs

### Data File Management
Functions check for local data files first, then allow users to specify custom file paths via `use_file` parameter.

### Error Handling
Functions validate file existence and provide informative error messages directing users to download required data files.

## Testing Strategy
- Unit tests are in `tests/testthat/`
- Tests verify data frame structure and basic functionality
- Some tests require downloading external data files
- LLM function tests require API keys set as environment variables:
  - `OPENAI_API_KEY` for OpenAI tests
  - `ANTHROPIC_API_KEY` or `CLAUDE_API_KEY` for Claude tests

## LLM Integration Usage

### OpenAI Classification
```r
# Basic usage
openai_cat("google.com")

# Multiple domains
openai_cat(c("google.com", "facebook.com", "github.com"))

# Custom categories
openai_cat("domain.com", categories = c("technology", "social", "ecommerce", "other"))

# With specific model and rate limiting
openai_cat("domain.com", model = "gpt-4", rate_limit = 1.0)
```

### Claude Classification
```r
# Basic usage
claude_cat("google.com")

# Multiple domains with custom categories
claude_cat(c("site1.com", "site2.com"), categories = c("news", "tech", "other"))
```

### API Key Management
- Set environment variables: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `CLAUDE_API_KEY`
- Or pass keys as parameters: `openai_cat("domain.com", api_key = "your-key")`