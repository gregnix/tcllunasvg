# tcllunasvg Changelog

## v0.1.1 (2026-07-17) — Build: TEA-CXX + dual generation

Build-only update, **no change to the Tcl API**.

### TEA C++ conversion (tea-cxx)

- `configure.in` → **`configure.ac`**; `tclconfig/tea-cxx.m4` added.
- The hand-rolled C++ setup (`AC_PROG_CXX` + `AC_LANG_PUSH`) is replaced by
  **`TEA_SETUP_CXX`** + **`TEA_CXX_RUNTIME`** (placed after `TEA_CONFIG_CFLAGS`,
  because they rewrite `SHLIB_LD`). C++ standard via `--with-cxx-standard`
  (default 17).
- Linking now goes through **`SHLIB_LD`** (the C++ driver) instead of a
  hand-written `$(CXX) -shared`; `-static-libstdc++ -static-libgcc` come from
  `TEA_CXX_RUNTIME`, no longer hardcoded in `LDFLAGS`. `CXXFLAGS` come from TEA
  (`@CXXFLAGS@`) instead of a hardcoded `-O2 -std=c++17 -fPIC`.
- Portable `.cpp.@OBJEXT@` suffix rule instead of the GNU `%` pattern rule.

### Two Tcl generations side by side

- `TEA_MAKE_LIB` yields generation-aware library names: `libtcllunasvg0.1.1.so`
  (Tcl 8.6) and `libtcl9tcllunasvg0.1.1.so` (Tcl 9.0).
- Both may now be installed into the **same** package directory — `make install`
  no longer overwrites the other generation.
- `pkgIndex.tcl` picks the matching file at load time
  (`[package vsatisfies [package provide Tcl] 9-]`); a single `pkgIndex.tcl`
  serves both generations.
- **Supersedes** the 0.1.0 guidance to install "two builds, each into its own
  `lib/` directory" — one shared directory is enough.

### Other

- `configure` is committed to the repo (generated with `autoconf`); a normal
  build no longer needs `autoconf`.
- The `SHLIB_EXT` self-detection remains only for the Windows dependency DLLs;
  the main library name now comes from TEA (`@PKG_LIB_FILE@`).

## v0.1.0 (2026-05-18) — Initial release

**Standalone Tcl extension for lunasvg.**

Extracted from the former lunasvg integration in `tclmcairo`
(`src/lunasvg_wrap.cpp`, the `#ifdef HAVE_LUNASVG` blocks, `buildlt.sh`). That
integration is removed in tclmcairo 0.4.0 — see
`MIGRATION-FROM-LUNASVG-IN-TCLMCAIRO.md`.

### Review-driven fixes (stage 1, before the GitHub release)

Small improvements from external code reviews, without API change:

- **`pkgIndex.tcl.in`**: more robust Windows DLL loading, mirroring tclmcairo.
  PATH augmentation with the package directory plus an explicit pre-load of the
  dependency DLLs (liblunasvg.dll, libplutovg.dll, MinGW runtime). Makes loading
  independent of the current working directory.
- **`README.md`**: added an explicit renderer decision table (nanosvg vs
  svg2cairo vs tcllunasvg) and documented the `-scale` vs `-width/-height`
  precedence more clearly (`-scale` ignores the others rather than "overriding"
  them).
- **`MIGRATION-FROM-LUNASVG-IN-TCLMCAIRO.md`**: header note about keeping the
  byte-identical copy in `gregnix/tclmcairo` in sync.
- `configure` is now included in the release ZIP (generated with `autoconf`).

### Tcl API

- **`tcllunasvg::load file|data ARG`** — load an SVG document, returns a handle
- **`$doc width / height / size`** — document dimensions
- **`$doc apply_stylesheet CSS`** — apply additional CSS
- **`$doc to_png FILE ?opts?`** — write a PNG file
- **`$doc to_argb32 ?opts?`** — return an ARGB32 buffer as a dict
- **`$doc destroy`** — release
- **`tcllunasvg::version / version_number`** — lunasvg version
- **`tcllunasvg::font_add family bold italic file`** — extend the font cache
- **`tcllunasvg::file_to_png in out ?opts?`** — one-shot

### Render options

`-width INT`, `-height INT`, `-scale FLOAT`, `-bg COLOR`

Color format: `0xAARRGGBB`, `#RRGGBB`, `#AARRGGBB`, `#RGB`, or
`white`/`black`/`transparent`.

### Build

- TEA-based (`configure.in`, `Makefile.in`, `tclconfig/`)
- `--with-lunasvg=DIR` for an explicit path
- pkg-config fallback when lunasvg is installed system-wide
- C++17 with `-fPIC` (required for shared libraries on Linux x86_64)
- Own platform detection (`SHLIB_EXT`) — independent of TEA's `@SHLIB_SUFFIX@`,
  which is not reliably substituted in BAWT Tcl
- **Auto-repair for relocated Tcl distributions**: detects when `tclConfig.sh`
  points at a non-existent path (BAWT distributions bake their build paths in)
  and transparently replaces it with `--with-tcl=PATH`. The build then works
  out of the box against BAWT without patching `tclConfig.sh` by hand.
- Stubs-based: no `TEA_PRIVATE_TCL_HEADERS` needed, so no private header paths
  from tclConfig.sh are required
- Detection recognizes: `liblunasvg.dll` (MinGW), `liblunasvg.so` (Linux),
  `liblunasvg.dylib` (macOS), `lunasvg.dll` (MSVC), `liblunasvg.dll.a`
  (MinGW import lib)
- `-static-libstdc++ -static-libgcc` for clean Windows deployments

### Installation on Windows

On Windows, `make install` copies, alongside `libtcllunasvg.dll`, also:

- `liblunasvg.dll` (SVG engine)
- `libplutovg.dll` (vector backend)
- `libstdc++-6.dll` (C++ runtime from UCRT64)
- `libgcc_s_seh-1.dll` (gcc exception unwind)
- `libwinpthread-1.dll` (threading)

This makes the package self-contained — avoiding DLL hell with other Tcl
extensions that ship older MinGW/MSYS2 runtime DLLs.

### Platforms

| Platform | Status |
|----------|--------|
| Linux (Debian, tested) | ✓ 19/19 tests, demos OK |
| Windows MSYS2 UCRT64 | ✓ 19/19 tests, demos OK |
| Windows + system Tcl (C:\Tcl) | ✓ works after `make install` |
| macOS | untested, but should work |

### Known limitations

- **`<textPath>`** is a lunasvg limitation. Workaround: use `svg2cairo` from
  tclmcairo.
- **Tcl mismatch:** with several Tcls installed in parallel, tcllunasvg must be
  built against the Tcl that actually loads it. See `INSTALL.md`, section
  "Choosing the Tcl".

### Migration from tclmcairo

```tcl
# Before (in tclmcairo with HAVE_LUNASVG):
$ctx svg_file_luna "logo.svg" 100 200 -scale 2

# After (decoupled):
set doc [tcllunasvg::load file "logo.svg"]
set img [$doc to_argb32 -scale 2]
$doc destroy
set img_id [$ctx image_from_argb32 \
    [dict get $img data] [dict get $img width] [dict get $img height]]
$ctx image_blit $img_id 100 200
$ctx image_free $img_id
```

See `MIGRATION-FROM-LUNASVG-IN-TCLMCAIRO.md` for details.
