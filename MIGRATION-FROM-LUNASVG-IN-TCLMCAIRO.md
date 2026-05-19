# Migration: lunasvg aus tclmcairo herausziehen → tcllunasvg

Stand: 2026-05-18 · betrifft tclmcairo 0.3.6 → 0.4.0

> **Hinweis zur Pflege:** Diese Datei existiert nahezu byte-identisch in
> **beiden** Repositories (`gregnix/tclmcairo` und `gregnix/tcllunasvg`).
> Wer sie ändert, **muss beide Kopien synchron halten** — sonst driften die
> Repos auseinander. Bei der nächsten Refaktorisierung sollte ein Symlink
> oder eine generierte Variante eingerichtet werden.

Diese Anleitung beschreibt die saubere Trennung der lunasvg-Integration
aus tclmcairo. Nach der Migration sind tcllunasvg und tclmcairo zwei
unabhängige Pakete — die Brücke sind ausschließlich ARGB32-Pixeldaten.

---

## Was in tclmcairo entfernt wird

### 1. Quelldateien

```
src/lunasvg_wrap.cpp                 KOMPLETT LÖSCHEN
src/lunasvg_wrap.o                   (build artifact)
buildlt.sh                           KOMPLETT LÖSCHEN
buildlt.bat (falls vorhanden)        KOMPLETT LÖSCHEN
nogit/lunasvg-build.md               in Archiv verschieben
```

### 2. Code-Stellen in `src/libtclmcairo.c`

**Forward declarations:**
```c
/* ENTFERNEN: */
#ifdef HAVE_LUNASVG
extern int LunaSvgFileCmd(...);
extern int LunaSvgDataCmd(...);
extern int LunaSvgSizeCmd(...);
#endif
```

**Feature-Tabelle:**
```c
/* ENTFERNEN: */
#ifdef HAVE_LUNASVG
    { "lunasvg",            1 },
    { "svg_file_luna",      1 },
    { "svg_data_luna",      1 },
    { "svg_size_luna",      1 },
#else
    ...
#endif
```

**Command-Wrapper:** Der komplette Block zwischen `#ifdef HAVE_LUNASVG`
und `#endif` löschen (CairoSvgFileLunaCmd, CairoSvgDataLunaCmd, CairoSvgSizeLunaCmd).

**Ensemble-Dispatch:**
```c
/* ENTFERNEN: */
#ifdef HAVE_LUNASVG
    else if (!strcmp(sub,"svg_file_luna"))    return CairoSvgFileLunaCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"svg_data_luna"))    return CairoSvgDataLunaCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"svg_size_luna"))    return CairoSvgSizeLunaCmd(cd,interp,objc,objv);
#endif
```

### 3. OO-Wrapper in `tcl/tclmcairo-*.tm`

```tcl
# ENTFERNEN:
method svg_file_luna {filename x y args}    { tclmcairo svg_file_luna $_id $filename $x $y {*}$args }
method svg_data_luna {svgdata  x y args}    { tclmcairo svg_data_luna $_id $svgdata  $x $y {*}$args }
```

### 4. Dokumentation und Tests

Alle Erwähnungen von `svg_file_luna`, `svg_data_luna`, `svg_size_luna`, `lunasvg`
aus README.md, INSTALL.md, docs/, CHANGELOG.md entfernen. Tests entsprechend
entfernen.

---

## Was in tclmcairo NEU dazukommt: `image_from_argb32`

Strukturell parallel zu `image_load`, nur dass die Pixel aus einem Tcl-Bytearray
kommen statt aus einer PNG-Datei.

### Tcl-Signatur

```tcl
set img_id [$ctx image_from_argb32 <bytes> <width> <height> ?<stride>?]
```

- `bytes`: bytearray, ARGB32 premultiplied
- `width`, `height`: Pixel-Dimensionen
- `stride`: optional. Default: `cairo_format_stride_for_width(...)`

Gibt eine Image-ID zurück — danach `image_blit`/`image_info`/`image_free`.

### C-Implementierung

In `src/libtclmcairo.c`:

```c
/* tclmcairo image_from_argb32 ctx_id bytes width height ?stride? -> image-id */
static int CairoImageFromArgb32Cmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 6 || objc > 7) {
        Tcl_WrongNumArgs(interp, 2, objv,
            "ctx_id bytes width height ?stride?");
        return TCL_ERROR;
    }
    int byteLen = 0;
    unsigned char *bytes = Tcl_GetByteArrayFromObj(objv[3], &byteLen);

    int w, h;
    if (Tcl_GetIntFromObj(interp, objv[4], &w) != TCL_OK) return TCL_ERROR;
    if (Tcl_GetIntFromObj(interp, objv[5], &h) != TCL_OK) return TCL_ERROR;

    int stride;
    if (objc == 7) {
        if (Tcl_GetIntFromObj(interp, objv[6], &stride) != TCL_OK)
            return TCL_ERROR;
    } else {
        stride = cairo_format_stride_for_width(CAIRO_FORMAT_ARGB32, w);
    }

    if (w <= 0 || h <= 0 || stride < w * 4) {
        Tcl_SetResult(interp,
            "image_from_argb32: invalid width/height/stride", TCL_STATIC);
        return TCL_ERROR;
    }
    if (byteLen < stride * h) {
        Tcl_SetObjResult(interp,
            Tcl_ObjPrintf("image_from_argb32: bytes too short: have %d, need %d",
                byteLen, stride * h));
        return TCL_ERROR;
    }

    /* WICHTIG: Buffer kopieren — cairo_image_surface_create_for_data
     * uebernimmt KEIN Ownership, und der Bytearray kann jederzeit
     * gefreed werden. ImgBuf bekommt die Kopie. */
    unsigned char *buf = (unsigned char*)ckalloc(stride * h);
    memcpy(buf, bytes, stride * h);

    cairo_surface_t *surf = cairo_image_surface_create_for_data(
        buf, CAIRO_FORMAT_ARGB32, w, h, stride);

    if (cairo_surface_status(surf) != CAIRO_STATUS_SUCCESS) {
        cairo_surface_destroy(surf);
        ckfree((char*)buf);
        Tcl_SetResult(interp,
            "image_from_argb32: could not create cairo surface", TCL_STATIC);
        return TCL_ERROR;
    }

    /* In Image-Pool registrieren — analog zu CairoImageLoadCmd:
     *   ImgBuf *b   = calloc(1, sizeof(ImgBuf));
     *   b->id       = g_next_img_id++;
     *   b->surf     = surf;
     *   b->backing  = buf;        // NEU: damit img_free den Buffer freigibt
     *   ...
     *
     * Im ImgBuf-Struct ergaenzen:
     *   unsigned char *backing;   // NULL bei image_load (cairo besitzt),
     *                             // != NULL bei image_from_argb32
     *
     * In img_free zusaetzlich:
     *   if (b->backing) { ckfree((char*)b->backing); }
     */
    ImgBuf *b = /* ... existing pool registration ... */;
    Tcl_SetObjResult(interp, Tcl_NewIntObj(b->id));
    return TCL_OK;
}
```

**Ensemble-Dispatch:**
```c
else if (!strcmp(sub,"image_from_argb32"))
    return CairoImageFromArgb32Cmd(cd,interp,objc,objv);
```

**Feature-Tabelle:**
```c
{ "image_from_argb32", 1 },
```

### OO-Wrapper

In `tcl/tclmcairo-*.tm`:

```tcl
method image_from_argb32 {bytes w h args}  {
    tclmcairo image_from_argb32 $_id $bytes $w $h {*}$args
}
```

### Buffer-Lifetime

`cairo_image_surface_create_for_data` übernimmt **kein Ownership** der
Pixel. Saubere Lösung: `ImgBuf` um ein `backing`-Feld erweitern, das
auf den mit `ckalloc` allokierten Puffer zeigt. `image_free` ruft dann
`ckfree(b->backing)` zusätzlich auf. Bei `image_load` bleibt `backing`
`NULL`, altes Verhalten unverändert.

---

## Anwendungsbeispiel nach Migration

```tcl
package require tcllunasvg
package require tclmcairo   ;# >= 0.4.0

set doc [tcllunasvg::load file "logo.svg"]
set img [$doc to_argb32 -scale 2 -bg transparent]
$doc destroy

set ctx [tclmcairo::new 800 600]
set img_id [$ctx image_from_argb32 \
    [dict get $img data] \
    [dict get $img width] \
    [dict get $img height]]

$ctx image_blit $img_id 100 200
$ctx image_free $img_id

$ctx save "page.pdf"
$ctx destroy
```

---

## CHANGELOG-Eintrag für tclmcairo 0.4.0

```markdown
## v0.4.0 (2026-MM-DD)

### BREAKING CHANGES

**`svg_file_luna` / `svg_data_luna` / `svg_size_luna` entfernt.**
Die lunasvg-Integration ist in ein eigenes Paket ausgelagert:
[tcllunasvg](https://github.com/gregnix/tcllunasvg).

`buildlt.sh` und `--with-lunasvg` Build-Optionen entfallen.

### Neu

**`$ctx image_from_argb32 bytes width height ?stride?`**
Lädt einen ARGB32-Premultiplied-Puffer als Cairo-Surface in den Image-Pool.

### Removed

- src/lunasvg_wrap.cpp
- buildlt.sh
- Feature-Flags: lunasvg, svg_file_luna, svg_data_luna, svg_size_luna
- nogit/lunasvg-build.md (ins Archiv)
```

---

## Verifikation nach Migration

```bash
cd /path/to/tclmcairo
grep -r "lunasvg\|HAVE_LUNASVG" src/ tests/ docs/ README.md INSTALL.md
# Erwartung: Treffer nur noch in CHANGELOG.md (historisch)

./configure --with-tcl=/usr/lib/tcl8.6
make
make test       # alle bisherigen Tests bestehen

# tcllunasvg unabhängig:
cd /path/to/tcllunasvg
./configure --with-tcl=/usr/lib/tcl8.6 --with-lunasvg=/path/to/lunasvg
make test       # 19/19

# End-to-end:
cd /path/to/tcllunasvg
make demo
```
