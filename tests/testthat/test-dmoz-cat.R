test_that("dmoz cat", {
  # Downloads an 80 MB archive: CRAN forbids that, and it fails offline.
  skip_on_cran()
  skip_if_offline()

  # Use temporary directory to avoid leaving large files
  temp_dir <- tempdir()
  get_dmoz_data(outdir = temp_dir, overwrite = TRUE)

  # Test with the downloaded data
  data_file <- file.path(temp_dir, "dmoz_domain_category.csv")
  reset_vintage_warnings()
  expect_warning(
    report <- dmoz_cat("http://www.google.com", use_file = data_file),
    "no longer published"
  )

  expect_s3_class(report, "data.frame")
  expect_equal(report$source_last_published, "2017-03")

  # Clean up
  if (file.exists(data_file)) {
    unlink(data_file)
  }
})

test_that("get_dmoz_data writes to outdir, not a hidden file beside it", {
  # paste0(outdir, "name") produced ".dmoz_domain_category.csv" for the documented
  # default outdir = ".", which dmoz_cat() would then fail to find.
  temp_dir <- tempdir()
  expected <- file.path(temp_dir, "dmoz_domain_category.csv")
  writeLines("example.com,Shopping", expected)
  on.exit(unlink(expected), add = TRUE)

  # With the path built correctly, the existing-file guard fires.
  expect_error(
    get_dmoz_data(outdir = temp_dir, overwrite = FALSE),
    "already exists"
  )
})

# --- Lookup keys -------------------------------------------------------------
#
# The shipped table is keyed on the hostname as DMOZ recorded it, and 2,089,407 of its
# 2,488,259 rows (84.0%) begin with "www.". 2,089,331 of those have no bare counterpart
# anywhere in the file, so stripping "www." from the input and matching only that form
# makes 84% of the table unreachable by any input at all.

dmoz_fixture <- function() {
  f <- tempfile(fileext = ".csv")
  writeLines(
    c(
      '"domain","cat_labels_en"',
      '"www.232analyzer.com","Top/Computers/Hardware/Test_Equipment/Analyzers"',
      '"sdcastroverde.com","Top/World/Galego/regional/Galicia/Lugo"'
    ),
    f
  )
  f
}

test_that("a www-prefixed table entry is reachable", {
  f <- dmoz_fixture()
  on.exit(unlink(f), add = TRUE)
  reset_vintage_warnings()
  expected <- "Top/Computers/Hardware/Test_Equipment/Analyzers"

  # Both spellings name the same host, so both must find the same row.
  expect_equal(
    suppressWarnings(dmoz_cat("http://www.232analyzer.com", use_file = f))$dmoz_category,
    expected
  )
  expect_equal(
    suppressWarnings(dmoz_cat("232analyzer.com", use_file = f))$dmoz_category,
    expected
  )
})

test_that("a bare table entry is still reachable", {
  f <- dmoz_fixture()
  on.exit(unlink(f), add = TRUE)
  reset_vintage_warnings()
  expect_equal(
    suppressWarnings(dmoz_cat("sdcastroverde.com", use_file = f))$dmoz_category,
    "Top/World/Galego/regional/Galicia/Lugo"
  )
})

test_that("the file's header row is not a lookup key", {
  f <- dmoz_fixture()
  on.exit(unlink(f), add = TRUE)
  reset_vintage_warnings()
  expect_true(is.na(suppressWarnings(dmoz_cat("domain", use_file = f))$dmoz_category))
})

test_that("host lookup is case-insensitive, as DNS is", {
  f <- dmoz_fixture()
  on.exit(unlink(f), add = TRUE)
  reset_vintage_warnings()
  expect_equal(
    suppressWarnings(dmoz_cat("SDCastroVerde.COM", use_file = f))$dmoz_category,
    "Top/World/Galego/regional/Galicia/Lugo"
  )
  expect_equal(
    suppressWarnings(dmoz_cat("HTTP://WWW.232Analyzer.com", use_file = f))$dmoz_category,
    "Top/Computers/Hardware/Test_Equipment/Analyzers"
  )
})
