## rdomains: Classify Domains Based on Their Content

[![CRAN_Status_Badge](http://www.r-pkg.org/badges/version/rdomains)](https://cran.r-project.org/package=rdomains) 
[![R-CMD-check](https://github.com/themains/rdomains/workflows/R-CMD-check/badge.svg)](https://github.com/themains/rdomains/actions/workflows/r.yml)
![](http://cranlogs.r-pkg.org/badges/grand-total/rdomains)

The package provides several ways to classify domains based on their content. You can get categorizations from Shallalist (service discontinued - using archived data), DMOZ (service ended; available at [curlie](https://curlie.org/)), Alexa API (discontinued), [VirusTotal API](https://www.virustotal.com), **OpenAI GPT models**, **Anthropic Claude models**, or use validated machine learning models based off the shallalist data.

### Installation

To get the current release version from CRAN:

```r
install.packages("rdomains")
```

To get the current development version from GitHub:

```r
# install.packages("devtools")
devtools::install_github("themains/rdomains", build_vignettes = TRUE)
```

### Usage

To learn how to use rdomains, launch the vignette within R:

```r
vignette("rdomains", package = "rdomains")
```

### License

Scripts are released under the [MIT License](https://opensource.org/licenses/MIT).
