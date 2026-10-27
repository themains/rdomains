# Execution follow-up

The repair branch is submitted as [rdomains PR #16](https://github.com/themains/rdomains/pull/16).
GitHub operations use the user's authenticated `gh` CLI.

## Independent review

A separate GPT-5.6 reviewer tested an isolated checkout and reproduced four regressions
introduced by the HTTP/cache refactor. Each has a regression test and a verified repair:

- Restore the existing bounded retry for transient HTTP failures, including robots.txt.
- Treat URL-key parsing errors as cache misses so malformed inputs return failed rows
  instead of aborting a collection batch. Cached reads still do not require DNS.
- Do not follow empty redirect locations back to the same resource.
- Cache fail-closed robots results through the same TTL path as other robots outcomes.

The full local suite passes 480 assertions with 18 expected external/paid-service skips
and no failures or warnings. Lint has zero findings. The four additional production
reversions all fail their corresponding tests, then pass after restoration; see
[evidence/review-revert-checks.json](evidence/review-revert-checks.json). Together with the
original audit, 28 targeted reversions have been checked.

The final local R CMD check completed with zero errors, warnings or notes. The
repository link-check command checked 59 links (41 unique), with 52 successful and
7 existing exclusions, and reported zero errors.

## CI repair

The shared `r-canon@v2` tag still points to an older workflow with r-lib/actions v2.12.1.
On Ubuntu 26.04 that action loses `R_LIB_FOR_PAK` when invoking sudo-rs. The upstream
fix is already in r-lib/actions v2.14.0 and in r-canon's default branch.

The four affected rdomains workflows now reference the immutable shared-workflow commit
`48db3249d3f6e50d9f8e57d53e57f8ffd60182cc`. This scopes the dependency update to rdomains;
the shared major tag and unrelated local r-canon edits remain untouched. Actionlint passes.

UT-Capitole's landing page returned HTTP 503 repeatedly while its official dataset endpoint
returned 200. The download function's reference now links to that actual source dataset.
The link checker remains enabled.

## Model-data preparation

The original prepared-text corpus follows the current deterministic domain split: no
cross-split overlap or incorrect split assignments were found. An older prepared-taxonomy
corpus does not follow that split rule and was not used.

The previous prepared-relabelled corpus removed validation/test rows and reduced the
vocabulary to 42 classes. A separate training-only candidate now preserves all 44 labels
and copies validation, test and labels files byte-for-byte from prepared-text:

| Split | Original rows | Candidate rows |
| --- | ---: | ---: |
| Training | 36,233 | 35,974 |
| Validation | 4,553 | 4,553 |
| Test | 4,382 | 4,382 |

Only 259 training disagreements in the drugs class were removed, using the existing
cached verdicts at confidence >=0.8 and excluding truncated verdicts. Every retained
training record is unchanged. The candidate and checksum manifest are stored locally in
`piedomains/data/training-repair-20261026/`; original corpora remain untouched.

This is a weak-label candidate, not independently adjudicated gold or a validated new
model. Cached confidence is not evidence that a label is correct. No API calls were made,
no new weights were trained, and no accuracy improvement is claimed. Paid labeling or
compute remains pending a spending cap; independent label review remains necessary.
