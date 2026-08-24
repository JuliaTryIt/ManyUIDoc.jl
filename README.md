# ManyUIDoc.jl

**ManyUIDoc** is the central documentation repository for the entire ManyUI ecosystem.

## 📖 Documentation

The documentation is built with `Documenter.jl` and automatically deployed to GitHub Pages.

👉 **[Read the Documentation (ManyUIDoc)](https://juliatryit.github.io/ManyUIDoc.jl/)**

### For language models

The site also publishes the documentation in the [llms.txt](https://llmstxt.org)
format, generated from the same page tree the nav is built from:

- [`/llms.txt`](https://juliatryit.github.io/ManyUIDoc.jl/dev/llms.txt) — a curated
  index: one line per page, with a link and a one-sentence description.
- [`/llms-full.txt`](https://juliatryit.github.io/ManyUIDoc.jl/dev/llms-full.txt) —
  every page inline, so a model needs no crawling and no search index.

Both are written by `docs/llms.jl` at the end of `docs/make.jl`, into the
build directory Documenter deploys verbatim. A page added to `PAGES`
appears in both without any further step; a page listed there but missing
from `docs/src` fails the build rather than producing a short index.

## The Ecosystem

The ManyUI framework is divided into several composable packages:
- **[ManyUI.jl](https://github.com/juliatryit/ManyUI.jl)** (Core framework)
- **[ManyUITUI.jl](https://github.com/juliatryit/ManyUITUI.jl)** (Terminal TUI backend)
- **[ManyUIWeb.jl](https://github.com/juliatryit/ManyUIWeb.jl)** (Web backend)
- **[ManyUICImGui.jl](https://github.com/juliatryit/ManyUICImGui.jl)** (Dear ImGui desktop backend, in development)
- **[ManyUICLI.jl](https://github.com/juliatryit/ManyUICLI.jl)** (Command-line generator)
- **[ManyUIDemos.jl](https://github.com/juliatryit/ManyUIDemos.jl)** (Showcase and examples)
