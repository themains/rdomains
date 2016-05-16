## Classify Domains Based on Their Content
[![Build Status](https://travis-ci.org/soodoku/domain_classifier.svg?branch=master)](https://travis-ci.org/soodoku/domain_classifier)
[![Appveyor Build status](https://ci.appveyor.com/api/projects/status/yh856e6cv7uucaj2?svg=true)](https://ci.appveyor.com/project/soodoku/rdomains)
[![CRAN_Status_Badge](http://www.r-pkg.org/badges/version/rdomains)](https://cran.r-project.org/package=rdomains)
![](http://cranlogs.r-pkg.org/badges/grand-total/rdomains)

The package provides a few ways to classify domains based on their content. For now, it is limited to providing categorized based on [shallalist](http://www.shallalist.de/), [trusted (McAfee) 'API'](http://trustedsource.org), [virustotal API](http://virustotal.com) (which uses [websense](https://www.forcepoint.com/)), and a couple of ML solutions based off shallalist data. 

### Installation

To get the current development version from GitHub:

```r
# install.packages("devtools")
devtools::install_github("soodoku/domain_classifier/rdomains", build_vignettes = TRUE)
```

To see how to use rdomains, see this [vignette](vignettes/rdomains.md). To launch the vignette within R: 

```r
vignette("rdomains", package = "rdomains")
```

### License

Scripts are released under the [MIT License](https://opensource.org/licenses/MIT).