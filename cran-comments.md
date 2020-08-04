This is a resubmission.
----------------------------------

there were three issues that were identified:

1. the function "predict.cv.glmnet" is part of the glmnet package. see here:
https://github.com/cran/glmnet/blob/master/R/predict.cv.glmnet.R

when i use R CMD Check, it popped a message that it couldn't find predict.cv.glmnet in the namespace. So I used ::: and now CRAN has rejected the package as ::: produces a note.

2. the following URL opens up just fine for me:
https://support.alexa.com/hc/en-us/articles/200461990-Can-I-get-a-list-of-top-sites-from-an-API-
but it throws a 403 for CRAN build. i have changed the URL to refer to a more top-level page in the hope that it will help.

3. on linux, the following URL https://dmoztools.net (which seems to have a problematic security certificate) throws a libcurl error. I switched to http

## Test environments
* ubuntu 12.04 (on travis-ci), R 3.5.0
* Windows Server 2012 R2 (x64) (on appveyor), R 3.5.0
* local Windows 10 (x64), R 4.0.2

## R CMD check results
There were no ERRORs, or WARNINGs.
