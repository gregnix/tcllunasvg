# tcllunasvg — SVG-Rendering für Tcl

Tcl-Binding für [lunasvg](https://github.com/sammycage/lunasvg) — rendert SVG
zu PNG-Dateien oder ARGB32-Pixelpuffern. **Kein Tk, kein Cairo erforderlich**:
läuft im reinen `tclsh`.

**Version:** 0.1.0 · **License:** BSD-2-Clause · **Tcl:** 8.6 / 9.0
**Output:** PNG-Datei, ARGB32-Byte-Buffer
**Plattformen:** Linux, Windows (MSYS2 UCRT64), macOS (ungetestet)

---

## Was ist tcllunasvg?

Eine **eigenständige, schlanke Tcl-Erweiterung** für SVG-Rendering.
Hervorgegangen aus der ehemaligen lunasvg-Integration in `tclmcairo` —
jetzt sauber getrennt, ohne C-Level-Kopplung an Cairo oder Tk.

Wenn ein Workflow das gerenderte SVG **mit Cairo** weiterverarbeiten will,
liefert `to_argb32` einen Byte-Puffer, den `tclmcairo` über sein
`image_from_argb32`-API (ab tclmcairo 0.4.0) aufnehmen kann. Tk-basierte
Anwendungen können den PNG-Output direkt mit `image create photo` laden.

---

## Schnellstart

### PNG aus SVG erzeugen (One-Shot)

```tcl
package require tcllunasvg
tcllunasvg::file_to_png "logo.svg" "logo.png" -scale 2
```

### Document-Handle für mehrfache Renderings

```tcl
package require tcllunasvg

set doc [tcllunasvg::load file "diagramm.svg"]
puts "SVG-Größe: [$doc size]"

$doc to_png "small.png"   -width  200
$doc to_png "large.png"   -scale  3.0
$doc to_png "labeled.png" -scale  2.0 -bg white

$doc destroy
```

### SVG aus Tcl-String rendern

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

### ARGB32-Pixel an tclmcairo weitergeben

```tcl
package require tcllunasvg
package require tclmcairo

# 1. SVG rendern
set doc [tcllunasvg::load file "icon.svg"]
set img [$doc to_argb32 -scale 4]
$doc destroy

# 2. Pixel in tclmcairo-Kontext laden, platzieren, freigeben
set ctx [tclmcairo::new 800 600]
$ctx clear 1 1 1
set img_id [$ctx image_from_argb32 \
    [dict get $img data] [dict get $img width] [dict get $img height]]
$ctx image_blit $img_id 100 100
$ctx image_free $img_id
$ctx save "page.pdf"
$ctx destroy
```

> **Hinweis:** `tclmcairo::image_from_argb32` kommt mit tclmcairo 0.4.0.
> Bis dahin nutzt `demos/demo-svg-argb32-tclmcairo.tcl` automatisch einen
> PNG-Fallback-Pfad.

---

## Tcl-API-Referenz

### `tcllunasvg::load <file|data> <argument>`

Lädt ein SVG-Dokument. Gibt einen **Handle-Befehl** zurück.

```tcl
set doc [tcllunasvg::load file "logo.svg"]
set doc [tcllunasvg::load data $svgstring]
```

### `$doc width` / `$doc height` / `$doc size`

Liefert die Dokument-Dimensionen aus dem SVG-`viewBox`-Attribut.

### `$doc apply_stylesheet <css>`

Wendet zusätzliches CSS auf das Dokument an.

### `$doc to_png <filename> ?-width W? ?-height H? ?-scale S? ?-bg COLOR?`

Rendert und schreibt PNG. PNG-Encoding macht lunasvg selbst.

### `$doc to_argb32 ?-width W? ?-height H? ?-scale S? ?-bg COLOR?`

Rendert in einen ARGB32-Premultiplied-Byte-Puffer. Gibt Dict zurück
mit Schlüsseln `width`, `height`, `stride`, `data`.

### `$doc destroy`

Gibt das Dokument frei.

### Optionen

| Option | Werte | Bedeutung |
|--------|-------|-----------|
| `-width W` | int >= 1 | Ziel-Breite in Pixeln |
| `-height H` | int >= 1 | Ziel-Höhe in Pixeln |
| `-scale S` | float > 0 | Multiplikator auf intrinsische SVG-Größe |
| `-bg COLOR` | Farbliteral | Hintergrund |

**Prioritäten für die Zielgröße** (wichtig zu beachten):

1. Wird `-scale S` angegeben, dann ist die Ausgabegröße **immer**
   `S * SVG-intrinsische_größe`. `-width` und `-height` werden in
   diesem Fall **ignoriert** (kein Fehler, nur ignoriert).
2. Sonst, wenn `-width` und/oder `-height` angegeben: diese
   bestimmen die Zielgröße (fehlende Dimension wird proportional
   skaliert).
3. Sonst: 1:1 zur intrinsischen SVG-Größe.

**Farbliterale:** `0xAARRGGBB`, `#RRGGBB`, `#AARRGGBB`, `#RGB`, oder
`white` / `black` / `transparent`.

---

### Utility-Befehle

#### `tcllunasvg::version`
Liefert die lunasvg-Version (z. B. `"3.5.0"`).

#### `tcllunasvg::version_number`
Liefert die Version als Integer (z. B. `30500`).

#### `tcllunasvg::font_add <family> <bold> <italic> <filename>`

Registriert eine TTF/OTF-Datei im lunasvg-Font-Cache.

```tcl
tcllunasvg::font_add "DejaVu Sans" 0 0 "/usr/share/fonts/dejavu/DejaVuSans.ttf"
```

#### `tcllunasvg::file_to_png <in.svg> <out.png> ?opts?`

Bequemer One-Shot ohne Handle.

---

## Was tcllunasvg **nicht** macht

- **Kein `<textPath>`** — lunasvg-Upstream-Limitation. Workaround:
  `svg2cairo` aus tclmcairo.
- **Kein In-Place-SVG-DOM-Editing** — laden, rendern, fertig.
- **Kein Tk-Photo-Image-Output** — bewusst. PNG schreiben und mit
  `image create photo -file out.png` laden.

---

## Verwandte Pakete

- **[lunasvg](https://github.com/sammycage/lunasvg)** — zugrundeliegende
  C++-Library (3.5+).
- **[tclmcairo](https://github.com/gregnix/tclmcairo)** — Cairo-Binding für Tcl.
  Konsumiert ARGB32-Output via `image_from_argb32` (ab 0.4.0).
- **svg2cairo** (Teil von tclmcairo) — Tcl-basierter SVG-Renderer auf Cairo,
  deckt textPath ab.

### Welchen Renderer wählen?

Im tclmcairo-Ökosystem stehen drei SVG-Renderer-Pfade zur Verfügung:

| Renderer | Aus Paket | CSS | `<text>` | `<textPath>` | `<marker>` / `<use>` | Extra-Deps |
|----------|-----------|-----|----------|--------------|----------------------|------------|
| `tclmcairo::svg_file` / `svg_data` | tclmcairo (nanosvg) | ✗ | ✗ | ✗ | partial | keine |
| `svg2cairo::render` | tclmcairo | ✓ | ✓ | ✓ fallback | ✗ | tDOM |
| `tcllunasvg` (dieses Paket) → `image_from_argb32` | tcllunasvg + tclmcairo | ✓ | ✓ | ✗ upstream | ✓ | lunasvg DLL |

**tcllunasvg lohnt sich,** wenn das SVG `<marker>`, `<use>`, `<clipPath>`,
Gradienten in `<defs>`, oder eingebettete `<image>`-Elemente enthält, die
nanosvg und svg2cairo nicht durchrendern. Für reines `<textPath>` ist
svg2cairo nach wie vor der einzige Weg.

---

## Build / Installation

Siehe `INSTALL.md`. Kurz:

**Linux:**
```bash
autoconf
./configure --with-tcl=/usr/lib/tcl8.6 --with-lunasvg=$HOME/src/lunasvg
make && sudo make install && make test
```

**Windows MSYS2 UCRT64:**
```bash
autoconf
./configure --with-tcl=/c/Tcl/lib --with-lunasvg=$HOME/src/lunasvg
make && make install && make test
```

`make install` unter Windows kopiert alle benötigten DLLs ins Paket-Verzeichnis.

---

## Lizenz

BSD 2-Clause (siehe `LICENSE`). Lunasvg selbst ist MIT-lizenziert.
