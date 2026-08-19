# Backends

A `Driver` makes targets swappable. A `Backend` makes them
swappable *without editing the call*.

## One verb

`launch` runs an app on any target:

```julia
using ManyUI

ui() = Container(Label("hello"))

launch(ui)                                   # this terminal
launch(ui; backend = HeadlessBackend())      # nothing attached
```

With `ManyUIWeb` loaded, the same app runs in a browser and the *only*
thing that changes is the backend argument:

```julia
using ManyUI, ManyUIWeb

launch(ui; backend = WebBackend(port = 8000))
```

Nothing else moves. `config` and `stylesheet` describe the **app**, so they
are spelled the same way whatever the target; a port or a tty describes the
**target**, so it lives on the backend.

## Capability discovery

Applications that offer more than one target can inspect a backend without
starting it:

```julia
ManyUI.backend_available(backend)
ManyUI.backend_kind(backend)
ManyUI.backend_capabilities(backend)
```

The common capability fields are `mouse`, `keyboard`, `text_input`, `focus`,
`resize`, `transparency`, `animations`, `native_window`, `gpu` and
`multi_session`. For example, an ImGui launcher can hide its native option
when `backend_available(ImGuiBackend())` is false because CImGui is not
installed, while WebTUI and WebNative can advertise their own feature sets.

## Why a factory

`launch` takes `() -> Widget` — a function that builds a tree — not a tree:

```julia
launch(ui)          # yes
launch(ui())        # no
```

A terminal needs one app. A browser needs **one app per connected client**,
each with its own tree, and it cannot know how many until they arrive. Only
a factory serves both, which is why it is the universal unit rather than a
convenience. It is also what keeps sessions isolated: two browsers share no
mutable state because each got its own `factory()` call.

## Blocking, and the handle

By default `launch` blocks until the app quits and returns an exit code,
like `run!`:

```julia
code = launch(ui)     # returns when the user quits
```

Pass `wait = false` to keep going and get a handle back:

```julia
h = launch(ui; wait = false)
isopen(h)     # still going?
close(h)      # ask it to stop
wait(h)       # block until it has
```

The handle's *type* is the backend's business — an `App` for a terminal, a
`WebServer` for WebTUI, or a `WebNativeServer` for WebNative — but every handle
answers those same three verbs, so code that starts and stops an app need not
know which backend it got. A handle is **live when you get it**: `launch` does
not return until the loop is actually up, so `isopen(h)` is true on the next
line and a `close` cannot race the loop into existence.

## Writing a backend

Two things, and nothing else:

```julia
struct MyBackend <: ManyUI.Backend end
ManyUI.make_driver(::MyBackend) = MyDriver()
```

That is the whole contract for a target with one driver. There is no
fallback for `make_driver` on purpose: a backend that forgets it
gets a `MethodError` naming the type, rather than a silent default driver
writing to somebody's terminal.

A backend whose target **multiplexes** — one app per client, as the web
does — has no single driver to make, so it defines its own `launch` method
instead and never implements `make_driver`. `ManyUIWeb.WebBackend` is the
worked example, and it lives in another package entirely: a backend joins
by dispatch, with no cooperation from ManyUI beyond the abstract type.

## The old entry points still work

`launch` is a convenience over the seam, not a replacement for it. This
still means exactly what it always did, and is what you want when you have
a driver in hand rather than a description of one:

```julia
run!(App(ui(), TerminalDriver()))
```

## ManyUITUI (Terminal Backend)

**ManyUITUI.jl** is the official Terminal User Interface (TUI) backend for the ManyUI framework. It projects the declarative widget tree directly into a standard terminal emulator with full interactivity, rich colors, and complex layouts.

### Features
- **Terminal Driver & Raw Mode**: Safely captures keyboard and mouse inputs, and handles terminal resizing seamlessly.
- **Optimized Diffing Engine**: Only the parts of the screen that actually change are redrawn, utilizing minimal ANSI escape sequences. This ensures a buttery smooth, flicker-free experience even over slow SSH connections.
- **CSS-like Styling**: Translates `ManyUI` declarative styles (flexbox constraints, borders, paddings, colors) into raw terminal characters and ANSI codes.
- **Event Parsing**: Parses complex ANSI escape sequences from standard input into rich Julia events (`Click`, `KeyPress`, `Scroll`, etc.).

### Quickstart

```julia
using ManyUI
using ManyUITUI

# 1. Domain Model
mutable struct CounterModel
    clicks::Int
end
struct Increment <: Action end

# 2. Logic
ManyUI.execute!(model::CounterModel, ::Increment) = model.clicks += 1

# 3. View
function ManyUI.render(model::CounterModel, proj::ManyUI.Projection)
    Container(
        Label("Count: $(model.clicks)"),
        Button("Click me", _ -> ManyUI.execute!(model, Increment()))
    )
end

# 4. Launch in the Terminal!
ManyUI.launch(CounterModel(0), TUI())
```

## ManyUICImGui (Dear ImGui desktop backend)

**ManyUICImGui.jl** is the desktop projection under development. It keeps the
ManyUI widget/model and canonical event contracts while using Dear ImGui for
native rendering. Its headless driver is available without graphical system
libraries, so backend and event tests can run in CI.

The optional native window seam currently uses CImGui's GLFW/OpenGL3 backend.
It lives in a package extension whose triggers are **CImGui, GLFW, HarfBuzz
and ModernGL** — all four. An extension fires only when every trigger is
loaded, so installing three of them leaves the backend asleep and
`launch_manyui` reaches a stub that throws:

```julia
using Pkg
Pkg.add(["ManyUICImGui", "CImGui", "GLFW", "HarfBuzz", "ModernGL"])

using ManyUI, ManyUICImGui
import CImGui, GLFW, HarfBuzz, ModernGL   # wake the extension

ManyUICImGui.native_available()           # true once it is awake

ui() = Container(Label("Hello from ManyUI"))
ManyUICImGui.launch_manyui(ui; width=900, height=600)
```

!!! note "HarfBuzz needs a recent `HarfBuzz_jll`"
    `libcimgui` calls `glfwGetPlatform`, which exists only in GLFW 3.4. A
    `HarfBuzz_jll` bound that forces the 100.x series drags `GLFW_jll` back
    to 3.3.9, where that symbol is missing, and the process dies with
    `signal 11 (2): Segmentation fault: 11`. If that happens, check the
    resolved `GLFW_jll` first — 3.3.9 is the symptom.

### Running the ManyUI demos in a CImGui mode

`ManyUIDemos` keeps the GPU stack out of its base environment, so the two
CImGui modes run from the `CImGuiEnv` environment shipped beside it:

```console
$ just instantiate-cimgui                        # once
$ just hub-cimgui                                # the hub, CImGui TUI
$ just demo-cimgui gallery.jl cimguitui          # one demo
```

Asking for `cimgui`/`cimguitui` from the base environment prints what is
missing and the command above rather than failing.

### Closing the window

The two paths end their window differently, and a launcher that offers both
has to know which:

* **`launch_tui`** runs a real ManyUI `App`, so `ManyUITUI.quit!(app)` is
  enough — the render loop stops with the App and the window goes with it.
* **`launch_manyui`** projects widgets straight into ImGui with no `App`
  behind them. A callback that means "this window is done" has nothing to
  quit, so it calls `ManyUICImGui.request_close!()` instead, which asks the
  window that is currently rendering to close and returns whether there was
  one. It never throws and returns `false` when the extension is asleep, so
  code that runs under every backend can call it unconditionally.

The initial projection covers `Container`, `Label`, `Static` and `Button`.
Widget, layout, event, theme and animation parity is tracked in the
[ManyUICImGui roadmap](https://github.com/s-celles/ManyUICImGui.jl/blob/main/ROADMAP.md).

## Reference
