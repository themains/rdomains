## Classify Domains Based on Their Content
[![Build Status](https://travis-ci.org/soodoku/domain_classifier.svg?branch=master)](https://travis-ci.org/soodoku/domain_classifier)
[![Appveyor Build status](https://ci.appveyor.com/api/projects/status/yh856e6cv7uucaj2?svg=true)](https://ci.appveyor.com/project/soodoku/rdomains)
[![CRAN_Status_Badge](http://www.r-pkg.org/badges/version/rdomains)](https://cran.r-project.org/package=rdomains)
![](http://cranlogs.r-pkg.org/badges/grand-total/rdomains)
[![codecov](https://codecov.io/gh/soodoku/domain_classifier/branch/master/graph/badge.svg)](https://codecov.io/gh/soodoku/domain_classifier)

The package provides a few ways to classify domains based on their content. You can either get the categorizations from [shallalist](http://www.shallalist.de/), [trusted (McAfee)](http://trustedsource.org), [DMOZ](http://rdf.dmoz.org), [Alexa API](http://docs.aws.amazon.com/AlexaWebInfoService/latest/) (which uses the [DMOZ Data](http://rdf.dmoz.org)), or [virustotal API](http://virustotal.com), or use validated machine learning models based off the shallalist data. 

### Installation

To get the current released version from CRAN:
```r
install.packages("rdomains")
```

To get the current development version from GitHub:

```r
# install.packages("devtools")
devtools::install_github("soodoku/domain_classifier/rdomains", build_vignettes = TRUE)
```

### Usage

To learn how to use rdomains, read this [vignette](vignettes/rdomains.md). Or launch the vignette within R: 

```r
vignette("rdomains", package = "rdomains")
```

### License

Scripts are released under the [MIT License](https://opensource.org/licenses/MIT).