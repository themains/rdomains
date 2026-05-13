#' rdomains: Classify Domains by their Content
#'
#' Want to know what kind of content is carried on a domain?
#' Get the results quickly using rdomains. The package provides access to virustotal
#' API, shalla, aws, OpenAI GPT models, Anthropic Claude models, 
#' and validated ML model based off shallalist data to predict content of a domain.
#'
#' To learn how to use rdomains, see this vignette: \url{../doc/rdomains.html}.
#'
#' @importFrom urltools suffix_extract
#' @importFrom Matrix Matrix spMatrix sparseVector
#' @importFrom jsonlite fromJSON toJSON
#' @importFrom stats setNames predict
#' @importFrom methods as
#' @importFrom glmnet predict.glmnet
#' @importFrom utils read.table URLencode untar unzip read.csv write.csv
#' @importFrom curl curl_download
#' @importFrom httr content GET oauth_app oauth_signature add_headers POST status_code
#' @importFrom xml2 read_xml as_list
#' @importFrom XML readHTMLTable
#' @importFrom virustotal set_key domain_report
#' @importFrom R.utils gunzip
#' @importFrom dplyr mutate bind_rows
#' @importFrom purrr map_chr map_df
#' @importFrom tibble tibble as_tibble
#' @importFrom stringr str_trim str_remove str_detect
#' @importFrom rlang abort warn inform .data
#' @importFrom cli cli_abort cli_warn cli_inform
#' @importFrom checkmate assert_character assert_file_exists assert_logical
#' @importFrom glue glue
#' @importFrom readr read_csv
#'
#' @author Gaurav Sood
"_PACKAGE"
