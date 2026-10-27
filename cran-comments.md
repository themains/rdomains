## Submission candidate

rdomains 0.6.0 standardizes classifier results, preserves source memberships and
input identity, and corrects archive, cache and retry behavior. NEWS documents the
breaking API changes. This candidate has not been submitted to CRAN.

## Local verification

* macOS arm64, R 4.6.0
* R CMD check: 0 errors, 0 warnings, 0 notes
* Full tests: 560 passed, 19 skipped, 0 warnings or failures
* Python 3.13.2 / piedomains 0.15.0: six real-model assertions passed offline
* lintr and actionlint passed; pkgdown and the executed vignette built successfully

The skipped tests require live services or explicit opt-in. Paid providers are
covered with mocks. No paid API calls run during routine checks. The Python model
is optional; its weights are not bundled. The dedicated integration workflow tests
R 4.5 with Python 3.12. Candidate CI and independent review are tracked in the PR.

## Notes for the reviewer

Network examples use `\dontrun{}`. Tests that access public services use
`skip_on_cran()`. File writes default to temporary locations; callers explicitly
choose any persistent download or cache destination.

The default model weights are unchanged. Their known category-confusion limits
and the historical name model's lack of current validation are documented.
