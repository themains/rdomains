#' Get Category from OpenAI
#'
#' Fetches category of content hosted by a domain using OpenAI's chat completion API.
#' The function uses GPT models to classify domains into specified categories.
#'
#' @param domains vector of domain names
#' @param api_key OpenAI API key. If not provided, looks for OPENAI_API_KEY environment variable
#' @param categories vector of categories to classify into. If NULL, uses default web categories
#' @param model OpenAI model to use (default: "gpt-4o-mini" for cost efficiency)
#' @param rate_limit delay in seconds between API calls (default: 0.5)
#' 
#' @return data.frame with original list and content category of the domain
#' 
#' @export
#' @examples \dontrun{
#' openai_cat("google.com")
#' openai_cat(c("google.com", "facebook.com"))
#' openai_cat("google.com", categories = c("search", "social", "ecommerce", "news", "other"))
#' }

openai_cat <- function(domains = NULL, api_key = NULL, categories = NULL, 
                      model = "gpt-4o-mini", rate_limit = 0.5) {
  
  if (is.null(domains)) stop("Please provide domain names to classify.")
  
  # Nuke leading and trailing spaces
  c_domains <- gsub("^ *| *$", "", domains)
  
  # nuke leading http://
  c_domains <- gsub("^https?://", "", c_domains)
  
  # nuke leading www.
  c_domains <- gsub("^www\\.", "", c_domains)
  
  # Default categories if not specified
  if (is.null(categories)) {
    categories <- c("news", "shopping", "social", "adult", "gambling", "technology",
                   "finance", "education", "entertainment", "business", "other")
  }
  
  # Initialize results df
  domain_cat <- data.frame(domain_name = c_domains, openai_category = NA_character_,
                          stringsAsFactors = FALSE)
  
  # Handle API key
  if (is.null(api_key)) {
    api_key <- Sys.getenv("OPENAI_API_KEY")
    if (identical(api_key, "")) {
      stop("Please provide OpenAI API key via api_key parameter or OPENAI_API_KEY environment variable.")
    }
  }
  
  # Process each domain
  for (i in seq_along(c_domains)) {
    domain <- c_domains[i]
    
    # Create prompt
    prompt <- paste0(
      "Classify the website domain '", domain, "' into exactly one of these categories: ",
      paste(categories, collapse = ", "), 
      ". Consider what type of content this domain likely hosts based on the domain name. ",
      "Respond with only the category name, no explanation or punctuation."
    )
    
    # Prepare API request
    request_body <- list(
      model = model,
      messages = list(
        list(role = "user", content = prompt)
      ),
      max_tokens = 50,
      temperature = 0.1
    )
    
    # Make API call
    tryCatch({
      response <- httr::POST(
        url = "https://api.openai.com/v1/chat/completions",
        httr::add_headers(
          "Authorization" = paste("Bearer", api_key),
          "Content-Type" = "application/json"
        ),
        body = jsonlite::toJSON(request_body, auto_unbox = TRUE),
        encode = "raw"
      )
      
      if (httr::status_code(response) == 200) {
        result <- jsonlite::fromJSON(httr::content(response, "text", encoding = "UTF-8"))
        category <- trimws(result$choices[1, ]$message$content)
        
        # Validate category is in allowed list
        if (category %in% categories) {
          domain_cat$openai_category[i] <- category
        } else {
          # If not exact match, try to find closest match or default to "other"
          domain_cat$openai_category[i] <- "other"
        }
      } else {
        warning(paste("API call failed for domain", domain, "- Status:", httr::status_code(response)))
        domain_cat$openai_category[i] <- NA_character_
      }
    }, error = function(e) {
      warning(paste("Error processing domain", domain, ":", e$message))
      domain_cat$openai_category[i] <- NA_character_
    })
    
    # Rate limiting
    if (i < length(c_domains)) {
      Sys.sleep(rate_limit)
    }
  }
  
  return(domain_cat)
}