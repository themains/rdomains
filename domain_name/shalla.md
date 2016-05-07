## Classifying Pornographic Domains Using Keywords and Domain Suffixes

Start by setting the global option that Strings not be treated as factors.

```r
# Global options
options(StringsAsFactors=FALSE)
```

Load the relevant libraries

```r
# Load libs 
library(urltools)
library(goji)
```

```
## 
## Attaching package: 'goji'
```

```
## The following object is masked from 'package:graphics':
## 
##     stars
```

```r
library(glmnet)
```

```
## Loading required package: Matrix
```

```
## Loading required package: foreach
```

```
## foreach: simple, scalable parallel programming from Revolution Analytics
## Use Revolution R for scalability, fault tolerance and more.
## http://www.revolutionanalytics.com
```

```
## Loaded glmnet 2.0-5
```

Read in the shallalist data

```r
# Load the data
shalla <- read.csv("shalla_cat_unique_host.csv")
```

### Featurizing

Keyword list based features:


```r
# Load porn keywords
knotty_file <- file("knotty_words.txt", "r")
knotty      <- readLines(knotty_file, warn=F)
close(knotty_file)
knotty      <- unlist(strsplit(knotty, ", "))

# Let us just initialize new cols for each of the knotty words
shalla[, knotty] <- NA

for (j in knotty) {

    shalla[, j] <- grepl(j, shalla$hostname)
}
```

Whether or not domain name is simple an IP address:

```r
# Code for IP
#sum(grepl("^[0-9]*.[0-9]*.[0-9]*.[0-9]", shalla$hostname[shalla$cat==0]))/sum(length(shalla$hostname[shalla$cat==0]))
shalla$num <- grepl("^[0-9]*.[0-9]*.[0-9]*.[0-9]", shalla$hostname)
```

Change features of type Boolean to numeric:

```r
# Numerics
shalla[,3:length(shalla)] <- shalla[,3:length(shalla)]*1
shalla$porn_cat <- as.numeric(shalla$category=="porn")
```

Domain suffix based features:

```r
# Code for TLDs
split_url <- suffix_extract(shalla$hostname)
shallam   <- merge(shalla, split_url, by.x="hostname", by.y="host", all.x=T, all.y=F)

shallam$subdomain <- nona(shallam$subdomain)
shallam$suffix    <- nona(shallam$suffix)

# Create dummies
unique_cats <- unique(shallam$suffix)

for(t in unique_cats) {
  shallam[, t] <- grepl(t, shallam$suffix)
}
```

Take out sparse columns:

```r
# Take out sparse cols.
col_sums     <- colSums(shallam[, unique_cats])
dispose_cats <- unique_cats[which(unique_cats %in% names(col_sums)[col_sums <= 100])]
shallams     <- shallam[,- which(names(shallam) %in% dispose_cats)]
remain_cats  <- unique_cats[!(unique_cats %in% dispose_cats)]
```

Split the data into training and test (not really needed):

```r
# Split into train and test 
set.seed(31415)
train_samp   <- sample(nrow(shallams), nrow(shallams)*.9)
shalla_train <- shallam[train_samp, ]
shalla_test  <- shallam[-train_samp,]
```

Fit a cross-validated lasso using glmnet: 

```r
# Analyze
glm_shalla <- cv.glmnet(as.matrix(shalla_train[, c(knotty, "num", remain_cats)]), shalla_train$porn_cat, alpha=1, family = "binomial", nfolds=5, type.measure="class")
```

Predict and assess accuracy within sample:

```r
pred       <- predict(glm_shalla, as.matrix(shalla_train[, c(knotty, "num", remain_cats)]), s = "lambda.min", type="response")
# In sample prediction Accuracy
table(pred > .5, shalla_train$porn_cat)
```

```
##        
##              0      1
##   FALSE 491038 178043
##   TRUE   27112 310333
```

```r
sum(diag(table(pred > .5, shalla_train$porn_cat)))/nrow(shalla_train)
```

```
## [1] 0.7961752
```

Predict and assess accuracy out of sample:

```r
# Predict Out of sample 
pred       <- predict(glm_shalla, as.matrix(shalla_test[, c(knotty, "num", remain_cats)]), s = "lambda.min", type="response")
table(pred > .5, shalla_test$porn_cat)
```

```
##        
##             0     1
##   FALSE 54478 19856
##   TRUE   3022 34481
```

Accuracy metric:

```r
# Accuracy
sum(diag(table(pred > .5, shalla_test$porn_cat)))/nrow(shalla_test)
```

```
## [1] 0.7954344
```
