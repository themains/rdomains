# CRAN submission preparation for rdomains 0.6.0

Base: `2533066ed081bc760c24acf1bebee5dac28266a4`.

A hosted review on PR #17 identified an environment synchronization defect missed
by the earlier empty-input override test. R environment changes do not update
Python's cached `os.environ`. Explicit `model` arguments are now passed to the
backend. It scopes the selected value in Python, loads the model before restoring
state, and restores the previous Python and R values independently. Unset values
remain unset. Custom checkpoints still load afresh; the immutable default remains
cached.

The new nonempty successive-call test failed eight assertions on the prior code
and passed after repair. Reversing only production code reproduced all eight
failures; restoring it passed 58 narrow assertions. A separate fresh R process
checks a custom-model load failure at first Python initialization, followed by a
successful default-model classification.

Full suite with real weights: 597 passed, 18 skipped, no failures or testthat warnings.
Lint: zero findings. The final CRAN-shaped check includes incoming checks and the PDF
manual. Windows-devel, independent follow-up review and CI results are recorded
with the submission evidence before upload.

## Final local evidence

The independent reviewer (gpt-6-astra, high reasoning, fresh context) reviewed
candidate `182053e9d99bfe9b49db07b7e6e32bddb1cefafd` and found no remaining
correctness defects. The reviewer independently reproduced the full 597-assertion
suite, a clean incoming/manual package check and 27 supplementary combinations of
R/Python environment values, model choices, failures and cache behavior. See
[evidence/cran-independent-review.md](evidence/cran-independent-review.md).

The exact tarball prepared by `devtools::submit_cran()` was checked separately
with `devtools::check_built(cran = TRUE, incoming = TRUE, manual = TRUE,
force_suggests = TRUE, error_on = "note")`. Result: zero errors, warnings or notes;
PDF and HTML manuals passed. Its installed suite passed 566 assertions with 22
intentional skips when optional Python integration and real-model tests were not
enabled. SHA-256:
`acc9a02e3007a0ca7784a9b93a82bacebd7ee8da85b0cbbbd2b8f6a5f8b9d35f`.
All 88 shipped source files match the reviewed checkout. Only build-excluded audit
records and CRAN submission comments changed after the candidate build.

CRAN source metadata queried without platform/version filters lists no reverse
dependencies. Windows-devel was submitted through `devtools::check_win_devel()`;
its returned report, final GitHub checks and submission receipt are retained with
the release artifacts when received. This record establishes local readiness,
not CRAN acceptance or publication.
