# Correctness audit and ellmer migration: rdomains 0.7.0

Base: `ee44859` (master, 0.6.1 as accepted by CRAN on 2026-10-29). Candidate: `c6117a2`
on branch `fix/audit-ellmer`, PR #21.

## Method

Plan-mode read-only audit: three exploration passes (public-API inventory with
argument/validation/forwarding checks; the LLM request path; the 2026-10-26 audit
records for prior coverage), every delegated finding re-run by hand before it was
accepted, and intuitive smoke tests of the offline classifiers. Decisions on scope were
taken by the maintainer (see "Decisions").

## Intuitive tests (before changes)

- `uni_cat`: case, scheme, path and `www.` normalised; exact host only, so
  `cs.stanford.edu` was `no_match`. `news_url_signals`: Bakshy regex over the whole URL.
  NA and `""` inputs rejected at the boundary.
- `adult_name_probability`: intercept p = 0.313 for any plain `.com` without a keyword
  hit (`google.com` = `nytimes.com` = `xvideos.com`); substring firing (`analytics.com`
  0.82, `essex.ac.uk` 0.52, `teenvogue.com` 0.96, `cumberland.edu` 0.013).
- `openai_cat` (old client), 40 well-known domains, gpt-6-luna: 40/40 in the expected or
  alternate category; 16.1 s for the first 10. `evidence/llm-eval-2026-10-29/baseline-40.csv`.

## Confirmed defects and fixes

Each fix has a regression test that failed on the unfixed code (observed) and passes
after it. One commit per item on the branch.

| # | Defect | Verification | Fix |
|---|---|---|---|
| 1 | `html_text_content()` passed a string to `xml2::read_html()`, which opens a tagless string as a path/URL | `html_text_content("/etc/hosts")` returned the file's text | bytes via `charToRaw(enc2utf8())`, `cdba877` |
| 2 | Private-address guard saw one DNS answer (`curl::nslookup` default `multiple = FALSE`) | `args(curl::nslookup)`; fake resolver test | `multiple = TRUE`, `1fc3f58` |
| 3 | VirusTotal validation errors (no HTTP status) → `service_error`, retryable | `provider_error_code(NA)` → `service_error`; `is_retryable` TRUE | `virustotal_validation_error` → `invalid_domain`, `ec7ed48` |
| 4 | Cache hit returned before `guarded_get()`, keyed by URL only | code read `collect_content.R:377`, `page_cache.R:48` | key includes `obey_robots`, `allow_hosts`, `max_bytes`; namespace `v3`, `6a13fb3` |
| 5 | Cache read-back altered bytes (readLines/paste), `content_bytes` recomputed | code read | raw gz write/read, `6a13fb3` |
| 6 | `fetch_report()$missing` documented as "produced nothing", holds failed rows | code read | doc, `30d5844` |
| 7 | `cache_clear(dir)` unvalidated | code read | string check, refuses `/` and home, `6a13fb3` |
| 8 | `pie_cat` top-1 `category` vs contract text "single label only" | code read; maintainer: keep behaviour | contract text, `30d5844` |
| 9 | Three hand-rolled host normalisers; exact-host lookups | code read; `urltools` already imported | one `clean_domains()`, registrable-domain fallback, `details$matched_key`, `0cafc72` |
| 10 | 2017 adult keyword model | smoke test above | removed with `glm_shalla` and Matrix/glmnet/stats/methods imports, `8c5ad5b` |

## LLM layer on ellmer (`a5d0daf`)

Prior art: ellmer 0.5.0 (CRAN 2026-09-04, Posit) provides `parallel_chat_structured()`
(any provider) and `batch_chat_structured()` (OpenAI, Anthropic, Gemini, Groq batch
APIs with a resumable state file), plus `type_enum()`. Verified from the installed
source: OpenAI goes through the Responses API (`/responses`, `text.format` json_schema);
Anthropic uses `output_config` json_schema for Claude ≥ 4.5; failed requests come back
in a `.error` list-column; `credentials` must be a function; prompts must be a list.

Design: `llm_cat(domains, chat, categories, mode, state_file, max_active, rpm, wait)`;
sequential = parallel with `max_active = 1`; dedupe by host; `openai_cat()`/`claude_cat()`
build the chat (`reasoning_effort = "none"`, `max_tokens = 64`). `delay` removed;
Claude's provider label is `"anthropic"`; `http_status` NA on success (ellmer does not
expose the response); `batch_pending` added to `RD_ERROR_CODES`.

Tests: fake OpenAI/Anthropic servers on webfakes (request bodies asserted: model,
`reasoning.effort = "none"`, `max_output_tokens = 64`, json_schema enum = categories;
out-of-vocabulary → `invalid_response`; 401 → `authentication_error`; 500 →
`service_unavailable`; one 429 then success → ok in 2 calls; 3 inputs of one host →
1 call; parallel 3 hosts → 3 calls); batch pending/finished via mocked
`ellmer::batch_chat_structured`; validation and empty-input identity CRAN-safe.

Live, after (gpt-6-luna, authorized cap $0.25): 10 sequential 10/10 in 9.3 s
(1,166 in / 130 out tokens); 30 parallel (`max_active = 5`) 30/30 in 8.5 s. 40/40 overall;
one changed answer vs baseline, `bloomberg.com` news → finance (both acceptable).
Total tokens 4,671 in / 531 out ≈ $0.0007 at list price; baseline ≈ $0.0003.
`evidence/llm-eval-2026-10-29/after-40.csv`.

Live, batch (OpenAI Batch API via `openai_cat(mode = "batch", wait = FALSE)`): job
`batch_6ae31eb5fa1881908f1880780e51d43e` on `/v1/responses`, 40 requests, submitted
2026-10-29 and completed 125 minutes later (provider `request_counts`: 40 completed,
0 failed). The first call returned `batch_pending` for every row; a later call with the
same `state_file` returned 40 `ok` rows. 40/40 correct against the expected set; one
answer differs from the sequential run, `bloomberg.com` finance → news (the baseline's
answer). `evidence/llm-eval-2026-10-29/batch-40.csv`. Batch pricing is half of list, so
≈ $0.0003.

## Checks on the candidate

- Unrestricted suite (`NOT_CRAN=true`): FAIL 0 | WARN 0 | SKIP 13 | PASS 631.
- CRAN-mode check (`cran = TRUE, manual = TRUE, NOT_CRAN=false`): 0 errors, 0 warnings,
  0 notes; tests FAIL 0 | SKIP 30 | PASS 502.
- lintr: no findings in changed files; remaining findings are pre-existing
  object-usage notes elsewhere.
- Independent review and CI: see the section below, appended when complete.

## Decisions

- Maintainer chose: ellmer migration; fix all confirmed defects; keep `pie_cat` top-1
  and amend the contract text; add host normalisation with registrable-domain fallback;
  remove the adult model; paid smoke tests up to $0.25.
- Not submitted to CRAN with this record. 0.6.1 was accepted on 2026-10-29; CRAN asks
  for no more than one update every one to two months unless requested, so 0.7.0 should
  wait until late November at the earliest.

## Independent review

gpt-6-astra (codex exec, fresh context, isolated worktrees). Round 1 on `c6117a2`:
[evidence/0.7.0-independent-review-round1.md](evidence/0.7.0-independent-review-round1.md).
Round 2 on `6251d20`:
[evidence/0.7.0-independent-review-round2.md](evidence/0.7.0-independent-review-round2.md).
Counts reproduced by the reviewer matched the local runs (631 then 637 passed, 0 failed;
CRAN-mode 502 passed, 0 failed; the reviewer's single NOTE is the worktree's `.git`
file entering the bundle, absent from the real checkout).

Findings and dispositions:

- **P1, fixed (`6a77818`).** One malformed 200 body aborted the whole call because
  ellmer raised before its `.error` column existed. `llm_run_prompts()` now bisects on
  error down to the single offender, reported as `invalid_response`; HTTP errors are
  told apart by the `httr2_error` class. Reviewer re-ran five scenarios (middle reply
  malformed, all malformed, parallel mode, invalid outer JSON in both modes): rows
  preserved, offender failed, 8 requests each for three prompts. Cost of the fallback:
  successful prompts in a failed half are re-sent once per level of the split.
- **P2, accepted as a documented limitation, reviewer dissenting.** A response marked
  `incomplete`/`max_tokens` whose text nevertheless parses to a valid `{"category": enum}`
  is reported as ok. ellmer's structured path discards the finish reason, so checking it
  would mean giving up `parallel_chat_structured()`. Maintainer's reasoning: the schema
  is a one-field enum object, so a reply that parses and holds a valid enum value is
  complete regardless of why generation stopped; no partial label is possible. The
  reviewer's position is that provider documentation asks callers to check the stop
  reason and that JSON parseability does not establish normal completion. Neither side
  has a captured live response exhibiting the case. Revisit if ellmer exposes finish
  reasons from its structured helpers.

## CI

PR #21 on `871976a`: all jobs pass. Along the way: curlie.org excluded from link checks
(502 on two separate runs the same day) and the provider base URLs (404 by design);
`cache_clear("/")` was not refused on Windows because `normalizePath("/")` yields `D:\`,
fixed by comparing `dirname(resolved)` to `resolved` with `winslash = "/"`.
