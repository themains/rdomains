## Resubmission

CRAN reported 12 test errors on the noLD additional check for 0.6.0. All 12 came from
tests that start a local webfakes HTTP server: on that host the server subprocess did
not start within webfakes' 5 s default timeout, so webfakes killed it and the tests
errored. All other flavors passed. Those 12 tests now call skip_on_cran() and run only
locally and in continuous integration. No package code changed.

## Test environments

* macOS arm64, R 4.6.0: devtools::check() with CRAN incoming checks and the PDF manual.
* GitHub Actions: Ubuntu release/devel/oldrel-1, macOS release, Windows release.
* R 4.5 and Python 3.12: full R/Python integration and cached offline model inference.

## R CMD check results

0 errors | 0 warnings | 0 notes

The full local suite with the optional Python model passed 597 assertions with
18 intentional skips. Independent review reproduced the full suite and clean
package check. Paid-provider tests use mocks; live calls require explicit opt-in.

## Changes

This update gives classifiers a common result format, preserves all lookup
memberships and original inputs, and repairs collection, archive, retry and model
selection behavior. NEWS documents the breaking changes, including the renamed
adult_name_probability() and news_url_signals() functions and the delay argument.
The minimum R version is now 4.5.0, covered by the integration and old-release checks.

The optional Python classifier is loaded only when requested. Its weights are not
bundled or downloaded at installation/startup. The existing models are unchanged;
known classification limits are documented, without a new accuracy claim.

## Reverse dependencies

No reverse dependencies were returned by tools::package_dependencies() against
current CRAN source metadata, including Depends, Imports, LinkingTo and Suggests.

## Other notes

Network examples use dontrun; public-service tests use skip_on_cran(). File writes
default to temporary directories unless the caller explicitly supplies a persistent
location. The maintainer and license are unchanged.
