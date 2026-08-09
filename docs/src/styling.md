# Styling

```@meta
CurrentModule = ManyUI
```

Appearance is declarative. Rules are written in a CSS-like syntax,
matched against widget ids, classes and types, and cascaded onto the
tree by specificity.

## Stylesheets

`parse_css` builds a `Stylesheet`; the `css"..."` string macro does the
same at parse time:

```julia
using ManyUI

sheet = parse_css("""
    Container { layout: column; padding: 1; gap: 1; border: round cyan; }
    Label     { color: cyan; }
    .warn     { color: yellow; }
    #title    { color: red; }
""")

length(sheet.rules)
```

Bad input throws a `CssParseError` carrying the line and column, never
a bare `ArgumentError`:

```julia
try
    parse_css("Label { color: }")
    false
catch e
    e isa CssParseError
end
```

## Selectors and specificity

Three selector kinds are supported, and they rank exactly as CSS ranks
them — id beats class beats type:

```julia
[(src, specificity(parse_css(src).rules[1].selector))
 for src in ("#title { color: red; }",
             ".warn { color: red; }",
             "Label { color: red; }")]
```

`Specificity(id, class, type)` is compared field by field. Between two
rules of equal specificity, the later one wins.

Applying the sheet resolves each node's computed style. A label that is
`#title`, `.warn` *and* a `Label` matches all three rules, and the id
wins:

```julia
label = Label("hi"; id = :title, classes = [:warn])
root = Container(label)
apply_stylesheet!(sheet, root)

computed_style(label).fg
```

`apply_stylesheet!` walks the whole tree; `recascade!` is the
incremental form the frame loop uses, doing the work only where the
style is dirty.

## Properties

| Property | Value |
|:--|:--|
| `color` | foreground color |
| `background` | background color |
| `border` | `<kind>` or `<kind> <color>` |
| `display` | `none`, `block`, `flex` |
| `layout` | a direction; shorthand for `display: flex` plus `direction` |
| `direction` | `row`, `column`, `row-reverse`, `column-reverse` |
| `justify` | `start`, `center`, `end`, `space-between`, `space-around`, `space-evenly` |
| `align` | `start`, `center`, `end`, `stretch` |
| `width`, `height` | a length |
| `margin`, `padding` | 1, 2 or 4 cell counts, in CSS order |
| `gap` | cells between flex children |
| `grow`, `shrink` | flex weights |
| `overflow` | `visible`, `hidden`, `scroll` |

Adding a property is adding a `parse_property` method — the table is
extensible, and is used only by the parser, never in a render loop.

## Colors

Colors come in four kinds:

```julia
using ManyUI
(rgb(0xFF, 0x64, 0x00), ansi256(202), ansi16(9), COLOR_DEFAULT)
```

## Color degradation

Not every terminal speaks 24-bit color. Rather than refuse to draw,
ManyUI maps a color down to whatever the target actually supports.
`degrade` is a pure function of the color and the depth:

```julia
orange = rgb(0xFF, 0x64, 0x00)
(truecolor = orange,
 at_256 = degrade(orange, ColorDepth.ANSI256),
 at_16 = degrade(orange, ColorDepth.ANSI16))
```

The 256-color step maps into the 6×6×6 cube and the grayscale ramp; the
16-color step picks the nearest perceptual match.

The depth is never guessed from `ENV` inside the render path. It comes
from the driver's `capabilities`, so a web client reporting no
truecolor support degrades exactly like a limited tty:

```julia
caps = capabilities(HeadlessDriver(Size(10, 2); depth = ColorDepth.ANSI16))
caps.color_depth
```

`detect_color_depth` is what a `TerminalDriver` uses to answer that
question for a real terminal, from `COLORTERM` and `TERM`.

## Text attributes

Attributes live on `Style`:

```julia
s = with(STYLE_NONE, Attr.BOLD, true)
(bold = has(s, Attr.BOLD), italic = has(s, Attr.ITALIC))
```

Styles merge with the child winning wherever it specifies something —
the same rule the cascade itself is built from.

## Rich text

The cascade styles *nodes*. Some styled things are not nodes: the key
in a tab caption, the level in a log line, the units in a status
readout. Making each of those a widget would put three nodes on a tab
strip and one per log row.

`RichText` is one line whose style varies along it — a sequence of
`TextRun`s, each carrying an override:

```julia
using ManyUI

warn = Style(fg = rgb(255, 200, 0), bold = true)
caption = RichText(TextRun("1", warn), TextRun(" Server"))

(plain(caption), text_width(caption))
```

`Label` and `Static` accept one wherever they accept a string, and a
string converts implicitly, so nothing about the existing spelling
changes:

```julia
l = Label(caption)
l.text[] = "back to plain"      # still a valid assignment
plain(l.text[])
```

### A run is a difference, not an appearance

A run's style is folded over the painting widget's computed style with
`merge` — the cascade's own monoid. So `STYLE_NONE`, the default, means
*exactly the widget's style*, and a run naming only `bold` keeps the
widget's colours:

```julia
base = Style(fg = rgb(0, 255, 0), bg = rgb(0, 0, 0))
got = merge(base, Style(bold = true))

(fg = got.fg == rgb(0, 255, 0), bg = got.bg == rgb(0, 0, 0),
 bold = has(got, Attr.BOLD))
```

That is what lets one `RichText` be built once and painted under a
light and a dark theme without being rebuilt. Runs that specify an
absolute colour still work — they simply stop tracking the theme.

### Styling never moves a break

`text_width`, `truncate_width` and `wrap_width` all accept a
`RichText`. Wrapping runs the *plain* text through the ordinary string
wrap and reattaches the styling afterwards, which makes one property
true by construction:

```julia
rt = RichText(TextRun("the quick ", Style(bold = true)),
              TextRun("brown fox jumps"))

plain.(wrap_width(rt, 12)) == wrap_width(plain(rt), 12)
```

Colouring a paragraph cannot reflow it. A second wrap implemented over
styled runs would have to be kept in step with the first forever to
promise that; there is only one wrap.

Two details follow from the same reasoning. A joining space inherits
the style of the whitespace run it replaces, because that cell still
has a background and resetting it would leave a hole in a highlighted
line. And `truncate_width` yields a *prefix*: it stops at the first
cluster that does not fit rather than skipping it, so a wide cluster
refused at the right edge never lets a narrow run behind it slide
forward into the freed cell.

### In the row widgets

A `List`'s `format`, a `Table`'s or `DataTable`'s `cell`, and a tab
caption all accept `TextLike` — either spelling. Nothing converts
eagerly, so the ordinary plain-string case allocates nothing extra:

```julia
warn = Style(fg = rgb(255, 0, 0))
level = r -> RichText(TextRun(String(r[1]),
                              r[1] === :error ? warn : STYLE_NONE),
                      TextRun(" " * r[2]))

log = List([(:error, "disk full"), (:info, "ok")]; format = level)
n_rows(log)
```

This is the case that motivated the primitive. A log list colouring
only its level column, or a tab strip with the shortcut key in a
warning colour, would otherwise need one widget per styled fragment —
three nodes on every tab, one per log row.

Column widths, truncation and the ellipsis marker behave exactly as
they do for plain cells, because they are decided on the text.

### Painting one

Backends paint a `RichText` through `write_richtext!`, which folds each
run over the widget's style and stops at the first run the edge cut
short:

```julia
using ManyUITUI

buf = Buffer(8, 1)
write_richtext!(buf, 1, 1, caption)
string(buf)
```
