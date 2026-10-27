#' rdomains: Classify Domains by their Content
#'
#' Want to know what kind of content is carried on a domain?
#' Get the results quickly using rdomains. The package provides access to virustotal
#' API, UT-Capitole, archived lists, OpenAI models, Anthropic Claude models,
#' and a historical model trained on Shallalist data. Use [pie_cat()] to classify
#' fetched content through the Python piedomains text model.
#'
#' To learn how to use rdomains, see this vignette: \url{../doc/rdomains.html}.
#'
#' @importFrom urltools suffix_extract
#' @importFrom Matrix Matrix spMatrix sparseVector
#' @importFrom jsonlite fromJSON toJSON
#' @importFrom stats setNames predict
#' @importFrom methods as
#' @importFrom glmnet predict.glmnet
#' @importFrom utils read.table URLencode untar unzip read.csv write.csv packageVersion
#' @importFrom curl nslookup
#' @importFrom httr2 req_url_query req_headers req_headers_redacted
#' @importFrom httr2 req_body_json req_error req_perform resp_status resp_body_string
#' @importFrom httr2 request req_user_agent req_timeout req_throttle req_retry
#' @importFrom httr2 req_options resp_content_type
#' @importFrom httr2 resp_url url_parse resp_header
#' @importFrom xml2 read_html xml_find_all xml_find_first xml_remove
#' @importFrom xml2 xml_text xml_attr url_absolute
#' @importFrom virustotal domain_report
#' @importFrom R.utils gunzip
#' @importFrom dplyr mutate bind_rows
#' @importFrom purrr map_chr map_df
#' @importFrom tibble tibble as_tibble tribble
#' @importFrom stringr str_trim str_remove str_detect str_match str_replace_all regex
#' @importFrom rlang abort warn inform .data hash
#' @importFrom cli cli_abort cli_warn cli_inform
#' @importFrom checkmate assert_character assert_file_exists assert_logical
#' @importFrom glue glue
#' @importFrom readr read_csv
#'
#' @author Gaurav Sood
"_PACKAGE"
