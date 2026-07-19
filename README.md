# tcllunasvg — SVG rendering for Tcl

Tcl binding for [lunasvg](https://github.com/sammycage/lunasvg) — renders SVG to
PNG files or ARGB32 pixel buffers. **No Tk, no Cairo required**: runs in plain
`tclsh`.

**Version:** 0.1.1 · **License:** BSD-2-Clause · **Tcl:** 8.6 / 9.0
**Output:** PNG file, ARGB32 byte buffer
**Platforms:** Linux, Windows (MSYS2 UCRT64), macOS (untested)

---

## What is tcllunasvg?

A **standalone, lightweight Tcl extension** for SVG rendering. Extracted from the
former lunasvg integration in `tclmcairo` — now cleanly separated, with no
C-level coupling to Cairo or Tk.

When a workflow wants to post-process the rendered SVG **with Cairo**, `to_argb32`
returns a byte buffer that `tclmcairo` can take in via its `image_from_argb32`
API (from tclmcairo 0.4.0). Tk-based applications can load the PNG output
directly with `image create photo`.

---

## Quick start

### Produce a PNG from an SVG (one-shot)

```tcl
package require tcllunasvg
tcllunasvg::file_to_png "logo.svg" "logo.png" -scale 2
```

### Document handle for multiple renderings

```tcl
package require tcllunasvg

set doc [tcllunasvg::load file "diagram.svg"]
puts "SVG size: [$doc size]"

$doc to_png "small.png"   -width  200
$doc to_png "large.png"   -scale  3.0
$doc to_png "labeled.png" -scale  2.0 -bg white

$doc destroy
```

### Render an SVG from a Tcl string

```tcl
set svg {
<svg width="200" height="100" xmlns="http://www.w3.org/2000/svg">
  <rect width="200" height="100" fill="#4078c0"/>
  <text x="100" y="55" text-anchor="middle" fill="white"
        font-size="24" font-family="sans-serif">Hello</text>
</svg>
}

set doc [tcllunasvg::load data $svg]
$doc to_png "hello.png"
$doc destroy
```

### Pass ARGB32 pixels to tclmcairo

```tcl
package require tcllunasvg
package require tclmcairo

# 1. render the SVG
set doc [tcllunasvg::load file "icon.svg"]
set img [$doc to_argb32 -scale 4]
$doc destroy

# 2. load the pixels into a tclmcairo context, place them, release
set ctx [tclmcairo::new 800 600]
$ctx clear 1 1 1
set img_id [$ctx image_from_argb32 \
    [dict get $img data] [dict get $img width] [dict get $img height]]
$ctx image_blit $img_id 100 100
$ctx image_free $img_id
$ctx save "page.pdf"
$ctx destroy
```

> **Note:** `tclmcairo::image_from_argb32` arrives with tclmcairo 0.4.0. Until
> then, `demos/demo-svg-argb32-tclmcairo.tcl` automatically uses a PNG fallback
> path.

---

## Tcl API reference

### `tcllunasvg::load <file|data> <argument>`

Loads an SVG document. Returns a **handle command**.

```tcl
set doc [tcllunasvg::load file "logo.svg"]
set doc [tcllunasvg::load data $svgstring]
```

### `$doc width` / `$doc height` / `$doc size`

Returns the document dimensions from the SVG `viewBox` attribute.

### `$doc apply_stylesheet <css>`

Applies additional CSS to the document.

### `$doc to_png <filename> ?-width W? ?-height H? ?-scale S? ?-bg COLOR?`

Renders and writes a PNG. PNG encoding is done by lunasvg itself.

### `$doc to_argb32 ?-width W? ?-height H? ?-scale S? ?-bg COLOR?`

Renders into an ARGB32 premultiplied byte buffer. Returns a dict with the keys
`width`, `height`, `stride`, `data`.

### `$doc destroy`

Releases the document.

### Options

| Option | Values | Meaning |
|--------|--------|---------|
| `-width W` | int >= 1 | target width in pixels |
| `-height H` | int >= 1 | target height in pixels |
| `-scale S` | float > 0 | multiplier on the intrinsic SVG size |
| `-bg COLOR` | color literal | background |

**Target-size precedence** (important):

1. If `-scale S` is given, the output size is **always** `S * intrinsic SVG
   size`. `-width` and `-height` are then **ignored** (no error, just ignored).
2. Otherwise, if `-width` and/or `-height` are given: they set the target size
   (a missing dimension is scaled proportionally).
3. Otherwise: 1:1 with the intrinsic SVG size.

**Color literals:** `0xAARRGGBB`, `#RRGGBB`, `#AARRGGBB`, `#RGB`, or
`white` / `black` / `transparent`.

---

### Utility commands

#### `tcllunasvg::version`
Returns the lunasvg version (e.g. `"3.5.0"`).

#### `tcllunasvg::version_number`
Returns the version as an integer (e.g. `30500`).

#### `tcllunasvg::font_add <family> <bold> <italic> <filename>`

Registers a TTF/OTF file in the lunasvg font cache.

```tcl
tcllunasvg::font_add "DejaVu Sans" 0 0 "/usr/share/fonts/dejavu/DejaVuSans.ttf"
```

#### `tcllunasvg::file_to_png <in.svg> <out.png> ?opts?`

Convenient one-shot without a handle.

---

## What tcllunasvg does **not** do

- **No `<textPath>`** — an upstream lunasvg limitation. Workaround: `svg2cairo`
  from tclmcairo.
- **No in-place SVG DOM editing** — load, render, done.
- **No Tk photo image output** — by design. Write a PNG and load it with
  `image create photo -file out.png`.

---

## Related packages

- **[lunasvg](https://github.com/sammycage/lunasvg)** — the underlying C++
  library (3.5+).
- **[tclmcairo](https://github.com/gregnix/tclmcairo)** — Cairo binding for Tcl.
  Consumes ARGB32 output via `image_from_argb32` (from 0.4.0).
- **svg2cairo** (part of tclmcairo) — a Tcl-based SVG renderer on Cairo, covers
  textPath.

### Which renderer to choose?

The tclmcairo ecosystem offers three SVG renderer paths:

| Renderer | From package | CSS | `<text>` | `<textPath>` | `<marker>` / `<use>` | Extra deps |
|----------|--------------|-----|----------|--------------|----------------------|------------|
| `tclmcairo::svg_file` / `svg_data` | tclmcairo (nanosvg) | ✗ | ✗ | ✗ | partial | none |
| `svg2cairo::render` | tclmcairo | ✓ | ✓ | ✓ fallback | ✗ | tDOM |
| `tcllunasvg` (this package) → `image_from_argb32` | tcllunasvg + tclmcairo | ✓ | ✓ | ✗ upstream | ✓ | lunasvg DLL |

**tcllunasvg is worth it** when the SVG contains `<marker>`, `<use>`,
`<clipPath>`, gradients in `<defs>`, or embedded `<image>` elements that nanosvg
and svg2cairo do not render. For plain `<textPath>`, svg2cairo remains the only
way.

---

## Build / installation

See `INSTALL.md`. In short (`configure` is included — `autoconf` is only needed
if you change `configure.ac`):

**Linux:**
```bash
./configure --with-tcl=/usr/lib/tcl8.6 --with-lunasvg=$HOME/src/lunasvg
make && sudo make install && make test
```

**Windows MSYS2 UCRT64:**
```bash
./configure --with-tcl=/c/Tcl/lib --with-lunasvg=$HOME/src/lunasvg
make && make install && make test
```

On Windows, `make install` copies all required DLLs into the package directory.

> **Match the C runtime.** Build the extension with the **same** runtime as the
> target Tcl: MSYS2 **UCRT64** for MSVC-built Tcl (official binaries, Magicsplat),
> but the **BAWT MinGW** toolchain for a BAWT Tcl (which is `msvcrt`-based).
> Check with `objdump -p tcl90.dll | findstr /i "DLL Name"`. See `INSTALL.md`.

### Both Tcl generations at once

Each build produces a generation-specific library name
(`libtcllunasvg0.1.1.so` for 8.6, `libtcl9tcllunasvg0.1.1.so` for 9.0), so you
can install both into the same directory and `pkgIndex.tcl` loads the right one:

```bash
./configure --with-tcl=/usr/lib/tcl8.6 --with-lunasvg=… && make && sudo make install
make clean
./configure --with-tcl=/usr/lib/tcl9.0 --with-lunasvg=… && make && sudo make install
```

---

## License

BSD 2-Clause (see `LICENSE`).

The rendering side brings its own licences: **lunasvg** and **plutovg** are MIT,
and plutovg's rasteriser derives from FreeType, so parts of it are under the
**FreeType License**. That one asks for credit in the documentation of a binary
distribution:

> Portions of this software are copyright The FreeType Project
> (www.freetype.org). All rights reserved.

All of them are permissive and none of it changes with static versus dynamic
linking — only the reminder does. See
[THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md) for the details, including
the statically linked libstdc++ and the GCC Runtime Library Exception.
