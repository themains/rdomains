# The negative controls are the point of this file.
#
# piedomains' blocking.py records the cases that cost it real classifications: reddit,
# walmart, tinyurl and quora all serve real pages while embedding reCAPTCHA, PerimeterX or
# a Cloudflare Turnstile widget; bankofamerica.com (491 tokens) matched an earlier looser
# denial pattern; a 319-word breeder site says puppies are "coming soon"; a real shop
# legitimately says "for sale".
#
# Porting the tiers without porting the counterexamples would port the bug back in.

long_page <- function(words, ...) {
  paste0(
    "<html><title>", ..1 %||% "A Real Site", "</title><body>",
    paste(rep("genuine page content about the subject", ceiling(words / 6)),
          collapse = " "),
    "</body></html>"
  )
}
`%||%` <- function(x, y) if (is.null(x)) y else x

test_that("strong anti-bot markers are detected", {
  expect_equal(page_signals("<html><body>captcha-delivery.com</body></html>")$block_vendor,
               "datadome")
  expect_equal(page_signals("<html><body>cf_chl_opt</body></html>")$block_vendor,
               "cloudflare")
  expect_equal(page_signals("<html><body>Incapsula incident ID 123</body></html>")$block_vendor,
               "imperva")
  expect_true(page_signals("<html><body>Reference #18.abc</body></html>")$blocked)
})

test_that("a challenge title is itself the tell", {
  s <- page_signals("<html><title>Just a moment...</title><body>challenges.cloudflare.com</body></html>")
  expect_true(s$blocked)
  expect_equal(s$page_state, "blocked")
})

test_that("a healthy page embedding reCAPTCHA is NOT blocked", {
  # reddit, walmart, tinyurl and quora all do this. Treating it as a block silently
  # discards good classifications.
  html <- paste0(
    "<html><title>Reddit - Dive into anything</title><body>",
    paste(rep("real discussion thread content here", 200), collapse = " "),
    "<script src='https://www.google.com/recaptcha/api.js'></script></body></html>"
  )
  s <- page_signals(html, domain = "reddit.com")
  expect_false(s$blocked)
  expect_equal(s$page_state, "content")
})

test_that("a long page mentioning access denial in legal copy is NOT blocked", {
  # bankofamerica.com, 491 tokens, matched an earlier looser pattern.
  html <- paste0(
    "<html><title>Bank of America</title><body>",
    paste(rep("banking services and account information", 150), collapse = " "),
    " You do not have permission to access certain areas without signing in. ",
    paste(rep("more legitimate banking copy", 150), collapse = " "),
    "<script src='recaptcha/api.js'></script></body></html>"
  )
  expect_false(page_signals(html, domain = "bankofamerica.com")$blocked)
})

test_that("parking pages are detected", {
  expect_true(page_signals("<html><body>This domain is for sale.</body></html>")$parked)
  expect_true(page_signals("<html><body>Buy this domain today</body></html>")$parked)
  # The one the first version missed: orderwith.com said "available for sale".
  expect_true(page_signals("<html><body>This name is available for sale</body></html>")$parked)
  # A parking service name is enough on its own, at any length.
  expect_true(page_signals("<html><body>Hosted by sedo.com</body></html>")$parked)
})

test_that("a real shop saying 'for sale' is NOT parked", {
  html <- paste0(
    "<html><title>Bike Shop</title><body>",
    "Our bikes are for sale in store and online. ",
    paste(rep("browse our range of road and mountain bicycles", 80), collapse = " "),
    "</body></html>"
  )
  s <- page_signals(html)
  expect_false(s$parked)
  expect_equal(s$page_state, "content")
})

test_that("empty placeholders are detected", {
  expect_true(page_signals("<html><body>Index of /</body></html>")$unavailable)
  expect_true(page_signals("<html><body>Welcome to nginx!</body></html>")$unavailable)
  expect_true(page_signals("<html><body>Account Suspended</body></html>")$unavailable)
  expect_true(page_signals("<html><body>Diese Seite ist noch im Aufbau</body></html>")$unavailable)
})

test_that("a real site saying 'coming soon' in passing is NOT unavailable", {
  # A 319-word breeder site saying puppies are coming soon; sampled at 100 words the
  # rule still swept in a riding school, which is why the floor is 60.
  html <- paste0(
    "<html><title>Kennel</title><body>",
    paste(rep("we breed labradors and show them at events", 60), collapse = " "),
    " New puppies coming soon. ",
    paste(rep("contact us to arrange a visit to the kennel", 40), collapse = " "),
    "</body></html>"
  )
  expect_false(page_signals(html)$unavailable)
})

test_that("thin pages are flagged but distinguished from blocked", {
  s <- page_signals("<html><body>Hello there friend</body></html>")
  expect_true(s$thin)
  expect_false(s$blocked)
  expect_equal(s$page_state, "thin")
})

test_that("page_state prefers blocked over parked over unavailable over thin", {
  both <- page_signals("<html><body>cf_chl_opt this domain is for sale</body></html>")
  expect_equal(both$page_state, "blocked")
})

test_that("page_signals returns one row with the documented columns", {
  s <- page_signals("<html><body>hello</body></html>")
  expect_equal(nrow(s), 1)
  expect_true(all(c("page_state", "blocked", "block_vendor", "parked",
                    "unavailable", "thin", "n_tokens") %in% names(s)))
})

# "dan.com" is a substring of "jordan.com", "sedo.com" of "cassedo.com". The registrar
# list is checked before the length guard, so an unanchored match relabels an arbitrarily
# long real page as a placeholder.
test_that("a real page that merely names a registrar is not parked", {
  html <- paste0(
    "<html><title>Air Jordan</title><body>",
    paste(rep("michael jordan sneaker history and release notes", 80),
          collapse = " "),
    " visit jordan.com for the official store</body></html>"
  )
  s <- page_signals(html)
  expect_false(s$parked)
  expect_equal(s$page_state, "content")
})

test_that("an actual registrar landing page is still parked", {
  s <- page_signals("<html><body>This domain is listed for sale at dan.com</body></html>")
  expect_true(s$parked)
  expect_equal(s$page_state, "parked")

  s2 <- page_signals("<html><body>Offered by www.hugedomains.com</body></html>")
  expect_true(s2$parked)
})
