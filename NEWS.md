# rdomains 0.1.6 

* Adds not_news classifier that classifies not news based on published work.
* passes expect_lint_free

# rdomains 0.1.5

* Shallalist and DMOZ data read in with stringAsFactors as FALSE.
* Swapped the DMOZ data to domain level category data, included English translations of non-English categories, quote protection of multiple categories.
* Accounting for changes in RSelenium --- startServer() for instance is deprecated. But currently only allow for passing of log for trusted_cat.
* Fixed bug in shalla_cat for multiple domain names arguments
* Fixed small issue with adult_ml1_cat() whose returned data.frame had a column that was a named list. The column is now a vector.
* If an unknown domain is passed to virustotal, it will return an empty data.frame rather than throw an error.

# rdomains 0.1.0

* Initial release