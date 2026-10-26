# October 2026 repair plan

Baseline: de4df77; R CMD check 0 errors/warnings/notes; local tests pass with 18 external-service skips; lint clean.

- [x] Preserve raw HTML and per-row identity in the piedomains bridge. Require piedomains >=0.15.0, apply thresholds to the full distribution, record real model provenance and inference outcomes.
- [x] Parse hosts; preserve case-sensitive URL resources in caches; enforce robots and address guards on every content and robots redirect; validate crawler boundaries.
- [x] Select archive captures at or before the requested date and reject empty/malformed CDX responses.
- [x] Update OpenAI/Claude defaults and request parameters; enforce category schemas and credential precedence without leaking keys or changing session credentials.
- [x] Record verified publication and download dates separately; correct DMOZ snapshot provenance; distinguish blocklist absence from safety; document old-model scope.
- [x] Regression and revert checks, real checkpoint parity, full tests/lint/R CMD check, generated docs and pkgdown.
- [ ] Resolve model-label repair scope and budget separately; do not claim pretrained-weight accuracy fixed by wrapper repairs.

Paid API smoke evaluation and model labeling/retraining remain pending scope and budget. No release was published.
