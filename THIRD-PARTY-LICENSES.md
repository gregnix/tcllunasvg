# Third-party licenses

What travels inside or beside a tcllunasvg build, and what has to be shipped
with it. This is a factual overview, not legal advice — when in doubt, read the
license files themselves; they are short.

## Components

| Component | License | How it is bound |
|---|---|---|
| **tcllunasvg** | BSD 2-Clause | this package |
| **lunasvg** | MIT (Samuel Ugochukwu) | shared library on the configure/make path, static on the MSVC path |
| **plutovg** | MIT (same author) | pulled in by lunasvg |
| parts of plutovg (`plutovg-ft-*.c/h`) | **FreeType License (FTL)** | inside plutovg |
| **libstdc++ / libgcc** | GPLv3 **with GCC Runtime Library Exception** | linked statically into the extension (`TEA_CXX_RUNTIME`) |
| Microsoft C runtime | Microsoft redistributable terms | dynamic (`/MD`) on the MSVC path only |

## Does static linking change the obligations?

Barely — and that is the point worth internalising. MIT, BSD and the FTL are all
permissive: they allow static linking without restricting the licence of the
result. What they require is **attribution**, and that requirement does not
depend on the linking model:

- **Dynamic:** `liblunasvg.so`/`.dll` and `libplutovg.so`/`.dll` are shipped as
  separate files. Their notices belong in the distribution.
- **Static:** the same code sits inside `libtcllunasvg….so`/`.dll`. That is
  distribution of "substantial portions" in binary form, so the same notices
  are required.

The practical difference is the risk of forgetting: with a separate DLL the file
is a reminder, with a static build nothing points at the third-party code any
more.

## FreeType parts in plutovg

plutovg's rasteriser derives from FreeType (`plutovg-ft-raster.c`,
`plutovg-ft-stroker.c`, `plutovg-ft-math.c`, with `FTL.TXT` alongside). The
FreeType License is BSD-style, with one requirement worth noting:

> credit must be given in the documentation of a binary distribution

So a distribution that contains plutovg — statically or as a DLL — should credit
The FreeType Project in its documentation, not only in a source file nobody
opens. The line below is enough:

> Portions of this software are copyright The FreeType Project
> (www.freetype.org). All rights reserved.

## The statically linked C++ runtime

`TEA_CXX_RUNTIME` adds `-static-libstdc++ -static-libgcc`, so libstdc++ and
libgcc end up inside the extension. Those libraries are GPLv3 — but with the
**GCC Runtime Library Exception**, which exists precisely for this: code
compiled with an "Eligible Compilation Process" (plain GCC, no proprietary
plugins that bypass GPL) may be distributed under the licence of your choice,
statically linked runtime included. A normal `g++` build qualifies.

On the MSVC path the question does not arise: the Microsoft CRT is bound
dynamically (`/MD`) and falls under Microsoft's redistributable terms.

## What a distribution should carry

- `LICENSE` of tcllunasvg (BSD 2-Clause)
- the MIT text of lunasvg and of plutovg — one copy each; both name the same
  copyright holder but are separate projects
- the FreeType credit line, or `FTL.TXT`
- nothing extra for libstdc++/libgcc thanks to the Runtime Library Exception

Shipping the three upstream licence files next to the package is the simplest
way to be done with it.
