test_that("source provenance survives only with the matching data file", {
  path <- withr::local_tempfile()
  writeLines("data", path)
  meta <- list(source_last_published = "2026-10-01", source_fetched_at = "2026-10-26T12:00:00Z")
  save_source_metadata(path, meta)
  expect_equal(load_source_metadata(path)[names(meta)], meta)
  Sys.setFileTime(path, as.POSIXct("2000-01-01", tz = "UTC"))
  expect_equal(load_source_metadata(path)[names(meta)], meta)
  writeLines("different data", path)
  expect_true(all(is.na(unlist(load_source_metadata(path)))))
  for (invalid in c("{broken", "1", "[]", "null")) {
    writeLines(invalid, paste0(path, ".metadata.json"))
    expect_true(all(is.na(unlist(load_source_metadata(path)))))
  }
})

test_that("downloads distinguish server publication date from retrieval time", {
  path <- withr::local_tempfile()
  for (modified in c("Wed, 01 Oct 2025 12:00:00 GMT", "unknown", "")) {
    local_mocked_bindings(req_perform = function(req, path) {
      writeLines("downloaded", path)
      headers <- if (nzchar(modified)) list(`last-modified` = modified) else list()
      httr2::response(status_code = 200, headers = headers)
    })
    meta <- download_source("https://example.com/data", path)
    expect_equal(readLines(path), "downloaded")
    expect_equal(
      meta$source_last_published,
      if (startsWith(modified, "Wed")) "2025-10-01" else NA_character_
    )
    expect_match(meta$source_fetched_at, "^[0-9-]+T[0-9:]+Z$")
  }
})

test_that("UT1 extraction resolves duplicates deterministically and records provenance", {
  source <- withr::local_tempdir()
  destination <- withr::local_tempdir()
  lists <- list(
    alpha = "shared.com", zeta = "shared.com",
    broad = c("shared.com", "elsewhere.com"), liste_bu = "ignored.com"
  )
  for (name in names(lists)) {
    dir.create(file.path(source, name))
    writeLines(lists[[name]], file.path(source, name, "domains"))
    writeLines(character(), file.path(source, name, "usage"))
  }
  archive <- withr::local_tempfile(fileext = ".tar.gz")
  withr::with_dir(source, utils::tar(archive, files = names(lists), compression = "gzip"))
  local_mocked_bindings(download_source = function(url, path) {
    file.copy(archive, path)
    list(source_last_published = "2026-10-25", source_fetched_at = "2026-10-26T12:00:00Z")
  })
  suppressMessages(get_ut1_data(destination))
  result <- ut1_cat(
    c("shared.com", "elsewhere.com", "ignored.com"),
    file.path(destination, "ut1_domain_category.csv")
  )
  expect_equal(result$category, c(NA_character_, "broad", NA_character_))
  expect_equal(result$labels[[1]]$category, c("alpha", "broad", "zeta"))
  expect_true(all(is.na(result$details[[1]]$records$usage)))
  expect_equal(result$source_last_published, rep("2026-10-25", 3))
})
