devtools::load_all()
reticulate::use_python('/tmp/piedomains-audit-20261026/.venv/bin/python', required=TRUE)
reticulate::py_run_string("import os\nfrom types import SimpleNamespace\nfrom piedomains.text import TextClassifier, resolve_text_model\n_rd_loads = []\ndef _rd_load(self, latest=False):\n    if self._model is not None and not latest: return\n    source = resolve_text_model()\n    _rd_loads.append(source)\n    if source == 'fixture/failure': raise RuntimeError('fixture failure')\n    self._model = SimpleNamespace(config=SimpleNamespace(_commit_hash=source))\nTextClassifier.load_models = _rd_load")
env <- reticulate::import('os')$environ
package_env <- getFromNamespace('.rdomains_env', 'rdomains')
count <- 0L
for (p in c(NA_character_, '', 'python-original')) {
  for (r in c(NA_character_, '', 'r-original')) {
    for (m in list(NULL, 'fixture/alpha', 'fixture/failure')) {
      package_env$pie_model <- NULL
      if (is.na(p)) env$pop('PIEDOMAINS_TEXT_MODEL', NULL) else env$`__setitem__`('PIEDOMAINS_TEXT_MODEL', p)
      if (is.na(r)) Sys.unsetenv('PIEDOMAINS_TEXT_MODEL') else Sys.setenv(PIEDOMAINS_TEXT_MODEL=r)
      backend <- tryCatch(rdomains:::pie_backend(m), error=identity)
      stopifnot(identical(Sys.getenv('PIEDOMAINS_TEXT_MODEL', unset=NA_character_), r))
      stopifnot(identical(env$get('PIEDOMAINS_TEXT_MODEL'), if(is.na(p)) NULL else p))
      if (identical(m, 'fixture/failure')) {
        stopifnot(inherits(backend,'error'), is.null(package_env$pie_model))
      } else {
        selected <- if (!is.null(m)) m else if (!is.na(r) && nzchar(r)) r else 'gojiberries/piedomains-text'
        stopifnot(identical(environment(backend)$source, selected))
        stopifnot(identical(environment(backend)$classifier$`_model`$config$`_commit_hash`, selected))
        if (selected == 'gojiberries/piedomains-text') {
          loads <- length(reticulate::py_eval('_rd_loads'))
          again <- rdomains:::pie_backend(m)
          stopifnot(identical(environment(backend)$classifier, environment(again)$classifier))
          stopifnot(length(reticulate::py_eval('_rd_loads')) == loads)
        } else stopifnot(is.null(package_env$pie_model))
      }
      count <- count + 1L
    }
  }
}
cat('PASS:', count, 'environment/model combinations, including unset/empty/divergent states, failed loads, cache reuse and provenance\n')
