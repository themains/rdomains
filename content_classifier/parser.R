'''

Parser
Given a list of HTML files, it takes out select attributes

'''

library(rvest)
library(magrittr)

# Generic Func

get_dat <- function (html_file) {

	# Get into html form
	html <- read_html(html_file)

	# Meta Keywords
	keywords <- html_nodes(html, "meta[name=keywords]") %>% html_attr("content")
	if (length(keywords)==0) keywords <- NA

	# Meta Description
	description <- html_nodes(html, "meta[name=description]") %>% html_attr("content")
	if (length(description)==0) description <- NA


	# Getting the text
	body <- html_nodes(html, "body")

	# Take out javascript
	body_char <- as.character(body)
	nojs_body <- gsub("<script.+?</script>", " ", body_char, ignore.case=T)

	# Get it back into rvest and strip out stuff
	text <- read_html(nojs_body) %>%  
	html_text() %>% 
	str_replace_all("[\\r\\n]", "") %>%
	str_replace_all("[[:blank:]]+", " ") %>%
	str_trim

	c(keywords, description, text)

}

# Main

# Input directory
input_dir <- "html_files"
# Find all the files
files <- dir(input_dir, full.names=T)
# Apply func to all the files
out     <- lapply(files, get_dat)
# Collect into a matrix and convert to data.frame
dat_out <- data.frame(do.call(rbind, out), names=c("keywords", "description", "text"))

# Write out
write.csv(dat_out, file="sample_out.csv", row.names=F)