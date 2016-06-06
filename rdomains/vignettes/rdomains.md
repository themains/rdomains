---
title: "Using rdomains"
author: "Gaurav Sood"
date: "2016-06-06"
vignette: >
  %\VignetteIndexEntry{Illustrating use of rdomains}
  %\VignetteEncoding{UTF-8}
---


### rdomains: Get the category of content hosted by a domain


**Caveat**  

If the package is being used to classify browsing data, an important caveat is in order. There is a strong skew in browsing data, with a few domains constituting a significant chunk of browsing time and visits. Classification error in classes gotten from APIs and generic ML classifiers implemented in the package do not weight the error by frequency of visits. We provide two ways to address the problem. First, the package includes [Alexa top 1 million domains (zip)](http://s3.amazonaws.com/alexa-static/top-1m.csv.zip). We also provide access to the Alexa API that gives traffic numbers. And build a ML classifier that weights by the traffic numbers. 

#### Install and Load the package

The latest development version of the package will always be on GitHub. To install the package from GitHub and to load the installed package:


```r
#library(devtools)
install_github("soodoku/domain_classifier/rdomains")
```
To install the package from CRAN, type in: 


```r
install.packages("rdomains")
```

Next, load the package:


```r
library(rdomains)
```

#### Shalla

To get category of the content from [shallalist](http://www.shallalist.de):


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

#### Virustotal

Start by getting the API key from [virustotal](https://www.virustotal.com/). 

Get virustotal category by running:


```r
virustotal_cat("http://www.google.com")
```
```
##                 domain   bitdefender dr_web  alexa        google       websense             trendmicro
## 1 http://www.google.com searchengines  chats google searchengines advertisements search engines portals
```
#### Trusted (McAfee)

Get the content category of a domain according to McAfee (Trusted):


```r
trusted_cat("http://www.google.com")
```

#### Alexa Category

To get the category of content from Amazon (Alexa) (which provides it via DMOZ), start by getting credentials from [https://aws.amazon.com/](https://aws.amazon.com/). Next, set the environment variables:


```r
Sys.setenv("AWS_ACCESS_KEY_ID", "key_id") 
Sys.getenv("AWS_SECRET_ACCESS_KEY", "secret_key")
```

Then run,


```r
alexa_cat(domain="http://www.google.com")[1,]
```

```
##                   Title                                           AbsolutePath
## 1 Search Engines/Google Top/Computers/Internet/Searching/Search_Engines/Google
```
