# Package

version       = "0.2.0"
author        = "Erik G. Brandt"
description   = "Bringer of property graphs to Nim!"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 1.0.4"
requires "yaml"
requires "zero_functional"

# Tasks

# build HTML documentation
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

# Tutorials
task northwind, "Northwind tutorial":
  withDir("tutorials"):
    #selfExec "c -r northwind.nim"                        # debug mode
    selfExec "c -d:release -d:danger -r northwind.nim"  # release mode
