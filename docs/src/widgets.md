# Widgets

```@meta
CurrentModule = ManyUI
```

ManyUI ships a small library of built-in widgets. They are ordinary
widgets with no privileged access: anything they do, your own widget
types can do too.

## Label

Wrapping text. It measures and paints through `wrap_width` and
`write_text!`, never through `Base.textwidth`, so a wide grapheme that
would straddle the right edge moves to the next line rather than being
cut in half.

```julia
using ManyUI

l = Label("Hello, ManyUI!")
measure(l, Size(40, 4))
```

Its text is reactive: assigning to it marks the label dirty for layout,
because new text wraps differently and can move its siblings.

```julia
l.text[] = "Some considerably longer text that will wrap"
measure(l, Size(20, 4))
```

## Container

A box that holds children, optionally with a border and a title. It is
the workhorse of layout — give it a `layout:` and a `gap:` and it
arranges whatever you put in it.

```julia
ui = Container(Label("first"), Label("second"))
layout!(ui, Region(1, 1, 20, 6))
length(children(ui))
```

## Button

A focusable, clickable widget that calls its callback when pressed —
whether by mouse, routed through hit testing, or by ENTER when it holds
focus.

Wiring one to a `Label` gives a counter, and shows the reactive loop
end to end: the callback writes the label's text, the write marks it
dirty, and the next frame repaints it.

```julia
clicks = Ref(0)
readout = Label("Count: 0"; id = :count)

b = Button("Click me", _ -> begin
               clicks[] += 1
               readout.text[] = "Count: $(clicks[])"
               nothing
           end; id = :go)

root = Container(readout, b)
layout!(root, Region(1, 1, 20, 4))

r = region(b)
for _ in 1:3
    dispatch_event!(root, MouseEvent(MouseAction.PRESS, MouseButton.LEFT,
                                     r.x, r.y, MOD_NONE))
end

(clicks = clicks[], text = readout.text[])
```

A button also fires on ENTER when it holds focus, so the same counter
works without a mouse:

```julia
dispatch_event!(root, parse(KeyEvent, "enter"), b)
readout.text[]
```

`is_focusable(b)` is true, so it takes part in the tab order:

```julia
is_focusable(b)
```

## Scrollpane

A window over exactly one child, for content bigger than the room you
have. Wrap several children in a `Container`, as CSS makes you.

The offset lives on the tree, not in the pane — so a wheel tick marks
`Dirty.PAINT` and layout never runs. `viewport(pane)` is the node that
scrolls, and it is what the scrolling API takes:

```julia
lines = Container([Static("line $i") for i in 1:8]...)
pane = Scrollpane(lines)
apply_stylesheet!(STYLESHEET_EMPTY, pane)
layout!(pane, Region(1, 1, 9, 3))

vp = viewport(pane)
(window = layout_of(vp).content.height, content = content_extent(vp).height)
```

Eight rows of content in a three-row window, so five rows can scroll
past. `scroll_to!` clamps and returns what it actually stored:

```julia
(max = max_scroll(vp), stored = scroll_to!(vp, Offset(0, 99)))
```

The wheel, the arrows, `pageup`/`pagedown` and `home`/`end` all work,
and a pane at its limit does not consume the event — so it bubbles to
the pane outside it and scroll chaining costs no code at all.
[Scrolling](scrolling.md) covers the whole story.

## Scrollbar

The visible indicator for one axis. It is a sibling of what it reports
on, never a child, so it never scrolls with the content — and it is
parametric on its viewport, so one `Scrollbar` serves a `Container`, a
`Scrollpane`'s canvas or a `TextArea` alike. It reads three functions
and touches nothing else.

`Scrollpane` builds its own, but the geometry is a pure function you can
check on its own — `(start, len)` on the track, for a window over some
content at an offset:

```julia
thumb_span(3, 3, 8, 0)
```

## TextInput

Single-line entry, with a caret, a placeholder and a submit handler. It
takes the width it is offered and scrolls horizontally rather than
resizing, so a keystroke costs zero layout.

```julia
field = TextInput("hi", i -> nothing; placeholder = "name?")
insert_text!(field, "!")
(text = field.text[], cursor = field.cursor[])
```

The cursor is a 0-based count of **grapheme clusters**, so it steps over
a wide emoji in one move and never lands inside one.

## TextArea

Multi-line entry over a `Vector{String}`. It scrolls by indexing its
lines, so painting is O(window) and a huge document costs the same frame
as a small one.

```julia
notes = TextArea("alpha\nbeta")
insert_newline!(notes)
(text = text(notes), extent = content_extent(notes))
```

It overrides `content_extent`, which is the whole of its integration
with `Scrollbar`. [Text entry](textentry.md) covers both widgets, and
the grapheme rules they are built on.

## MinSizeOverlay

The "Increase Terminal Size" screen. When the rendering area drops
below the root's minimum, the App suspends normal rendering and paints
this instead — no layout of your tree runs at all until there is room
for it again.

```julia
should_suspend(Size(12, 3), Size(20, 5))
```

```julia
should_suspend(Size(80, 24), Size(20, 5))
```

You rarely construct it yourself; `AppConfig(; min_size = ...)` decides
when it appears.

```julia
OVERLAY_MIN_SIZE
```

Below a certain size even the overlay cannot be laid out, so a
tree-free painter takes over. The framework never crashes because the
window got small.

## List, Table and DataTable

The data widgets, covered in full on the [Data widgets](@ref) page.
`List` shows items, `Table` shows columns, `DataTable` also sorts.

```julia
l = List(["alpha", "beta", "gamma"])
(rows = row_count(l), nodes = length(descendants(l)))
```

`nodes` is zero, and stays zero at a hundred thousand items: unlike
every other widget here, their rows are **data rather than widgets**, so
a frame costs the same however much data you hand them.

## Writing your own

A widget is a mutable struct holding a `WidgetNode`, plus whatever
state it needs:

```julia
using ManyUI

mutable struct Spinner <: ManyUI.Widget
    node::WidgetNode
    frame::Int
end
Spinner() = Spinner(WidgetNode(; type_name = :Spinner), 1)

const FRAMES = ('|', '/', '-', '\\')

ManyUI.measure(w::Spinner, avail::Size) = Size(1, 1)

# In ManyUITUI or a specific projection, you would implement render!:
# function ManyUITUI.render!(w::Spinner, buf::AbstractMatrix{Cell})
#     write_text!(buf, 1, 1, string(FRAMES[w.frame]), STYLE_NONE)
#     nothing
# end
```

Two methods make it real: `measure`, which reports how much room it
wants, and `render!`, which paints into the content box it was granted.
The buffer's `(1, 1)` is the content origin, and its size is the
content box — so a widget cannot paint outside its own region, and
`type_name` makes it addressable from CSS as `Spinner { ... }`.

## Readouts

Three widgets for showing a number without spending a node on each part
of it.

### Sparkline

A one-row plot, one cell per sample:

```julia
using ManyUI

sp = Sparkline([1, 3, 2, 5, 4]; cap = 240)
push_value!(sp, 6)
(n_values(sp), spark_bounds(sp))
```

The series is *data*, not a widget per point — the same seam `List` and
the table widgets use. A 10 000-sample series is one node, and a frame
costs the width of the widget rather than the length of the series,
because only the last `width` samples can be on screen. New data
arrives on the right; the oldest scrolls off the left. `cap` bounds a
live series so it cannot grow without limit.

`lo` and `hi` fix the scale, and fixing it is the point: auto-scaling
redraws the same series differently the moment one outlier arrives,
which is exactly when a reader most needs the picture to hold still. A
value outside a fixed scale is pinned to the end it overshot rather
than dropped.

### StatusBar

```julia
bar = StatusBar(; left = "server :2828",
                  center = RichText("running", Style(fg = rgb(0, 200, 0))),
                  right = "[q]uit")
status_layout(bar, 60)
```

Three segments on one row. It is a widget rather than three `Static`s
in a flex row for one reason: **what it drops when it does not fit**.
Flex would shrink all three and leave three half-truncated fragments. A
`StatusBar` drops the centre first, then the right, and truncates the
left only when it is alone and still too wide — the left segment is
where an application puts its identity, so it is the one that survives.
`status_layout` is pure, so you can test the rule without a buffer.

### ProgressList

A column of captioned bars:

```julia
pl = ProgressList([ProgressItem("build", 0.4),
                   ProgressItem("test", 0.9)])
set_progress!(pl, 1, 0.75)
(n_items(pl), pl_label_width(pl))
```

A row is *not* a widget — the seam `List` and the table widgets already
take. A hundred tasks are a `Vector` of a hundred items and one node;
composing this out of a hundred `ProgressBar`s would put a hundred
nodes on the tree to show a hundred numbers. It overrides
`content_extent`, so a `Scrollbar` reports on it with no new code.

The label column's `AUTO` width measures *every* item, unlike a table's
`AUTO` column, which samples. The costs differ: a caption is short and
a progress list is a handful of rows, where a table guards against a
hundred thousand. Sampling here would let the column change width as
the list scrolled, and every bar would jump sideways.

### A labelled ProgressBar is a gauge

```julia
ProgressBar(0.62; label = "62% — 1.4 GB/s")
```

A field rather than a second widget, because a `Gauge` would differ
from a `ProgressBar` by exactly that one. A labelled bar cannot use the
block glyphs — text written over `█` is unreadable — so it fills with a
reversed span, which keeps the boundary legible *through* the caption.

## Modal dialogs

A popup is already a second root painted over the tree and hit-tested
before it. `modal = true` is what turns one into a dialog:

```julia
using ManyUI, ManyUITUI

content = Container(Button("OK", _ -> nothing),
                    Button("Cancel", _ -> nothing);
                    title = "Discard changes?")

open_popup!(app, Popup(content, owner, Size(30, 5);
                       placement = PopupPlacement.CENTER,
                       modal = true))
```

What makes it modal is not its size or its placement — it is that the
user cannot walk around the question. Three things, and each is a way
out that had to be closed:

- **A press outside does not dismiss it.** The popup layer dismisses an
  ordinary popup on exactly that press, so this is carved out of it. A
  dialog the application cannot proceed without must not be answerable
  by clicking next to it.
- **TAB does not leave it.** `focus_root(app)` returns the modal's
  content instead of the tree, so the tab order is the dialog's.
- **A keystroke does not reach the tree behind it.** The same root is
  used to dispatch keys.

A non-modal popup keeps all three behaviours of the tree — a `DropDown`
holds focus itself and forwards to its list, which is why the trap asks
about `modal` and not merely about there being a popup.

Opening a modal moves focus into it and closing puts it back where it
was, provided that widget is still in the tree.

### Dialog

`Dialog` is **not** a new widget type. A dialog is a captioned
`Container` holding a message and a row of buttons, and every part of
that already exists:

```julia
msg = "Discard changes?"
d = Dialog(msg; title = "Confirm",
           buttons = ["OK"     => (_ -> close_popup!(app, owner)),
                      "Cancel" => (_ -> close_popup!(app, owner))])

open_popup!(app, Popup(d, owner, dialog_size(msg; title = "Confirm");
                       placement = PopupPlacement.CENTER, modal = true))
```

What did not already exist is the arrangement and the *size* — the
popup layer takes a declared size rather than measuring its content, so
guessing one line for a long question shows as a clipped one.
`dialog_size` wraps the message to the width it settles on and reports
the height it will actually need.

Modality is not part of `Dialog` either. `Popup(...; modal = true)`
supplies it, because it is a property of the layer, not of what is on
it.

### Dimming

A modal dims everything it covers before painting itself. `Attr.DIM`
and not an opaque fill, deliberately: dimming keeps the tree readable
underneath, which is what tells the user the application is still there
and merely waiting. A fill would say it had gone.
