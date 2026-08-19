# llms.txt / llms-full.txt -- the documentation, addressed to a model.
#
# https://llmstxt.org: a site publishes `llms.txt`, a short curated index
# in markdown, and optionally `llms-full.txt`, the whole text inline. A
# model reading either gets the documentation without executing the
# JavaScript search index or crawling the HTML.
#
# Both are DERIVED from the same `pages` tree `makedocs` renders, so a
# page added to the nav appears here without anyone remembering to.

"""
First markdown H1 of `path`, or a title derived from the file name when
the page has none.
"""
function _page_title(path::AbstractString)::String
    for line in eachline(path)
        m = match(r"^#\s+(.+?)\s*$", line)
        m === nothing || return String(m.captures[1])
    end
    return titlecase(replace(splitext(basename(path))[1], '_' => ' '))
end

"""
The page's first prose sentence, for the one-line description `llms.txt`
puts after each link. Skips headings, code fences, admonitions and
Documenter `@` blocks -- none of them describe the page.
"""
function _page_blurb(path::AbstractString)::String
    in_fence = false
    para = String[]
    for line in eachline(path)
        s = strip(line)
        if startswith(s, "```")
            in_fence = !in_fence
            continue
        end
        in_fence && continue
        if isempty(s)
            # A blank line ends the first prose paragraph -- but only
            # once we have started one.
            isempty(para) ? continue : break
        end
        (startswith(s, '#') || startswith(s, '!') || startswith(s, '|') ||
         startswith(s, '-') || startswith(s, '*')) && continue
        push!(para, s)
    end
    isempty(para) && return ""
    # A sentence usually WRAPS across source lines, so join the paragraph
    # before cutting it: splitting per line truncated mid-clause ("applies
    # them to a grid of").
    text = join(para, " ")
    # The sentence may end INSIDE emphasis -- "...render it anywhere.**" --
    # so allow the markers between the full stop and the space, and then
    # drop bold markers entirely: a one-line index gains nothing from
    # them, and half a bold span would leave the markdown unbalanced.
    sentence = first(split(text, r"(?<=[.!?])[*_]*\s"))
    sentence = replace(sentence, "**" => "")
    length(sentence) <= 220 && return sentence
    # Truncate on a word boundary, never mid-word.
    cut = findlast(' ', first(sentence, 220))
    return rstrip(first(sentence, cut === nothing ? 220 : cut - 1), [' ', ',', ';']) * "…"
end

# `pages` entries are either "file.md", "Title" => "file.md", or
# "Group" => [entries...]. Flatten to (group, title, relpath) triples.
function _flatten(pages, srcdir; group = "Documentation")
    out = Tuple{String,String,String}[]
    for entry in pages
        if entry isa AbstractString
            push!(out, (group, _page_title(joinpath(srcdir, entry)), entry))
        elseif entry isa Pair && entry.second isa AbstractString
            push!(out, (group, String(entry.first), String(entry.second)))
        elseif entry isa Pair
            append!(out, _flatten(entry.second, srcdir; group = String(entry.first)))
        end
    end
    return out
end

"""
    write_llms(; srcdir, builddir, pages, sitename, summary, baseurl)

Write `llms.txt` and `llms-full.txt` into `builddir`, which Documenter
deploys verbatim, so they land at the site root next to `index.html`.

Returns the two paths. Throws if a page in `pages` has no source file --
that is a broken nav, and a silently short `llms.txt` is worse than a
failed build.
"""
function write_llms(; srcdir::AbstractString, builddir::AbstractString,
                    pages, sitename::AbstractString,
                    summary::AbstractString, baseurl::AbstractString)
    entries = _flatten(pages, srcdir)
    isempty(entries) && error("write_llms: no pages to index")

    for (_, _, rel) in entries
        isfile(joinpath(srcdir, rel)) ||
            error("write_llms: $(rel) is in `pages` but not in $(srcdir)")
    end

    mkpath(builddir)

    index = IOBuffer()
    println(index, "# ", sitename)
    println(index)
    println(index, "> ", summary)
    println(index)
    last_group = ""
    for (group, title, rel) in entries
        if group != last_group
            println(index)
            println(index, "## ", group)
            println(index)
            last_group = group
        end
        # `index.md` IS the site root: /dev/, not /dev/index/.
        slug = rel == "index.md" ? "" : replace(rel, r"\.md$" => "/")
        url = rstrip(baseurl, '/') * "/" * slug
        blurb = _page_blurb(joinpath(srcdir, rel))
        println(index, "- [", title, "](", url, ")",
                isempty(blurb) ? "" : ": " * blurb)
    end

    full = IOBuffer()
    println(full, "# ", sitename)
    println(full)
    println(full, "> ", summary)
    println(full)
    println(full, "This file is the complete documentation, one page after ",
                  "another, in the order the site presents them.")
    for (_, title, rel) in entries
        println(full)
        println(full, "<!-- source: ", rel, " -->")
        println(full)
        body = read(joinpath(srcdir, rel), String)
        # The page's own H1 becomes an H2 here, so the concatenation has
        # exactly one H1 -- the site's -- and stays a valid outline.
        body = replace(body, r"^#\s"m => "## ")
        println(full, "## ", title)
        println(full)
        println(full, strip(body))
    end

    index_path = joinpath(builddir, "llms.txt")
    full_path = joinpath(builddir, "llms-full.txt")
    write(index_path, String(take!(index)))
    write(full_path, String(take!(full)))

    # Cheap self-checks: every page must be reachable from both files.
    idx = read(index_path, String)
    fll = read(full_path, String)
    for (_, title, rel) in entries
        occursin(title, idx) || error("write_llms: $(title) missing from llms.txt")
        occursin(rel, fll) || error("write_llms: $(rel) missing from llms-full.txt")
    end

    @info "wrote llms.txt / llms-full.txt" pages = length(entries) index_path full_path
    return (index_path, full_path)
end
