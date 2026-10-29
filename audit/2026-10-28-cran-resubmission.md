# CRAN resubmission: rdomains 0.6.1

Trigger: CRAN email of 2026-10-28 asking for a fix before 2026-11-18. The check page
showed every regular flavor OK and one additional issue, noLD
(https://www.stats.ox.ac.uk/pub/bdr/noLD/rdomains.out): 12 test errors, all
`webfakes app subprocess did not start :(` with `webfakes process dead, exit code: -9`.

## Diagnosis

`webfakes::new_app_process()` waits `process_timeout` ms (default 5000, env
`R_WEBFAKES_PROCESS_TIMEOUT`) for the child R session to report its port, then kills
it and errors. The noLD host ran the suite at 41 s CPU / 146 s wall, so a fresh R
session plus `library(webfakes)` exceeded 5 s. Local startup takes 0.12 s. Running
master with `NOT_CRAN=false R_WEBFAKES_PROCESS_TIMEOUT=1` reproduces the failure
class: FAIL 15 | SKIP 22 | PASS 518 against CRAN's FAIL 12 | SKIP 22 | PASS 526; the
differences sit inside the 12 server tests, some of which progressed further under
CRAN's 5 s. Not related to long doubles.

## Change

Candidate `1ba00a5`: `skip_on_cran()` on the 12 webfakes-based tests (file-level in
`test-e2e-fetch.R`, per-test in `test-audit-http.R`), version 0.6.1, NEWS,
cran-comments, `.gitignore` for `CRAN-SUBMISSION`. No file under `R/` changed. The
"raise the timeout" alternative was considered and declined by the maintainer in
favor of removing CRAN's exposure to local-server tests entirely.

## Local evidence

- CRAN-mode check of the candidate with the hostile timeout
  (`cran = TRUE, manual = TRUE, NOT_CRAN=false, R_WEBFAKES_PROCESS_TIMEOUT=1`):
  0 errors, 0 warnings, 0 notes; tests FAIL 0 | SKIP 23 | PASS 518; zero
  "webfakes process dead" lines. Skip categories identical to the noLD log plus the
  12 server tests (reported as 5 skips: 4 per-test and 1 file-level).
- Unrestricted `devtools::test()`: the 12 server tests run and pass; 0 failures.
- Built tarball `rdomains_0.6.1.tar.gz`, SHA-256
  `5130ce3f52b54592e0682c3755c49b8bc5994994f1076a03796b04687de7bb60`, checked with
  `check_built(cran = TRUE, incoming = TRUE, manual = TRUE, force_suggests = TRUE,
  NOT_CRAN = "false")`: 0 errors, 0 warnings, 0 notes; FAIL 0 | SKIP 23 | PASS 518.
- lintr: 66 findings on both master and the candidate, none in the changed files;
  the CI lint job passes.

## Independent review

gpt-6-astra (codex exec, fresh context, isolated worktree at the candidate commit)
found no defects, confirmed no webfakes server start remains reachable under
`NOT_CRAN=false`, and reproduced FAIL 0 | SKIP 23 | PASS 518 (CRAN mode) and
FAIL 0 | SKIP 13 | PASS 593 (unrestricted). See
[evidence/cran-0.6.1-independent-review.md](evidence/cran-0.6.1-independent-review.md).
Its single NOTE came from the worktree's `.git` file entering the bundle; the real
checkout's tarball check has no notes.

## CI

PR #20: all ten jobs pass (R CMD check on Ubuntu release/devel/oldrel-1, macOS,
Windows; lint; coverage; pkgdown build; links; Python integration).

This record establishes local readiness, not CRAN acceptance.
