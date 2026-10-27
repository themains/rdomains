Sys.unsetenv(c("OPENAI_API_KEY","ANTHROPIC_API_KEY","CLAUDE_API_KEY"))
devtools::load_all("/tmp/rdomains-audit-20261026",quiet=TRUE)
app <- webfakes::new_app()
app$get("/robots.txt",function(req,res) res$send("User-agent: *\nDisallow: /private\n"))
app$get("/private",function(req,res) res$set_header("content-type","text/html")$send(paste0("<html><body>",paste(rep("private page substantive content",20),collapse=" "),"</body></html>")))
app$get("/start",function(req,res) res$set_status(302L)$set_header("location","/private")$send(""))
srv <- webfakes::new_app_process(app)
tryCatch({
  for(path in c("/private","/start")) {
    cat("ROBOTS",path,"\n")
    print(collect_content(srv$url(path),delay=0.01,allow_hosts="127.0.0.1",archive_fallback=FALSE,cache_dir=tempfile())[,c("status","robots_allowed","final_url")])
  }
},finally=srv$stop())
cat("ROBOTS_REDIRECT_GUARD\n")
app2 <- webfakes::new_app()
app2$get("/robots.txt",function(req,res)res$set_status(302L)$set_header("location","/internal-robots")$send(""))
app2$get("/internal-robots",function(req,res)res$send("User-agent: *\nAllow: /\n"))
srv2 <- webfakes::new_app_process(app2)
tryCatch(print(rdomains:::robots_for_origin(sub("/$","",srv2$url()))$status),finally=srv2$stop())
