Sys.unsetenv(c('OPENAI_API_KEY', 'ANTHROPIC_API_KEY', 'CLAUDE_API_KEY'))
devtools::load_all('/Users/soodoku/Documents/GitHub/themains/rdomains', quiet = TRUE)
ns <- asNamespace('rdomains')
run <- function(name, code) {
  cat('\nPROBE:', name, '\n')
  tryCatch(print(force(code)), error=function(e) cat('ERROR:', conditionMessage(e), '\n'))
}
html <- paste0('<html><body>', paste(rep('Independent reporting about markets and technology.', 50), collapse=' '), '</body></html>')
run('legitimate long article mentions parking marketplace', page_signals(paste0('<html><body>', paste(rep('Independent reporting about markets and technology.', 50), collapse=' '), ' Our investigation covers sedo.com and other domain marketplaces.</body></html>')))
run('empty retry selection', collect_content(character()))
run('HTTP failure retry policy', ns$is_retryable('http_error'))
run('cache valid JSON with invalid HTTP-status shape aborts collection', {
  cache <- tempfile(); dir.create(cache)
  ns$cache_put(cache, 'https://example.com/article', html,
    list(fetched_at=format(Sys.time(), '%Y-%m-%dT%H:%M:%SZ', tz='UTC'), http_status=c(200L,201L), final_url='https://example.com/article', content_bytes=nchar(html), status='ok', stage='process'), max_size=1e7)
  tryCatch(collect_content(c('https://example.com/article','https://example.org/'), cache_dir=cache), finally=unlink(cache, recursive=TRUE))
})
run('archive receives hostname instead of requested page', local({
  called <- NULL
  testthat::local_mocked_bindings(archive_fetch=function(domain, ...) {called <<- domain; NULL}, .package='rdomains')
  result <- collect_content('https://example.com/News/story?id=7', archive_date='20200101')
  list(requested=result$input, archive_argument=called, error_code=result$error_code)
}))
run('HTTP 302 with content but no Location becomes success', local({
  response <- httr2::response(status_code=302, headers=list('content-type'='text/html'), body=charToRaw(html), url='https://example.com/a')
  testthat::local_mocked_bindings(guarded_get=function(...) list(response=response, robots_allowed=TRUE), .package='rdomains')
  result <- collect_content('https://example.com/a', cache_dir=tempfile(), archive_fallback=FALSE)
  result[c('http_status','status','error_code','retryable')]
}))
run('HTTP 404 is retryable', local({
  response <- httr2::response(status_code=404, headers=list('content-type'='text/html'), body=charToRaw(html), url='https://example.com/a')
  testthat::local_mocked_bindings(guarded_get=function(...) list(response=response, robots_allowed=TRUE), .package='rdomains')
  result <- collect_content('https://example.com/a', cache_dir=tempfile(), archive_fallback=FALSE)
  result[c('http_status','status','error_code','retryable')]
}))
run('unavailable archive and empty archive are indistinguishable', local({
  result <- lapply(c(503L,200L), function(status) {
    response <- httr2::response(status_code=status, headers=list('content-type'='application/json'), body=charToRaw('[]'))
    testthat::local_mocked_bindings(req_perform=function(...) response, .package='rdomains')
    x <- collect_content('example.com', archive_date='20200101')
    data.frame(archive_http_status=status, x[c('status','error_code','retryable')])
  })
  dplyr::bind_rows(result)
}))
run('download helper composability', local({
  directory <- tempfile(); dir.create(directory)
  on.exit(unlink(directory,recursive=TRUE))
  testthat::local_mocked_bindings(
    download_source=function(...) list(source_fetched_at='2026-10-26T00:00:00Z'),
    unzip=function(zipfile,exdir,...) writeLines(c('domain,cat_labels_en','example.com,news'), file.path(exdir,'dmoz_domain_category.csv')),
    .package='rdomains')
  path <- get_dmoz_data(outdir=directory)
  list(returned=path, file_exists=file.exists(file.path(directory,'dmoz_domain_category.csv')))
}))
run('lookup custom file silently picks first duplicate', local({
  path <- tempfile(fileext='.csv'); on.exit(unlink(path))
  writeLines(c('domains,category','example.com,news','example.com,shopping'),path)
  a <- suppressWarnings(shalla_cat('example.com',use_file=path))$shalla_category
  writeLines(c('domains,category','example.com,shopping','example.com,news'),path)
  b <- suppressWarnings(shalla_cat('example.com',use_file=path))$shalla_category
  list(forward=a, reverse=b)
}))
run('API error outcome loses reason and selected model', local({
  testthat::local_mocked_bindings(req_perform=function(...) httr2::response(status_code=429), .package='rdomains')
  suppressWarnings(openai_cat('example.com',api_key='fixture',rate_limit=0))
}))
run('VirusTotal schema changes with returned vendor', local({
  testthat::local_mocked_bindings(domain_report=function(domain) if(domain=='a.com') list(data=list(attributes=list(categories=list(VendorA='news')))) else list(), .package='rdomains')
  list(with_category=names(virustotal_cat('a.com',api_key='fixture')), without_category=names(virustotal_cat('b.com',api_key='fixture')))
}))
run('parking false positive bypasses model and becomes successful label', local({
  article <- paste0('<html><body>', paste(rep('Independent reporting about markets and technology.', 50), collapse=' '), ' Our investigation covers sedo.com and other domain marketplaces.</body></html>')
  signals <- page_signals(article)
  pages <- ns$fetch_row('news.example','https://news.example/article',Sys.time(),status='ok',stage='process',html=article,parsed=html_text_content(article),signals=signals)
  testthat::local_mocked_bindings(pie_backend=function() stop('model should not be reached'), .package='rdomains')
  pie_cat(pages=pages)[c('status','pie_category','label_source','pie_confidence')]
}))
run('robots timeout becomes nonretryable denial', local({
  testthat::local_mocked_bindings(
    check_url=function(...) NULL,
    req_perform=function(...) stop('operation timed out'),
    .package='rdomains')
  collect_content('https://robots-unavailable.example/a',cache_dir=tempfile(),archive_fallback=FALSE)[c('status','error_code','retryable','http_status')]
}))
run('R/Python shared outcome policy has diverged', local({
  text <- readLines('/tmp/piedomains-audit-20261026/src/piedomains/outcomes.py')
  block <- text[(match('class ErrorCode(StrEnum):',text)+1):(match('RETRYABLE: frozenset[ErrorCode] = frozenset(',text)-1)]
  python_codes <- sub('^.*= "([a-z_]+)".*$', '\\1',grep('^    [A-Z_]+ = "',block,value=TRUE))
  r_codes <- fetch_error_codes()$code
  list(python_only=setdiff(python_codes,r_codes), R_only=setdiff(r_codes,python_codes), R_bot_blocked_retryable=ns$is_retryable('bot_blocked'), Python_bot_blocked_retryable=TRUE)
}))
run('public function formals', local({
  exports <- sort(getNamespaceExports('rdomains'))
  for (name in exports) {
    value <- get(name,ns)
    if (is.function(value)) cat(name, ': ',paste(names(formals(value)),collapse=', '),'\n',sep='')
  }
  invisible(NULL)
}))
