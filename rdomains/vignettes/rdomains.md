---
title: "Using rdomains"
author: "Gaurav Sood"
date: "2016-05-13"
vignette: >
  %\VignetteIndexEntry{Illustrating use of rdomains}
  %\VignetteEngine{knitr::rmarkdown}
  %\VignetteEncoding{UTF-8}
---


### rdomains: Get the category of content hosted by a domain

#### Install and Load the package

The latest version of the package will always be on GitHub. To install the package from GitHub and to load the installed package:


```r
library(devtools)
install_github("soodoku/domain_classifier/rdomains")
```

```
## Downloading GitHub repo soodoku/domain_classifier@master
## from URL https://api.github.com/repos/soodoku/domain_classifier/zipball/master
```

```
## Installing rdomains
```

```
## "C:/PROGRA~1/R/R-33~1.0/bin/x64/R" --no-site-file --no-environ --no-save  \
##   --no-restore --quiet CMD INSTALL  \
##   "C:/Users/gaurav/AppData/Local/Temp/RtmpIXoItD/devtools1cb869844c40/soodoku-domain_classifier-d3040bb/rdomains"  \
##   --library="C:/Users/gaurav/Documents/R/win-library/3.3"  \
##   --install-tests
```

```
## 
```

```
## Reloading installed rdomains
```

```r
library(rdomains)
```

#### Shalla

To get category of the content from shallalist:


```r
shalla_cat("http://www.google.com")
```

```
##   domain_name shalla_category
## 1  google.com   searchengines
```

#### ML 

To get category of the content based on ML (currently gives propensity of pornographic content based on name and suffix alone):


```r
name_suffix_cat("http://www.google.com")
```

```
##      domains  category
## 1 google.com 0.3133728
```

#### Virustotal

Start by getting the API key from [virustotal](https://www.virustotal.com/). 

Get virustotal category by running:


```r
virustotal_cat("http://www.google.com")
```

#### Trusted (McAfee)

Get the content category of a domain by McAfee (Trusted):


```r
trusted_cat("http://www.google.com")
```

```
## Error in eval(expr, envir, enclos): could not find function "trusted_cat"
```
