#' @title rdomains: Classify Domains by their Content
#' 
#' @name rdomains-package
#' @aliases rdomains
#'
#' @description Want to know what kind of content is carried on a domain?
#' Get the results quickly using rdomains. The package provides access to virustotal
#' API, shalla, and validated ML model based off shallalist data to predict content
#' of a domain.
#'
#' To learn how to use rdomains, see this vignette: \url{vignettes/rdomains.html}. 
#' 
#' @importFrom urltools suffix_extract
#' @importFrom Matrix Matrix spMatrix sparseVector
#' @importFrom glmnet predict.cv.glmnet
#' @importFrom stats setNames
#' @importFrom methods as
#' @importFrom utils read.table URLencode untar unzip read.csv write.csv 
#' @importFrom curl curl_download
#' @importFrom XML readHTMLTable
#' @importFrom RSelenium remoteDriver checkForServer startServer
#' @importFrom virustotal set_key domain_report
#' @importFrom aws.alexa set_secret_key url_info
#' 
#' @docType package
#' @author Gaurav Sood
NULL
