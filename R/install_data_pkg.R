# Check whether to install data for rdmomains and install if necessary
#
# If the \code{rdomainsdata} package is not installed, install it from
# the \href{http://github.com/themains/rdomainsdata/}{Github site for rdomainsdata}.
check_data_package <- function() {
  package_version <- "0.3.0"
  if (!requireNamespace("rdomainsdata", quietly = TRUE)) {
    message("The rdomainsdata package needs to be installed.")
    install_data_package()
  } else if (utils::packageVersion("rdomainsdata") < package_version) {
    message("The rdomainsdata package needs to be updated.")
    install_data_package()
  }
}

#' Install the \code{rdomainsdata} package after checking with the user
#' @export
install_data_package <- function() {
  instructions <- paste(" Please try installing the package for yourself",
                        "using the following command: \n",
  "    devtools::install_github(\"https://github.com/themains/rdomainsdata\")")

  error_func <- function(e) {
    stop(paste("Failed to install the rdomainsdata package.\n", instructions))
  }

  if (interactive()) {
    input <- utils::menu(c("Yes", "No"),
                         title = "Install the rdomainsdata package?")
    if (input == 1) {
      message("Installing the rdomainsdata package.")
      tryCatch(install_github("https://github.com/themains/rdomainsdata"),
               error = error_func, warning = error_func)
    } else {
      stop(paste("The rdomainsdata package provides the data you requested.\n",
                 instructions))
    }
  } else {
    stop(paste("Failed to install the rdomainsdata package.\n", instructions))
  }
}
