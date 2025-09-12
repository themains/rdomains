\name{openai_cat}
\alias{openai_cat}
\title{Get Category from OpenAI}
\usage{
openai_cat(
  domains = NULL,
  api_key = NULL,
  categories = NULL,
  model = "gpt-4o-mini",
  rate_limit = 0.5
)
}
\arguments{
\item{domains}{vector of domain names}

\item{api_key}{OpenAI API key. If not provided, looks for OPENAI_API_KEY environment variable}

\item{categories}{vector of categories to classify into. If NULL, uses default web categories}

\item{model}{OpenAI model to use (default: "gpt-4o-mini" for cost efficiency)}

\item{rate_limit}{delay in seconds between API calls (default: 0.5)}
}
\value{
data.frame with original list and content category of the domain
}
\description{
Fetches category of content hosted by a domain using OpenAI's chat completion API.
The function uses GPT models to classify domains into specified categories.
}
\examples{
\dontrun{
openai_cat("google.com")
openai_cat(c("google.com", "facebook.com"))
openai_cat("google.com", categories = c("search", "social", "ecommerce", "news", "other"))
}
}