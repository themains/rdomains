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
