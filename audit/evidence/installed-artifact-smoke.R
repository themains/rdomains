.libPaths(c("/tmp/rdomains-060-installed", .libPaths()))
library(rdomains)
stopifnot(as.character(packageVersion("rdomains")) == "0.6.0")
path <- tempfile(fileext = ".csv")
writeLines(c("domains,category", "example.com,news", "example.com,shopping"), path)
result <- suppressWarnings(shalla_cat(c("https://example.com/news", "absent.example"), use_file = path))
stopifnot(nrow(result) == 2L, ncol(result) == 18L,
          identical(result$status, c("ok", "no_match")),
          identical(result$labels[[1]]$category, c("news", "shopping")))
saved <- tempfile(fileext = ".rds")
saveRDS(result, saved)
stopifnot(identical(readRDS(saved), result))
stopifnot(nrow(pie_cat(character())) == 0L,
          nrow(openai_cat(character())) == 0L,
          identical(names(news_url_signals(character())),
                    c("input_id", "input", "soft_news", "hard_news")))
fixture <- jsonlite::fromJSON("tests/testthat/fixtures/model-page.json")
pages <- rdomains:::fetch_row("audit.example", "https://audit.example/article", Sys.time(),
  status = "ok", stage = "process", html = fixture$html,
  parsed = rdomains:::html_text_content(fixture$html), signals = page_signals(fixture$html)
)
classified <- pie_cat(pages = pages)
stopifnot(classified$status == "ok", classified$category == "news",
          classified$model_revision == "38d7e6403f911902f47b9218ce5c645a06dd02fe")
classified$input_id <- 42L
stopifnot(pie_cat(pages = classified)$input_id == 42L)
cat("Installed 0.6.0 artifact: lookup, typed empties, RDS resume, real model and restored IDs passed.\n")
