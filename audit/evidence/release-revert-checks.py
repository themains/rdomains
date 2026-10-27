"""Verify each regression in an isolated copy; never modify the release checkout."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

SOURCE = Path(__file__).resolve().parents[2]
OUT = SOURCE / "audit/evidence/release-reverts"
OUT.mkdir(exist_ok=True)
CASES = [
    ("archive-guard", "R/archive.R", 'fetched$error_code %||% "archive_unavailable"', '"archive_unavailable"', "release-correctness"),
    ("vendor-label-shape", "R/virustotal_cat.R", 'if (!valid) stop("Malformed vendor labels")', 'invisible(valid)', "result-contract"),
    ("vendor-retry", "R/virustotal_cat.R", 'result$retryable[i] <- is_retryable(result$error_code[i])', 'result$error_code[i] <- "service_error"; result$retryable[i] <- TRUE; result$http_status[i] <- NA_integer_', "result-contract"),
    ("retry-input-identity", "R/pie_cat.R", "    pages$input_id <- input_id", "    invisible(input_id)", "result-contract"),
    ("parking", "R/page_signals.R", '  lowered <- tolower(text)\n  if (word_count(lowered)', '  if (grepl("sedo.com", text, fixed = TRUE)) return(TRUE)\n  lowered <- tolower(text)\n  if (word_count(lowered)', "release-correctness"),
    ("archive-resource", "R/collect_content.R", 'recovered <- archive_fetch(url,', 'recovered <- archive_fetch(domain,', "release-correctness"),
    ("cache-shape", "R/page_cache.R", '  if (!valid) {', '  if (FALSE) {', "release-correctness"),
    ("archive-outage", "R/archive.R", '"archive_unavailable"', '"no_archive_snapshot"', "release-correctness"),
    ("robots-outage", "R/robots.R", '"robots_unavailable"', '"robots_blocked"', "release-correctness"),
    ("not-found", "R/collect_content.R", '"http_not_found"', '"http_error"', "release-correctness"),
    ("redirect", "R/collect_content.R", '"redirect_error"', 'NA_character_', "release-correctness"),
    ("robots-cache-expiry", "R/robots.R", 'else min(ttl, 60)', 'else ttl', "release-correctness"),
    ("malformed-archive", "R/archive.R", '"archive_invalid_response"', '"no_archive_snapshot"', "release-correctness"),
    ("fallback-processing", "R/collect_content.R", '      return(archived)', '      if (archived$status == "ok") return(archived)', "release-correctness"),
    ("empty-input", "R/utils.R", '  if (is.null(domains)) {', '  if (!length(domains)) {', "result-contract"),
    ("duplicate-membership", "R/results.R", '    result <- set_result_labels(result, i, label_table(rows[[label]]))', '    result <- set_result_labels(result, i, label_table(head(rows[[label]], 1)))', "result-contract"),
    ("provider-error", "R/llm.R", '    result$error_code[i] <- response$error_code', '    result$error_code[i] <- NA_character_', "result-contract"),
    ("provider-model", "R/llm.R", '    result$model_id[i] <- response$model_id', '    result$model_id[i] <- NA_character_', "result-contract"),
    ("input-identity", "R/results.R", 'input_id = seq_len(n), input = input,', 'input_id = seq_len(n), input = clean_domains(input),', "result-contract"),
    ("download-path", "R/get_dmoz_data.R", 'invisible(output)', 'invisible(NULL)', "result-contract"),
    ("university-empty", "R/uni_cat.R", 'as.character(unlist(data$domains, use.names = FALSE))', 'unlist(data$domains, use.names = FALSE)', "result-contract"),
    ("scoped-model", "R/pie_cat.R", 'withr::local_envvar(c(PIEDOMAINS_TEXT_MODEL = model))', 'Sys.setenv(PIEDOMAINS_TEXT_MODEL = model)', "result-contract"),
]
env = os.environ.copy()
for key in ("OPENAI_API_KEY", "ANTHROPIC_API_KEY", "CLAUDE_API_KEY"):
    env.pop(key, None)
env["NOT_CRAN"] = "false"
with tempfile.TemporaryDirectory(prefix="rdomains-revert-") as directory:
    root = Path(directory) / "rdomains"
    shutil.copytree(SOURCE, root, ignore=shutil.ignore_patterns(".git", "docs", "audit", "*.Rcheck"))
    def run(label, selection):
        command = ["Rscript", "-e", 'testthat::set_max_fails(Inf); devtools::test(filter="' + selection + '", reporter="summary", stop_on_failure=TRUE)']
        result = subprocess.run(command, cwd=root, env=env, capture_output=True, text=True)
        output = "\n".join(line.rstrip() for line in (result.stdout + result.stderr).splitlines())
        (OUT / (label + ".log")).write_text(output + "\n")
        return result.returncode
    assert run("before", "release-correctness|result-contract") == 0
    for label, name, old, new, selection in CASES:
        if len(sys.argv) > 1 and label not in sys.argv[1:]:
            continue
        path = root / name
        original = path.read_text()
        assert old in original, label
        try:
            path.write_text(original.replace(old, new))
            assert run(label, selection) != 0, "Regression survived reversal: " + label
        finally:
            path.write_text(original)
        assert run(label + "-restored", selection) == 0, label
        print(label + ": failed without fix; passed after restoration", flush=True)
