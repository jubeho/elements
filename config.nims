# switch("out", "bin/")
task run, "default build is via the c backend":
  setCommand "c"
  --run
  --outdir:bin
task mydoc, "creates doc":
  setCommand "doc"
  --outdir:"src/htmldocs"
  --project
