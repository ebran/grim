# Package

version       = "0.1.1"
author        = "Erik G. Brandt"
description   = "Graphs in nim!"
license       = "MIT"
srcDir        = "src"

# custom task for documentation
task docs, "Build the documentation (HTML)":
   exec "nim doc --outdir:docs/ --project --index:on --git.url:https://www.github.com/ebran/grim src/grim.nim"
   exec "nim buildIndex --out:docs/index.html docs"
   "docs/grim.html".mvFile("docs/index.html")

# Dependencies

requires "nim >= 1.0.4"
requires "yaml"
