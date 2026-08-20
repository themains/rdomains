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

### A label has a date

Most categories here come from static lists, and those lists have very different vintages
— two are no longer published at all:

```r
source_vintage()
#> key          source                         last_published  status
#> shalla       Shallalist                     2022-01         discontinued
#> dmoz         DMOZ / Open Directory Project  2017-03         discontinued
#> stevenblack  Steven Black unified hosts     NA              maintained
#> uni          Hipo university-domains-list   NA              maintained
```

This matters more than it sounds. Domains expire and get re-registered, so a category
assigned years ago may describe a site that no longer exists. `shalla_cat()` and
`dmoz_cat()` therefore return a `source_last_published` column alongside the category and
warn once per session. Treat an old label as evidence about a domain's past, not its
present.

The sibling project [piedomains](https://github.com/themains/piedomains) measured the
cost: its worst class disagreed with its own page content 71% of the time, and the cause
was not bad annotation but roughly a decade between the label and the page. Only 60% of
the domains it trained on still resolve.

### License

Scripts are released under the [MIT License](https://opensource.org/licenses/MIT).
