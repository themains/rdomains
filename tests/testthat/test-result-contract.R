test_that("provider outcomes preserve input identity, reason and model", {
  local_mocked_bindings(req_perform = function(...) httr2::response(status_code = 429))
  result <- openai_cat(c("https://example.com/a", "https://example.com/b"),
    api_key = "fixture", delay = 0
  )
  expect_identical(result$input_id, 1:2)
  expect_identical(result$input, c("https://example.com/a", "https://example.com/b"))
  expect_equal(result$error_code, rep("rate_limited", 2))
  expect_true(all(result$retryable))
  expect_equal(result$model_id, rep("gpt-6-luna", 2))
})

test_that("empty inputs are typed results and perform no I/O", {
  local_mocked_bindings(
    req_perform = function(...) stop("unexpected request"),
    fromJSON = function(...) stop("unexpected lookup")
  )
  results <- list(
    openai_cat(character()), claude_cat(character()), virustotal_cat(character()),
    shalla_cat(character()), dmoz_cat(character()), ut1_cat(character()),
    uni_cat(character()), stevenblack_cat(character()), collect_content(character())
  )
  expect_true(all(vapply(results, nrow, integer(1)) == 0L))
  expect_true(all(vapply(results, function(x) is.integer(x$input_id), logical(1))))
})

test_that("lookup memberships are independent of file row order", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("domains,category", "example.com,news", "example.com,shopping"), path)
  a <- suppressWarnings(shalla_cat("example.com", use_file = path))
  writeLines(c("domains,category", "example.com,shopping", "example.com,news"), path)
  b <- suppressWarnings(shalla_cat("example.com", use_file = path))
  expect_identical(a$labels, b$labels)
  expect_equal(a$labels[[1]]$category, c("news", "shopping"))
  expect_true(is.na(a$category))
  expect_equal(a$status, "ok")
})

test_that("VirusTotal keeps a stable schema for missing and multiple vendors", {
  local_mocked_bindings(domain_report = function(domain) {
    if (domain == "a.com") {
      list(data = list(attributes = list(
        categories =
          list(VendorA = "news", VendorB = "business")
      )))
    } else {
      list()
    }
  })
  a <- virustotal_cat("a.com", api_key = "fixture")
  b <- virustotal_cat("b.com", api_key = "fixture")
  expect_identical(names(a), names(b))
  expect_identical(sort(a$labels[[1]]$vendor), c("VendorA", "VendorB"))
  expect_identical(b$status, "no_match")
  expect_identical(nrow(b$labels[[1]]), 0L)
})

test_that("DMOZ downloads return a reusable path", {
  directory <- withr::local_tempdir()
  local_mocked_bindings(
    download_source = function(...) list(source_fetched_at = "2026-10-26T00:00:00Z"),
    unzip = function(zipfile, exdir, ...) {
      writeLines(
        c("domain,cat_labels_en", "example.com,news"),
        file.path(exdir, "dmoz_domain_category.csv")
      )
    }
  )
  path <- get_dmoz_data(outdir = directory)
  expect_identical(path, normalizePath(file.path(directory, "dmoz_domain_category.csv")))
  expect_equal(suppressWarnings(dmoz_cat("example.com", use_file = path))$category, "news")
})

test_that("saved university JSON preserves all university records", {
  path <- withr::local_tempfile(fileext = ".json")
  writeLines('[{"name":"A","domains":["a.edu"]},{"name":"B","domains":["a.edu","b.edu"]}]',
             path)
  result <- uni_cat(c("https://www.a.edu/path", "b.edu", "missing.edu"), use_file = path)
  expect_equal(result$category, c("university", "university", NA_character_))
  expect_equal(result$details[[1]]$records$name, c("A", "B"))
  expect_equal(result$status, c("ok", "ok", "no_match"))
  writeLines('[{"name":"A","domains":[]}]', path)
  expect_equal(uni_cat("a.edu", use_file = path)$status, "no_match")
})

test_that("empty classifiers share the complete typed contract", {
  expected <- classification_result(character(), "fixture", "fixture")
  result <- list(
    pie_cat(character()), openai_cat(character()), claude_cat(character()),
    virustotal_cat(character()), shalla_cat(character()), dmoz_cat(character()),
    ut1_cat(character()), uni_cat(character()), stevenblack_cat(character())
  )
  for (x in result) expect_identical(x, expected)
})

test_that("model overrides are scoped and unused collection arguments are rejected", {
  withr::local_envvar(c(PIEDOMAINS_TEXT_MODEL = "original"))
  pie_cat(character(), model = "override")
  expect_equal(Sys.getenv("PIEDOMAINS_TEXT_MODEL"), "original")
  pages <- collect_content(character())
  expect_error(pie_cat(pages = pages, timeout = 1), class = "rlib_error_dots_nonempty")
  expect_error(pie_cat("example.com", pages = pages), "Supply either")
})
