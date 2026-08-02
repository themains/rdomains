## Submission

rdomains 0.5.0. This release adds page fetching so a domain can be classified
on its current content, and surfaces the vintage of the static label sources.

Two of the package's four lookup sources are no longer published (DMOZ closed
March 2017, Shallalist January 2022). Lookups against them now return a
`source_last_published` column and warn once per session, so a decade-old label
is no longer presented identically to one from a maintained list.

New `collect_content()` fetches homepage HTML and text. It identifies itself as
`rdomains/<version>` with a contact URL, obeys robots.txt including Crawl-delay,
throttles per host, caps the response body, follows redirects one hop at a time
so each is re-validated, and refuses hosts resolving to private or link-local
addresses.

## Test environments

* local macOS, R 4.5.x
* GitHub Actions: ubuntu release/devel/oldrel-1, macOS release, windows release

## R CMD check results

0 errors | 0 warnings | 0 notes

## Notes for the reviewer

* Functions that access the network (`collect_content()`, `get_shalla_data()`,
  `get_dmoz_data()`, `get_stevenblack_data()`, `uni_cat()`, `openai_cat()`,
  `claude_cat()`, `virustotal_cat()`) are wrapped in `\dontrun{}` in examples.
  Tests touching the network are guarded with `skip_on_cran()` and
  `skip_if_offline()`, and the package installs, loads and passes its offline
  tests with no network.
* No file is written outside `tempdir()` unless the caller supplies a path.
* `openai_cat()`, `claude_cat()` and `virustotal_cat()` require API keys; their
  tests skip when the relevant environment variable is unset.

## Reverse dependencies

None.
