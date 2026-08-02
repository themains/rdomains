test_that("private and special addresses are never fetchable", {
  # Rejecting these is what stops a domain lookup from becoming a probe of the caller's
  # own network. 169.254.169.254 is the cloud metadata endpoint.
  for (ip in c("127.0.0.1", "10.1.2.3", "192.168.1.1", "169.254.169.254",
               "172.16.0.1", "100.64.0.1", "0.0.0.0", "224.0.0.1",
               "::1", "fe80::1", "fc00::1")) {
    expect_false(is_global_ip(ip), info = ip)
  }
  for (ip in c("8.8.8.8", "1.1.1.1", "93.184.216.34", "2001:4860:4860::8888")) {
    expect_true(is_global_ip(ip), info = ip)
  }
})

test_that("IPv4-mapped IPv6 is unwrapped before the check", {
  # The step people forget, and forgetting it re-opens the whole hole.
  expect_false(is_global_ip("::ffff:10.0.0.1"))
  expect_false(is_global_ip("::ffff:127.0.0.1"))
  expect_true(is_global_ip("::ffff:8.8.8.8"))
})

test_that("is_global_ip rejects garbage rather than defaulting to allow", {
  expect_false(is_global_ip(NA_character_))
  expect_false(is_global_ip(""))
  expect_false(is_global_ip("not-an-ip"))
  expect_false(is_global_ip("999.1.1.1"))
})

test_that("check_url refuses what should never be fetched", {
  # DNS is injected so this never touches the network.
  global <- function(host, error = FALSE) "8.8.8.8"
  private <- function(host, error = FALSE) "10.0.0.1"

  expect_null(check_url("https://example.com", resolver = global))
  expect_equal(check_url("https://example.com", resolver = private), "private_address")
  expect_equal(check_url("ftp://example.com", resolver = global), "invalid_domain")
  expect_equal(check_url("https://1.2.3.4", resolver = global), "invalid_domain")
  expect_equal(check_url("https://secret.onion", resolver = global), "invalid_domain")
  expect_equal(check_url("https://localhost", resolver = global), "invalid_domain")
  expect_equal(check_url("https://box.local", resolver = global), "invalid_domain")
  expect_equal(
    check_url("https://example.com", resolver = function(host, error = FALSE) NULL),
    "dns_error"
  )
})

test_that("conditions map to stable codes by class, not message text", {
  expect_equal(classify_condition(simpleError("Timeout was reached")), "timeout")
  expect_equal(classify_condition(simpleError("Could not resolve host")), "dns_error")
  expect_equal(classify_condition(simpleError("Connection refused")), "connection_error")
  expect_equal(classify_condition(simpleError("something odd")), "unknown")
})

test_that("robots.txt parsing follows RFC 9309", {
  txt <- paste(
    "User-agent: *", "Disallow: /private", "Allow: /private/public",
    "Crawl-delay: 2", "", "User-agent: badbot", "Disallow: /", sep = "\n"
  )
  p <- parse_robots(txt, "rdomains")
  expect_equal(p$crawl_delay, 2)
  expect_true(robots_path_allowed(p$rules, "/"))
  expect_false(robots_path_allowed(p$rules, "/private"))
  # Longest match wins, so the more specific Allow beats the shorter Disallow.
  expect_true(robots_path_allowed(p$rules, "/private/public"))
  expect_false(robots_path_allowed(p$rules, "/private/secret"))

  # A group naming us specifically beats the wildcard group.
  expect_false(robots_path_allowed(parse_robots(txt, "badbot")$rules, "/"))
})

test_that("robots wildcards and end-anchors work", {
  p <- parse_robots("User-agent: *\nDisallow: /*.pdf$\nDisallow: /tmp/")
  expect_false(robots_path_allowed(p$rules, "/a.pdf"))
  expect_true(robots_path_allowed(p$rules, "/a.pdf?x=1"))  # $ anchors the end
  expect_false(robots_path_allowed(p$rules, "/tmp/x"))
  expect_true(robots_path_allowed(p$rules, "/ok.html"))
})

test_that("an empty Disallow allows everything", {
  p <- parse_robots("User-agent: *\nDisallow:")
  expect_true(robots_path_allowed(p$rules, "/anything"))
})

test_that("comments and CRLF do not break parsing", {
  p <- parse_robots("# a comment\r\nUser-agent: *\r\nDisallow: /x  # trailing\r\n")
  expect_false(robots_path_allowed(p$rules, "/x"))
})

test_that("the user agent identifies the package and offers a contact", {
  ua <- rdomains_user_agent()
  expect_match(ua, "^rdomains/")
  expect_match(ua, "github.com/themains/rdomains", fixed = TRUE)
  # Never impersonate a browser: it is dishonest and it does not even work against bot
  # walls, which fingerprint TLS rather than the UA string.
  expect_false(grepl("Mozilla|Chrome|Safari", ua))
})

test_that("collect_content validates its input before touching the network", {
  expect_error(collect_content(NULL), "must not be NULL")
  expect_error(collect_content(""), "contains empty strings")
  expect_error(collect_content(123), "character")
})

test_that("collect_content returns a row per input, even for unfetchable ones", {
  skip_on_cran()
  skip_if_offline()

  res <- collect_content(
    c("example.com", "no-such-domain-xyzzy-99999.invalid"),
    obey_robots = FALSE
  )
  expect_equal(nrow(res), 2)
  expect_equal(res$domain_name, c("example.com", "no-such-domain-xyzzy-99999.invalid"))
  expect_equal(res$error_code[2], "dns_error")
  expect_true(res$retryable[2])
  # Every row carries its own provenance, whatever happened.
  expect_false(any(is.na(res$fetched_at)))
  expect_false(any(is.na(res$source_last_published)))
})

test_that("http_status holds the HTTP code, not the row status", {
  # Regression: tibble() evaluates arguments sequentially, so a `status` column shadowed
  # the local variable holding the HTTP code and http_status silently became "ok"/"failed".
  skip_on_cran()
  skip_if_offline()

  res <- collect_content("example.com", obey_robots = FALSE)
  expect_type(res$http_status, "integer")
  expect_equal(res$http_status[1], 200L)
})

test_that("every row has the same schema and types, whatever happened", {
  # The typing guarantee. R has no static types, so one constructor pins the schema --
  # two separate tibble() calls drift, and when they do bind_rows() either fails far from
  # the cause or silently coerces. This is what caught http_status becoming a character.
  started <- Sys.time()
  ok <- fetch_row(
    "a.com", "a.com", started, status = "ok", stage = "process",
    http_status = 200L, final_url = "https://a.com", content_bytes = 100L,
    parsed = list(title = "T", description = NA_character_, lang = "en", text = "words"),
    signals = list(n_tokens = 5L, page_state = "content", block_vendor = NA_character_),
    robots_allowed = TRUE
  )
  failed <- fetch_row("b.com", "b.com", started, error_code = "dns_error")

  expect_identical(names(ok), names(failed))
  expect_identical(
    vapply(ok, function(x) class(x)[1], character(1)),
    vapply(failed, function(x) class(x)[1], character(1))
  )
  expect_type(ok$http_status, "integer")
  expect_type(ok$retryable, "logical")
  # bind_rows must not error, which is the whole point.
  expect_no_error(dplyr::bind_rows(ok, failed))
})

test_that("retryable is derived from the code, never set by hand", {
  started <- Sys.time()
  expect_true(fetch_row("a.com", "a.com", started, error_code = "timeout")$retryable)
  expect_false(fetch_row("a.com", "a.com", started, error_code = "bot_blocked")$retryable)
  expect_false(fetch_row("a.com", "a.com", started, status = "ok")$retryable)
})
