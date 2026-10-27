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

- New targeted tests: 67 assertions passed, no skips or warnings.
- `release-revert-checks.py`: 18 isolated production reversals each failed with
  the tests retained, then passed after restoration. Individual logs are in
  `evidence/release-reverts/`; source changes in the working checkout were untouched.
- `lintr::lint_package()` after `devtools::load_all()`: no lints.
- `actionlint`: passed.
- pkgdown: complete site and executed vignette built successfully.
- Real pinned checkpoint: 6 assertions passed on CPU with network access disabled,
  including native Python equivalence and repeated inputs. The Python interpreter
  emitted a multiprocessing semaphore-cleanup warning at shutdown on macOS.
- Full suite, package check, independent review and candidate CI are release gates;
  their final results will be recorded before release preparation is declared complete.

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
