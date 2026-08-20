test_that("stevenblack_cat returns expected data structure", {
  # Test with minimal mock data
  mock_hosts <- c(
    "# This is a test hosts file",
    "127.0.0.1 localhost",
    "0.0.0.0 doubleclick.net",
    "0.0.0.0 googleadservices.com",
    "127.0.0.1 malware-example.com"
  )

  # Create temporary hosts file
  temp_hosts <- tempfile(fileext = ".txt")
  writeLines(mock_hosts, temp_hosts)

  # Test function
  result <- stevenblack_cat(c("google.com", "doubleclick.net"), use_file = temp_hosts)

  # Clean up
  unlink(temp_hosts)

  # Check structure. The third column is the vintage of the list that produced the
  # category -- see source_vintage(). For this list it is the file's own date, because
  # Steven Black's hosts file is actively maintained.
  expect_s3_class(result, "data.frame")
  expect_equal(ncol(result), 3)
  expect_equal(names(result), c("domain", "stevenblack", "source_last_published"))
  expect_equal(nrow(result), 2)

  # Check classifications
  expect_equal(result$stevenblack[1], "safe") # google.com not in blocklist
  expect_equal(result$stevenblack[2], "ads") # doubleclick.net classified as ads
})

test_that("stevenblack_cat handles domain cleaning", {
  mock_hosts <- c("0.0.0.0 example.com")
  temp_hosts <- tempfile(fileext = ".txt")
  writeLines(mock_hosts, temp_hosts)

  # Test with various domain formats
  domains <- c(
    "http://example.com",
    "https://www.example.com",
    "example.com/path"
  )

  result <- stevenblack_cat(domains, use_file = temp_hosts)
  unlink(temp_hosts)

  # All should be classified as blocked since they resolve to example.com
  expect_equal(sum(result$stevenblack == "blocked"), 3)
})

test_that("stevenblack_cat handles errors appropriately", {
  # Test with non-existent file
  expect_error(
    stevenblack_cat("test.com", use_file = "nonexistent.txt"),
    "File does not exist"
  )

  # Test with no domain
  expect_error(
    stevenblack_cat(NULL),
    "must not be NULL"
  )
})

test_that("get_stevenblack_data creates file", {
  skip_if_offline()

  temp_dir <- tempdir()

  # Test download (this might be slow, so we'll skip on CRAN)
  skip_on_cran()

  # Download base variant
  result_file <- get_stevenblack_data(outdir = temp_dir, variant = "base", overwrite = TRUE)

  expect_true(file.exists(result_file))
  expect_true(file.size(result_file) > 1000) # Should be a substantial file

  # Clean up
  unlink(result_file)
})

test_that("get_stevenblack_data validates variants", {
  expect_error(
    get_stevenblack_data(variant = "invalid"),
    "Invalid variant"
  )
})

test_that("get_stevenblack_data respects overwrite parameter", {
  temp_dir <- tempdir()
  test_file <- file.path(temp_dir, "stevenblack_hosts_base.txt")

  # Create a dummy file
  writeLines("test", test_file)

  # Should error without overwrite
  expect_error(
    get_stevenblack_data(outdir = temp_dir, overwrite = FALSE),
    "File already exists"
  )

  # Clean up
  unlink(test_file)
})
# The category is derived from keywords in the domain name, and "ad" is a substring of
# "trade", "download", "gadget", "espadrilles" and "nokiadns". Against the live list
# (99,278 blocked hosts) an unanchored "ad" labels 13,423 hosts "ads", of which 10,581
# (78.8%) contain no ad token at all.
test_that("the ads label needs an ad token, not an inner substring", {
  mock_hosts <- c(
    "0.0.0.0 downloaduj.pl",
    "0.0.0.0 gadgetproof.net",
    "0.0.0.0 cryptonova84trade.com",
    "0.0.0.0 doubleclick.net",
    "0.0.0.0 ad.example.com",
    "0.0.0.0 ads-server.net"
  )
  temp_hosts <- tempfile(fileext = ".txt")
  writeLines(mock_hosts, temp_hosts)
  on.exit(unlink(temp_hosts), add = TRUE)

  res <- stevenblack_cat(
    c(
      "downloaduj.pl", "gadgetproof.net", "cryptonova84trade.com",
      "doubleclick.net", "ad.example.com", "ads-server.net"
    ),
    use_file = temp_hosts
  )

  expect_equal(
    res$stevenblack,
    c("blocked", "blocked", "blocked", "ads", "ads", "ads")
  )
})

test_that("blocklist lookup is case-insensitive, as DNS is", {
  temp_hosts <- tempfile(fileext = ".txt")
  writeLines("0.0.0.0 doubleclick.net", temp_hosts)
  on.exit(unlink(temp_hosts), add = TRUE)
  expect_equal(
    stevenblack_cat("DoubleClick.NET", use_file = temp_hosts)$stevenblack,
    "ads"
  )
})

# The list blocks hosts as written, and 34,151 of the live list's 99,278 entries carry a
# "www." that clean_domains() strips; 1,870 of those have no bare counterpart. Looking up
# only the bare form reports a blocked host as safe -- the harmful direction for a
# blocklist.
test_that("a host blocked only in its www. form is not reported safe", {
  temp_hosts <- tempfile(fileext = ".txt")
  writeLines(c("0.0.0.0 www.ads.example.com", "0.0.0.0 bare-example.net"), temp_hosts)
  on.exit(unlink(temp_hosts), add = TRUE)

  res <- stevenblack_cat(
    c("www.ads.example.com", "ads.example.com", "bare-example.net", "not-listed.org"),
    use_file = temp_hosts
  )
  expect_equal(res$stevenblack, c("ads", "ads", "blocked", "safe"))
})
