% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/brightcloud_cat.R
\name{brightcloud_cat}
\alias{brightcloud_cat}
\title{Get Category from Brightcloud}
\usage{
brightcloud_cat(domain = NULL, key = NULL, secret = NULL)
}
\arguments{
\item{domain}{domain name}

\item{key}{brightcloud API consumer key}

\item{secret}{brightcloud API consumer secret}
}
\value{
named list
}
\description{
Returns category of content from Brighcloud
}
\details{
Get the API Consumer Key and Secret from \url{http://www.brightcloud.com/}.
}
\examples{
\dontrun{
brightcloud_cat("http://www.google.com", key = "XXXX", secret = "XXXX")
}

}
\references{
\url{http://www.brightcloud.com/}
}
