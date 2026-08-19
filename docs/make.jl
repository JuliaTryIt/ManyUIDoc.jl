using Documenter
using ManyUI
using ManyUITUI

include(joinpath(@__DIR__, "llms.jl"))

# The nav tree, named once: `makedocs` renders it and `write_llms`
# indexes it, so a page cannot appear in one and be missing from the
# other.
const PAGES = [
    "Home" => "index.md",
    "Concepts" => "concepts.md",
    "Backends" => "backends.md",
    "Layout" => "layout.md",
    "Styling" => "styling.md",
    "Events" => "events.md",
    "Widgets" => "widgets.md",
    "Scrolling" => "scrolling.md",
    "Text entry" => "textentry.md",
    "Data widgets" => "data.md",
    "API reference" => [
        "api/enums.md",
        "api/geometry.md",
        "api/style.md",
        "api/buffer.md",
        "api/tree.md",
        "api/events.md",
        "api/drivers.md",
        "api/app.md",
        "api/widgets.md",
        "api/inputs.md",
        "api/scrolling.md",
        "api/text.md",
        "api/list.md",
        "api/tables.md",
    ],
]

DocMeta.setdocmeta!(ManyUI, :DocTestSetup, :(using ManyUI); recursive = true)
DocMeta.setdocmeta!(ManyUITUI, :DocTestSetup, :(using ManyUITUI); recursive = true)

makedocs(;
    modules = [ManyUI, ManyUITUI],
    sitename = "ManyUI.jl",
    authors = "Sébastien Celles",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://s-celles.github.io/ManyUIDoc.jl",
        edit_link = "main",
        inventory_version = "0.1",
        # The aggregate search index grows with the library and is past the
        # 500 KiB soft default; raise its ceiling so a full API stays one
        # warning-free build. `size_threshold` gets headroom too.
        search_size_threshold_warn = 1024 * 1024,
        size_threshold_warn = 500 * 1024,
        size_threshold = 1024 * 1024,
    ),
    pages = PAGES,
    checkdocs = :none,
    warnonly = false,
)

# llms.txt / llms-full.txt, written into the build directory Documenter
# deploys verbatim, so they land at the site root.
write_llms(;
    srcdir = joinpath(@__DIR__, "src"),
    builddir = joinpath(@__DIR__, "build"),
    pages = PAGES,
    sitename = "ManyUI.jl",
    summary = "A Julia UI framework whose widget tree and model are written \
               once and projected to several targets: a terminal, a browser, \
               a Dear ImGui window, or a CLI.",
    baseurl = "https://s-celles.github.io/ManyUIDoc.jl/dev",
)

if get(ENV, "CI", "false") == "true"
    deploydocs(;
        repo = "github.com/s-celles/ManyUIDoc.jl",
        devbranch = "main",
    )
end
