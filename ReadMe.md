## rdomains: Classify Domains Based on Their Content

[![CRAN_Status_Badge](http://www.r-pkg.org/badges/version/rdomains)](https://cran.r-project.org/package=rdomains) 
[![Build Status](https://travis-ci.org/themains/rdomains.svg?branch=master)](https://travis-ci.org/themains/rdomains)
[![Build status](https://ci.appveyor.com/api/projects/status/3vjmwn7jyf1s17e4?svg=true)](https://ci.appveyor.com/project/soodoku/rdomains)
[![codecov](https://codecov.io/github/themains/rdomains/branch/master/graph/badge.svg)](https://codecov.io/github/themains/rdomains/)
![](http://cranlogs.r-pkg.org/badges/grand-total/rdomains)

The package provides a few ways to classify domains based on their content. You can either get the categorizations from [shallalist](http://www.shallalist.de/), [trusted (McAfee)](https://trustedsource.org/), DMOZ (the service has ended; available at [curlie](https://curlie.org/)), [Alexa API](https://docs.aws.amazon.com/AlexaWebInfoService/latest/), which uses the DMOZ Data (now hosted at [https://curlie.org](https://curlie.org)), or [virustotal API](http://virustotal.com), or use validated machine learning models based off the shallalist data.

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
