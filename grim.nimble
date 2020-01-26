# Package

version       = "0.1.1"
author        = "Erik G. Brandt"
description   = "Graphs in nim!"
license       = "MIT"
srcDir        = "src"

# build HTML documentation in docs/
task docs, "Build the documentation (in HTML)":
  # Build documentation from .rst files in docs/ folder
  for dir in "docs" & listDirs("docs"):
    for file in listFiles(dir):
      if file[^4..^1] == ".rst":
        selfExec "rst2html --outdir:$1 $2".format(dir, file)
  
  # Build reference documentation from comments in code
  selfExec "doc --outdir:docs/ --project --index:on --git.url:https://www.github.com/ebran/grim src/grim.nim"
  selfExec "buildIndex --outdir:docs/ docs"
  # Get rid of xml header line
  exec "sed -i '1d' docs/index.html"

# Dependencies

requires "nim >= 1.0.4"
requires "yaml"
