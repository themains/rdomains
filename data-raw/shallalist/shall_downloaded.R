# Shallalist has closed shop. (1/14/2021)
# Some of the data is archived here --- https://github.com/cbuijs/accomplist/blob/master/standard.sources
setwd(paste0(githubdir, "rdomains/data-raw/shallalist/accomplist/"))

library(curl)
library(readr)

curl_download("https://raw.githubusercontent.com/cbuijs/shallalist/master/adv/domains", "ads")
curl_download("https://raw.githubusercontent.com/cbuijs/shallalist/master/gamble/domains", "gambling")
curl_download("https://raw.githubusercontent.com/cbuijs/shallalist/master/finance/banking/domains", "finance")
curl_download("https://raw.githubusercontent.com/cbuijs/shallalist/master/porn/domains", "porn")
curl_download("https://raw.githubusercontent.com/cbuijs/shallalist/master/spyware/domains", "spyware")
curl_download("https://raw.githubusercontent.com/cbuijs/shallalist/master/tracker/domains", "tracker")
curl_download("https://raw.githubusercontent.com/cbuijs/shallalist/master/violence/domains", "violence")

 
# read_lines() to read one line at a time
ads = data.frame(domains = read_lines("ads"), category = "ads")
gambling = data.frame(domains = read_lines("gambling"), category = "gambling")
finance = data.frame(domains = read_lines("finance"), category = "finance")
porn = data.frame(domains = read_lines("porn"), category = "porn")
spyware = data.frame(domains = read_lines("spyware"), category = "spyware")
tracker = data.frame(domains = read_lines("tracker"), category = "tracker")
violence = data.frame(domains = read_lines("violence"), category = "violence")

# Agg
shalla = rbind(ads, gambling, finance, porn, spyware, tracker, violence)

gz1 <- gzfile("shallalist.gz", "w")
write.csv(shalla, file = gz1, row.names = F)
close(gz1)
