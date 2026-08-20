test_that("the error-code taxonomy is closed and well formed", {
  codes <- fetch_error_codes()
  expect_s3_class(codes, "data.frame")
  expect_true(all(c("code", "stage", "retryable", "description") %in% names(codes)))
  expect_false(any(duplicated(codes$code)))
  expect_type(codes$retryable, "logical")
  expect_false(any(is.na(codes$retryable)))
  # Every stage named is a real pipeline stage (NA allowed for `unknown`).
  expect_true(all(stats::na.omit(codes$stage) %in% RD_STAGES))
})

test_that("the codes match piedomains verbatim", {
  # These strings are a shared public contract across the two packages. Changing one
  # silently breaks aggregation across them.
  codes <- fetch_error_codes()$code
  shared <- c(
    "invalid_domain", "dns_error", "connection_error", "timeout",
    "http_error", "robots_blocked", "content_type_rejected",
    "content_too_large", "empty_text", "bot_blocked", "thin_content",
    "unknown"
  )
  expect_true(all(shared %in% codes))
})

test_that("bot_blocked is not retryable here, unlike piedomains", {
  # piedomains retries it because it has an archive.org fallback to retry *into*.
  # rdomains has none, so a retry from the same address is rudeness with a guaranteed
  # identical outcome.
  expect_false(is_retryable("bot_blocked"))
  expect_true(is_retryable("timeout"))
  expect_true(is_retryable("dns_error"))
  expect_false(is_retryable("thin_content"))
  expect_false(is_retryable(NA))
})

test_that("fetch_report counts by stage and reason", {
  rows <- tibble::tibble(
    domain_name = c("a.com", "b.com", "c.com", "d.com"),
    status = c("ok", "failed", "failed", "failed"),
    stage = c("infer", "fetch", "fetch", "process"),
    error_code = c(NA, "timeout", "timeout", "thin_content"),
    retryable = c(FALSE, TRUE, TRUE, FALSE)
  )
  rep <- fetch_report(rows)
  expect_equal(rep$n, 4)
  expect_equal(rep$ok, 1)
  expect_equal(rep$failed, 3)
  expect_equal(rep$retryable, 2)
  expect_equal(rep$by_reason[[1]]$value[1], "timeout")
  expect_equal(rep$by_reason[[1]]$n[1], 2)
  expect_setequal(rep$missing[[1]], c("b.com", "c.com", "d.com"))
})

test_that("fetch_report is a pure function, so it survives filtering", {
  # This is why the report is recomputed rather than stored: a stored summary goes
  # stale the moment the rows are subset.
  rows <- tibble::tibble(
    domain_name = c("a.com", "b.com"),
    status = c("ok", "failed"),
    stage = c("infer", "fetch"),
    error_code = c(NA, "timeout"),
    retryable = c(FALSE, TRUE)
  )
  expect_equal(fetch_report(rows[rows$status == "failed", ])$n, 1)
  expect_equal(fetch_report(rows[rows$status == "failed", ])$failed, 1)
})

test_that("fetch_report rejects something that is not a run", {
  expect_error(fetch_report("nope"), "must be a data frame")
  expect_error(fetch_report(tibble::tibble(a = 1)), "missing column")
})
