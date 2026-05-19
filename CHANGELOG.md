# tcllunasvg Changelog

## v0.1.0 (2026-05-18) — Initial release

**Eigenständige Tcl-Erweiterung für lunasvg.**

Hervorgegangen aus der ehemaligen lunasvg-Integration in `tclmcairo`
(`src/lunasvg_wrap.cpp`, `#ifdef HAVE_LUNASVG`-Blöcke, `buildlt.sh`).
Diese Integration wird in tclmcairo 0.4.0 entfernt — siehe
`MIGRATION-FROM-LUNASVG-IN-TCLMCAIRO.md`.

### Review-driven Fixes (Stufe 1, vor GitHub-Release)

Folgende kleine Verbesserungen aus externen Code-Reviews, ohne API-Änderung:

- **`pkgIndex.tcl.in`**: robusteres Windows-DLL-Loading analog zu
  tclmcairo. PATH-Augmentation mit dem Paket-Verzeichnis plus
  explizites Pre-Load der Abhängigkeits-DLLs (liblunasvg.dll,
  libplutovg.dll, MinGW-Runtime). Macht das Laden unabhängig vom
  aktuellen Working-Directory.
- **`README.md`**: explizite Renderer-Entscheidungstabelle ergänzt
  (nanosvg vs svg2cairo vs tcllunasvg) und `-scale`-vs-`-width/-height`-
  Präzedenz klarer dokumentiert (-scale ignoriert die anderen statt
  zu "überschreiben").
- **`MIGRATION-FROM-LUNASVG-IN-TCLMCAIRO.md`**: Sync-Hinweis im Header
  zur Pflege der byte-identischen Kopie in `gregnix/tclmcairo`.
- `configure` jetzt im Release-ZIP enthalten (per `autoconf` generiert).

### Tcl-API

- **`tcllunasvg::load file|data ARG`** — lädt SVG-Dokument, gibt Handle zurück
- **`$doc width / height / size`** — Document-Dimensionen
- **`$doc apply_stylesheet CSS`** — zusätzliches CSS anwenden
- **`$doc to_png FILE ?opts?`** — PNG-Datei schreiben
- **`$doc to_argb32 ?opts?`** — ARGB32-Puffer als Dict zurückgeben
- **`$doc destroy`** — Freigabe
- **`tcllunasvg::version / version_number`** — lunasvg-Version
- **`tcllunasvg::font_add family bold italic file`** — Font-Cache erweitern
- **`tcllunasvg::file_to_png in out ?opts?`** — One-Shot

### Render-Optionen

`-width INT`, `-height INT`, `-scale FLOAT`, `-bg COLOR`

Farbformat: `0xAARRGGBB`, `#RRGGBB`, `#AARRGGBB`, `#RGB`, oder
`white`/`black`/`transparent`.

### Build

- TEA-basiert (`configure.in`, `Makefile.in`, `tclconfig/`)
- `--with-lunasvg=DIR` für expliziten Pfad
- pkg-config-Fallback wenn lunasvg systemweit installiert
- C++17 mit `-fPIC` (Linux x86_64 erfordert das für Shared Libraries)
- Eigene Plattform-Erkennung (`SHLIB_EXT`) — unabhängig von TEA's
  `@SHLIB_SUFFIX@`, das in BAWT-Tcl nicht zuverlässig substituiert wird
- **Auto-Repair für relokierte Tcl-Distributionen**: erkennt, wenn
  `tclConfig.sh` auf einen nicht-existenten Pfad zeigt (BAWT-Distributionen
  bauen ihre Build-Pfade fest ein), und ersetzt sie transparent durch
  `--with-tcl=PATH`. Damit funktioniert der Build out-of-the-box gegen
  BAWT, ohne `tclConfig.sh` händisch zu patchen.
- Stubs-basiert: kein `TEA_PRIVATE_TCL_HEADERS` nötig, also auch keine
  privaten Header-Pfade aus tclConfig.sh erforderlich
- Detection erkennt: `liblunasvg.dll` (MinGW), `liblunasvg.so` (Linux),
  `liblunasvg.dylib` (macOS), `lunasvg.dll` (MSVC), `liblunasvg.dll.a`
  (MinGW Import-Lib)
- `-static-libstdc++ -static-libgcc` für saubere Windows-Deployments

### Installation unter Windows

`make install` kopiert auf Windows neben `libtcllunasvg.dll` auch:

- `liblunasvg.dll` (SVG-Engine)
- `libplutovg.dll` (Vektor-Backend)
- `libstdc++-6.dll` (C++-Runtime aus UCRT64)
- `libgcc_s_seh-1.dll` (gcc Exception-Unwind)
- `libwinpthread-1.dll` (Threading)

Damit ist das Paket selbstgenügsam — vermeidet DLL-Hell mit anderen
Tcl-Erweiterungen, die ältere MinGW/MSYS2-Runtime-DLLs mitbringen.

### Plattformen

| Plattform | Status |
|-----------|--------|
| Linux (Debian, getestet) | ✓ 19/19 Tests, Demos OK |
| Windows MSYS2 UCRT64 | ✓ 19/19 Tests, Demos OK |
| Windows + System-Tcl (C:\Tcl) | ✓ funktioniert nach `make install` |
| macOS | nicht getestet, sollte aber funktionieren |

### Bekannte Einschränkungen

- **`<textPath>`** ist eine lunasvg-Limitation. Workaround: `svg2cairo`
  aus tclmcairo nutzen.
- **Tcl-Mismatch:** Bei mehreren parallel installierten Tcls muss
  tcllunasvg gegen das tatsächlich verwendete Tcl gebaut werden.
  Siehe `INSTALL.md`, Abschnitt "Tcl-Auswahl".

### Migration aus tclmcairo

```tcl
# Vorher (in tclmcairo mit HAVE_LUNASVG):
$ctx svg_file_luna "logo.svg" 100 200 -scale 2

# Nachher (entkoppelt):
set doc [tcllunasvg::load file "logo.svg"]
set img [$doc to_argb32 -scale 2]
$doc destroy
set img_id [$ctx image_from_argb32 \
    [dict get $img data] [dict get $img width] [dict get $img height]]
$ctx image_blit $img_id 100 200
$ctx image_free $img_id
```

Siehe `MIGRATION-FROM-LUNASVG-IN-TCLMCAIRO.md` für Details.
