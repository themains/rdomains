test_that("script, style and comments are removed", {
  html <- "<html><body><p>real content here</p>
    <script>var x = 'javascript noise';</script>
    <style>.cls { color: red; }</style>
    <!-- a build comment --></body></html>"
  got <- html_text_content(html)$text
  expect_true(grepl("real content here", got, fixed = TRUE))
  expect_false(grepl("javascript noise", got, fixed = TRUE))
  expect_false(grepl("color", got, fixed = TRUE))
  expect_false(grepl("build comment", got, fixed = TRUE))
})

test_that("whitespace is collapsed and text lowercased, and nothing else", {
  # Mirrors piedomains' clean_and_normalize_text as of 0.12.0.
  got <- html_text_content("<html><body>Hello   \n\t  WORLD</body></html>")$text
  expect_equal(got, "hello world")
})

test_that("punctuation is kept, deliberately", {
  # Dropping table pipes and layout dashes looked obviously right and measured worse:
  # held-out macro-F1 0.7267 -> 0.7134. Do not "fix" this without retraining.
  got <- html_text_content("<html><body>Price: $10 | In stock -- yes!</body></html>")$text
  expect_true(grepl("|", got, fixed = TRUE))
  expect_true(grepl("--", got, fixed = TRUE))
  expect_true(grepl("$10", got, fixed = TRUE))
})

test_that("words are not deduplicated or sorted", {
  # The pre-0.12.0 cleaner did both. A transformer wants sentences.
  got <- html_text_content("<html><body>zebra apple zebra</body></html>")$text
  expect_equal(got, "zebra apple zebra")
})

test_that("title, description and lang are extracted", {
  html <- "<html lang='de'><head><title>Beispiel</title>
    <meta name='description' content='Eine Seite'></head><body>text</body></html>"
  got <- html_text_content(html)
  expect_equal(got$title, "Beispiel")
  expect_equal(got$description, "Eine Seite")
  expect_equal(got$lang, "de")
})

test_that("missing metadata comes back as NA, not empty string", {
  got <- html_text_content("<html><body>text</body></html>")
  expect_true(is.na(got$title))
  expect_true(is.na(got$description))
  expect_true(is.na(got$lang))
})

test_that("malformed and empty input does not error", {
  expect_equal(html_text_content("")$text, "")
  expect_equal(html_text_content("   ")$text, "")
  # Truncated mid-tag: xml2 is lenient, and we must not propagate a parse failure.
  expect_no_error(html_text_content("<html><body><p>unclosed"))
  expect_no_error(html_text_content("not html at all"))
})

test_that("a page with no body still yields its text", {
  got <- html_text_content("<html><head><title>T</title></head></html>")
  expect_type(got$text, "character")
})
