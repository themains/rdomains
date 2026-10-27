# rdomains 0.6.0 candidate

Base: `1bad0007a09f30e42709d04aa8141e05eb3cfbec` (PR #16).
The second audit is in `2026-10-26-design.md`.

## Repairs

The public classifiers now share a typed result, preserve input identity, distinguish
missing memberships from failures, and retain all source labels. Source-specific
records and collection/model provenance remain available in `details`. The README
organizes entry points by the user's question and demonstrates saving and resuming.

Shared helpers own result construction, lookup matching, LLM batch outcomes,
download destinations and acquired-page processing. The unused XML dependency and
unused thin-page helper were removed. Renamed measurements describe their actual
scope: `adult_name_probability()` and `news_url_signals()`.

Collection preserves archive URL paths, distinguishes archive and robots outages,
expires failed robots lookups after at most 60 seconds, treats malformed cache
metadata as a miss, and handles 404 and unresolved 3xx responses explicitly. Archive
fallback is opt-in. Long articles mentioning a parking service remain content.
Malformed CDX responses and unusable archive captures retain distinct outcomes.

The default immutable piedomains checkpoint is reused within an R session. Custom
checkpoints are loaded afresh, with scoped environment overrides. A versioned
outcome fixture documents intentional R/Python differences. A dedicated CI job
checks R 4.5/Python 3.12, real-weight parity, and cached offline inference.

## Validation evidence

- Initial new targeted tests: 67 assertions passed, no skips or warnings. Final
  targeted suites contain 82 assertions after independent-review repairs.
- `release-revert-checks.py`: 18 isolated production reversals each failed with
  the tests retained, then passed after restoration. Individual logs are in
  `evidence/release-reverts/`; source changes in the working checkout were untouched.
- `lintr::lint_package()` after `devtools::load_all()`: no lints.
- `actionlint`: passed.
- pkgdown: complete site and executed vignette built successfully.
- Real pinned checkpoint: 6 assertions passed on CPU with network access disabled,
  including native Python equivalence and repeated inputs. The Python interpreter
  emitted a multiprocessing semaphore-cleanup warning at shutdown on macOS.
- Full suite: 560 assertions passed, 19 skipped (live services and real-model opt-in),
  zero failures or warnings. R CMD check: 0 errors, 0 warnings, 0 notes on R 4.6.0/macOS.
- Shipped links: 51 checked occurrences, 40 successful, 11 established exclusions,
  zero errors after correcting the Steven Black registry URL.
- Independent review passed on `a6d6fe0fae102724a64d8f57a7e7486c692a6be3`.
  Candidate CI is tracked in [PR #17](https://github.com/themains/rdomains/pull/17).

Tests use mocked paid providers. No paid inference or training was run. Docker's
local daemon was unavailable; native R and Python checks were used.

## Model quality still requires separate work

The 44-label `gojiberries/piedomains-text` checkpoint remains revision
`38d7e6403f911902f47b9218ce5c645a06dd02fe`. The wrapper does not repair its documented
retail/drugs confusion. The historical 2017 adult model has no current calibration
study. Renaming and documenting these limitations does not establish accuracy.

A separate training-data candidate prepared from cached verdicts removes 259
suspected training disagreements while preserving validation/test files. It is not
independent human gold, and no new weights or improved accuracy are claimed.
Before replacing the checkpoint: freeze an independent, temporally documented
reference set; measure macro-F1, per-class precision/recall, confusion and calibration;
compare a repaired model on that untouched set; publish data/model provenance.
Paid labeling or training needs a spending limit before execution.

## Publication

Version 0.6.0 reflects deliberate API changes listed in NEWS. Preparing the candidate
and draft release does not submit to CRAN or publish a tag. Those actions follow the
reviewed candidate, completed CI and publication authorization.

## Independent review repairs

Reviewer: `gpt-6-astra`, selected through the agent tool with a fresh context and
isolated clone `/tmp/rdomains-independent-060`; base `1bad000`, first candidate `221a525`.
The reviewer independently matched 560 assertions / 19 skips, zero lint, and six
offline real-model assertions. Its initial package-check invocation enabled extra
network tests through devtools' default environment; final verification explicitly
sets `env_vars = c(NOT_CRAN = "false")`.

Four concrete findings were reproduced locally and repaired:

1. Inference-only retries discarded caller-restored IDs. The outer result IDs now
   become the retained page IDs before inference. The new test failed two assertions
   before repair and passed afterward.
2. VirusTotal authentication and missing-resource errors were wrongly retryable.
   Typed conditions and available HTTP status now determine the outcome. A shared
   provider mapping also serves the LLM adapters. The supported dependency minimum
   is virustotal 0.7.0, verified on CRAN. Malformed vendor labels fail one row.
3. Archive resource guards became transient outages. The original guard code and
   available status are retained. Size, private-address and redirect-limit probes
   failed six assertions before repair and passed afterward.
4. The mocked Python test left a fake model in the session cache. It now restores
   the prior cache. The combined mocked/real tier failed three assertions before
   repair; CI now runs the combined tier before a separate offline check.

Targeted production reversals cover the new ID, vendor and archive fixes in addition
to the original 18 checks. The full model tier and release gates were rerun on the
repaired candidate; all four independent findings are closed.

## Final local and independent verification

Code candidate: `a6d6fe0fae102724a64d8f57a7e7486c692a6be3`. Subsequent evidence and
submission-comment edits are excluded from the package by `.Rbuildignore`.

Both the implementation checkout and independent checkout passed the full combined
suite: **581 assertions, 18 skips, zero failures and zero testthat warnings**. The
skips are eight paid-provider opt-ins and ten CRAN-excluded public-network tests.
Both R CMD checks passed with **0 errors, 0 warnings, 0 notes**; the package-check
tier passed 575 assertions with 19 skips (the additional skip is real weights).
Both lint runs were clean. The independent reviewer also ran 11 unchanged regression
assertions that failed on the first candidate and passed on the repaired candidate.

The earlier real-weight test ran on CPU. The final combined suite and installed
artifact smoke test ran on Apple MPS; both matched native Python predictions.
The known interpreter semaphore-cleanup warning occurred only after successful
process exit. CI's Ubuntu job verifies the CPU path and Python 3.12/R 4.5 floor.

The built tarball installed successfully into an isolated library. Its smoke test
verified multiple lookup memberships, typed empty results, RDS save/reload,
offline real-model inference and caller-restored IDs. The tarball excludes audit
records, raw training data and generated website files. The final pkgdown build
and actionlint check passed.

There are 22 targeted production reversal cases, each failed without its fix and
passed after restoration. The model-test isolation regression was reproduced by
running mocked and real tests together before and after its fixture repair.

No model weights were changed. No paid providers, training, CRAN submission or
published release tag were involved in this verification.
