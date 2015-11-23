'''

Scraper
Given a list of domains, it downloads home pages of all

'''

# setwd(githubdir)
# setwd("domain_classifier/")
# setwd("content_classifier/")

# Load libs
library(curl)

# Download domains
domain_list <- read.csv("sample_in.csv")
outdir <- "html_files"
lapply(domain_list$url, function(x) curl_download(x, destfile=paste0(outdir, "/", x, ".html")))