# tcllunasvg — Installation

## Prerequisites

| Component | Version | Note |
|-----------|---------|------|
| Tcl        | 8.6 or 9.0 | stubs are used |
| C++ compiler | C++17 | g++ 7+ / clang 5+ |
| autoconf   | 2.69+   | Only needed if you change `configure.ac` — `configure` is included |
| make       | GNU make | |
| lunasvg    | 3.5+    | https://github.com/sammycage/lunasvg |
| cmake      | 3.15+   | Only to build lunasvg |

---

## Important: choosing the Tcl

If **several Tcl installations** exist in parallel on the system (e.g. a BAWT
Tcl under `C:\Bawt\` and a system Tcl under `C:\Tcl\`):

**The Tcl you build against here (`--with-tcl=...`) MUST be the same one that
loads the library later.**

Stubs absorb many compatibility problems, but **not all**: with different Tcls
there are subtle crashes in destructor paths (e.g. when a document handle is
released). This was observed concretely during 0.1.0 development.

If both Tcls are needed, build once per Tcl. Since 0.1.1 both may go into the
**same** package directory: the libraries carry the Tcl generation in their name
(`libtcllunasvg0.1.1.so` for 8.6, `libtcl9tcllunasvg0.1.1.so` for 9.0), and
`pkgIndex.tcl` loads the matching one. The flow:

```bash
./configure --with-tcl=/usr/lib/tcl8.6 --with-lunasvg=…
make && sudo make install
make clean
./configure --with-tcl=/usr/lib/tcl9.0 --with-lunasvg=…
make && sudo make install
```

### BAWT Tcl and similar distributions

Some Tcl distributions (BAWT, some vendor builds) bake the original build path
into `tclConfig.sh` and are then shipped under a different path. Symptom at link
time:

```
ld.exe: cannot find -ltclstub: No such file or directory
```

with a `-L` path pointing at a BAWT-internal build location that does not exist
on your system.

**tcllunasvg detects this automatically since 0.1.0**: if the `TCL_EXEC_PREFIX`
recorded in `tclConfig.sh` does not exist, but `--with-tcl=PATH/lib` names a
valid location, configure replaces the dead paths transparently. The configure
output reports it clearly:

```
configure: tclConfig.sh points to non-existent path:
configure:     /C/BawtBuilds/.../Install/Tcl
configure: rewriting to user-supplied --with-tcl prefix:
configure:     /c/Tcl903
```

No more patching `tclConfig.sh` by hand.

---

## Linux (Ubuntu/Debian/Fedora/Arch)

### Step 1 — build lunasvg (once)

```bash
mkdir -p ~/src && cd ~/src
git clone https://github.com/sammycage/lunasvg.git
cd lunasvg
cmake -B build_shared -DBUILD_SHARED_LIBS=ON .
cmake --build build_shared -j$(nproc)
```

Optionally install system-wide:

```bash
sudo cmake --install build_shared
sudo ldconfig
```

### Step 2 — build tcllunasvg

```bash
cd /path/to/tcllunasvg
./configure --with-tcl=/usr/lib/tcl8.6 \
            --with-lunasvg=$HOME/src/lunasvg
make
sudo make install
make test
```

If lunasvg was installed system-wide, `--with-lunasvg=...` can be omitted.

---

## Windows — match the C runtime first

Windows has **two** C runtimes, and the extension must be built with the **same
one** as the Tcl it will load into. Mixing them puts two C runtimes in one
process (separate heaps, `FILE*` tables, `errno`) — which stays quiet for a
stubs-only extension but crashes silently the moment a `FILE*` or a raw pointer
crosses the boundary.

- **`msvcrt.dll`** — the old runtime. **BAWT** distributions and their bundled
  MinGW use this.
- **UCRT** (`ucrtbase.dll`) — the modern one. **MSVC**-built Tcl uses it: the
  official Tcl Windows binaries and the Magicsplat distribution, and the MSYS2
  **UCRT64** toolchain.

tcllunasvg's own boundary is pure C (`to_argb32` returns a Tcl bytearray, `to_png`
writes internally), so nothing runtime-bound crosses it and a mismatch often
"works" — but match the runtime anyway; the failure mode is silent and late.

Check what your target Tcl links against:

```cmd
objdump -p tcl90.dll | findstr /i "DLL Name"
```

- `msvcrt.dll` → the BAWT world → build with the **BAWT MinGW** toolchain (see
  the BAWT section below).
- `ucrtbase.dll` / `api-ms-win-crt-*` → UCRT → build with **MSYS2 UCRT64** (next).

## Windows with MSYS2 UCRT64 (for MSVC / Magicsplat / official Tcl)

Use this path when the target Tcl is UCRT-based (see above). The **build** happens
from the MSYS2 UCRT64 Bash; classic CMD/PowerShell is supported for running.

### Step 1 — install MSYS2 packages

In the **MSYS2 UCRT64 shell** (not MINGW64, not MSYS):

```bash
pacman -S autoconf automake make pkgconf \
          mingw-w64-ucrt-x86_64-gcc \
          mingw-w64-ucrt-x86_64-cmake \
          mingw-w64-ucrt-x86_64-ninja
```

> **Why UCRT64?** All parts — lunasvg, tcllunasvg and the runtime DLLs — must
> come from the **same** MSYS2 world, otherwise you get DLL hell from
> incompatible `libstdc++-6.dll` versions. UCRT64 is the right world **when the
> target Tcl is also UCRT** (MSVC / Magicsplat / official). For a BAWT Tcl
> (msvcrt), use the BAWT MinGW toolchain instead — see the BAWT section below.

### Step 2 — build lunasvg

In MSYS2 UCRT64 Bash:

```bash
cd ~/src
git clone https://github.com/sammycage/lunasvg.git
cd lunasvg
cmake -B build_shared -DBUILD_SHARED_LIBS=ON .
cmake --build build_shared -j
```

> **Note:** the CMake generator switch `-G "MinGW Makefiles"` is **not** needed
> here — it does not even exist under UCRT64.

Result:
- `~/src/lunasvg/build_shared/liblunasvg.dll`
- `~/src/lunasvg/build_shared/plutovg/libplutovg.dll`

### Step 3 — build and install tcllunasvg

In MSYS2 UCRT64 Bash:

```bash
cd ~/src/tcllunasvg

# example: against system Tcl under C:\Tcl
./configure --with-tcl=/c/Tcl/lib \
            --with-lunasvg=$HOME/src/lunasvg

# or against BAWT Tcl
./configure --with-tcl=/c/Bawt/Bawt86/Windows/x64/Development/opt/Tcl/lib \
            --with-lunasvg=$HOME/src/lunasvg

make
make install     # also copies the runtime DLLs
make test        # 19/19 tests should be green
```

### What `make install` does on Windows

Copies into `$(prefix)/lib/tcltk/tcllunasvg<version>/`:

1. `libtcllunasvg0.1.1.dll` (Tcl 8.6) or `libtcl9tcllunasvg0.1.1.dll` (Tcl 9.0)
2. `pkgIndex.tcl`
3. `liblunasvg.dll` — SVG engine
4. `libplutovg.dll` — lunasvg's vector backend
5. `libstdc++-6.dll` — C++ runtime (from UCRT64)
6. `libgcc_s_seh-1.dll` — gcc exception unwind
7. `libwinpthread-1.dll` — threading support

This makes the package **self-contained**. Windows finds all required DLLs in the
same directory.

### Tcl 9.0

```bash
./configure --with-tcl=/path/to/tcl9.0/lib --with-lunasvg=$HOME/src/lunasvg
```

---

## Windows: building for a BAWT Tcl (msvcrt)

BAWT-built Tcl is **msvcrt**-based, so the extension must be msvcrt too. There are
two concrete ways.

### Option A — standalone, in an msvcrt MinGW

The MSYS2 **MINGW64** environment is msvcrt (unlike UCRT64), so build exactly as
in the UCRT64 section but from the **MINGW64** shell with the non-`ucrt` packages:

```bash
# in the MSYS2 MINGW64 shell (title bar says "MINGW64", not "UCRT64")
pacman -S autoconf automake make pkgconf \
          mingw-w64-x86_64-gcc \
          mingw-w64-x86_64-cmake \
          mingw-w64-x86_64-ninja

# lunasvg
cd ~/src
git clone https://github.com/sammycage/lunasvg.git
cd lunasvg
cmake -B build_shared -DBUILD_SHARED_LIBS=ON .
cmake --build build_shared -j

# tcllunasvg, against the BAWT Tcl
cd ~/src/tcllunasvg
./configure --with-tcl=/c/Bawt/Bawt86/Windows/x64/Development/opt/Tcl/lib \
            --with-lunasvg=$HOME/src/lunasvg
make
make install
make test
```

Both parts are now msvcrt, matching the BAWT Tcl. For a **byte-exact** match to
BAWT's own gcc, put BAWT's bundled toolchain first on `PATH` instead of MSYS2's:

```bash
export PATH="/c/Bawt/BawtBuild9.0.4/Tools/gcc14.2.0_x86_64-w64-mingw32/bin:$PATH"
```

For a stubs-only C boundary with static libstdc++ (as here) this exact match is
rarely necessary — MINGW64 msvcrt is enough.

### Option B — inside the BAWT build (no runtime question at all)

Add tcllunasvg to the BAWT build itself; then it is compiled with the same
toolchain and Tcl as the rest of the distribution. tcllunasvg is a TEA extension
that needs the C++ lunasvg library, so it takes **two** build files.

```tcl
# MyBawt/InputLibs/lunasvg.bawt  — the C++ dependency (CMake)
proc Init_lunasvg { libName libVersion } {
    SetLibHomepage     $libName "https://github.com/sammycage/lunasvg"
    SetLibDependencies $libName "CMake"
    SetPlatforms       $libName "All"
    SetWinCompilers    $libName "gcc"
}
proc Build_lunasvg { libName libVersion buildDir instDir devDir distDir } {
    if { [UseStage "Extract"    $libName] } { ExtractLibrary $libName $buildDir }
    if { [UseStage "Configure"  $libName] } {
        CMakeConfig $libName $buildDir $instDir "-DBUILD_SHARED_LIBS=ON"
    }
    if { [UseStage "Compile"    $libName] } { CMakeBuild $libName $buildDir $instDir }
    if { [UseStage "Distribute" $libName] } {
        LibFileCopy [file join $instDir lib] [file join $devDir  [GetTclDir]] "*" true
        LibFileCopy [file join $instDir lib] [file join $distDir [GetTclDir]] "*" true
    }
    return true
}
```

```tcl
# MyBawt/InputLibs/tcllunasvg.bawt  — the TEA extension
proc Init_tcllunasvg { libName libVersion } {
    SetLibHomepage     $libName "https://github.com/gregnix/tcllunasvg"
    SetLibDependencies $libName "lunasvg" "Tcl"   ;# lunasvg is built first
    SetPlatforms       $libName "All"
    SetWinCompilers    $libName "gcc"             ;# BAWT MinGW = msvcrt
}
proc Build_tcllunasvg { libName libVersion buildDir instDir devDir distDir } {
    if { [UseStage "Extract" $libName] } { ExtractLibrary $libName $buildDir }
    if { [UseStage "Configure" $libName] } {
        set cflags ""
        append cflags [GetPermissiveCFlags] " " [GetDarwinCFlags]
        set flags ""
        if { [string trim $cflags] ne "" } { append flags "CFLAGS='$cflags' " }
        # lunasvg was installed by its build file into devDir; point configure at
        # it. If a lunasvg.pc is on PKG_CONFIG_PATH, --with-lunasvg is optional.
        set luna [file join $devDir [GetTclDir]]
        TeaConfigTcl $libName $buildDir $instDir "$flags --with-lunasvg=$luna"
    }
    if { [UseStage "Compile" $libName] } {
        MSysBuild $libName $buildDir "install-binaries"
    }
    if { [UseStage "Distribute" $libName] } {
        StripLibraries "$instDir"
        LibFileCopy "$instDir" "$devDir/[GetTclDir]"  "*" true
        LibFileCopy "$instDir" "$distDir/[GetTclDir]" "*" true
    }
    return true
}
```

Register both in a setup file (with `Include "Tools.bawt"` so CMake is available,
and `Include "Tcl_Basic.bawt"`), then run the build. The surrounding scaffold —
the `MyBawt/` directory, the wrapper script, the setup file, and the
`--libdir`/`--setupdir` options — is covered in the *tcltk-bauen* handbook,
chapter "Eigene Pakete integrieren".

> **Note on the lunasvg path.** tcllunasvg's detection expects either a checkout
> layout (`$DIR/include/lunasvg.h` + `$DIR/build_shared/liblunasvg.*`) or a
> `pkg-config` entry. In the BAWT tree lunasvg lands under `devDir`, so adjust
> `--with-lunasvg` to where the headers and import library actually are, or rely
> on `pkg-config` — verify the `checking for lunasvg …` line in the configure log.

---

## Verification after installation

```tcl
% package require tcllunasvg
0.1.1
% tcllunasvg::version
3.5.0
% set doc [tcllunasvg::load data {<svg width="100" height="50" xmlns="http://www.w3.org/2000/svg"><rect width="100" height="50" fill="red"/></svg>}]
% $doc to_png "test.png"
% $doc destroy
```

---

## Troubleshooting

### `lunasvg not found`

`--with-lunasvg=DIR` does not point at the lunasvg checkout. Expected:

```
$LUNASVG_DIR/
├── include/lunasvg.h
└── build_shared/liblunasvg.{so,dll}
```

### `ld: cannot find -llunasvg` (Windows / MinGW)

The link fails even though `liblunasvg.dll` **and** `liblunasvg.dll.a` exist in
`build_shared/`. The cause is the **path type**: `--with-lunasvg=$HOME/src/lunasvg`
passes an MSYS path (`/home/you/...`), and the native MinGW `ld` cannot resolve a
`-L/home/...` search path (no drive letter → it looks under `C:\home\...`). The
Tcl stub lib still links because its path (`/C/Bawt/...`) carries a drive letter.

Fix: pass lunasvg as a **Windows path** via `cygpath -m`:

```bash
./configure --with-tcl=/c/Tcl/lib \
            --with-lunasvg=$(cygpath -m $HOME/src/lunasvg)
```

`cygpath -m` turns `/home/you/src/lunasvg` into `C:/msys64/home/you/src/lunasvg`,
which `ld` resolves. If the import library is missing entirely (only the `.dll`
is there), rebuild lunasvg with `-DCMAKE_SHARED_LINKER_FLAGS="-Wl,--out-implib,liblunasvg.dll.a"`.

### `couldn't load library "...tcllunasvg...dll": ... dependent library ... not found` (Windows)

The extension DLL is found, but a **dependency** (liblunasvg.dll, libplutovg.dll,
the MinGW runtime DLLs) is not on the search path. `make install` copies all of
them next to the extension, so the **installed** package loads fine; the error
typically appears only when loading from the build directory (e.g. `make test`),
where the dependencies do not sit alongside. Test the installed copy instead:

```tcl
% lappend auto_path C:/msys64/mingw64/lib/tcltk   ;# a Windows path, forward slashes
% package require tcllunasvg
```

Note two things when testing on Windows: use a **Windows path** (`C:/...`, not
`/mingw64/...` — Tcl's file access does not understand MSYS mounts), and use the
**same Tcl** the extension was built against (e.g. the BAWT `tclsh86.exe`, not the
MSYS2 Tcl).

### `The procedure entry point 'clock_gettime64' could not be located in the DLL libstdc++-6.dll`

**DLL hell**: Windows finds an older `libstdc++-6.dll` (e.g. from a MINGW64 build
of another package) before the newer UCRT64 one. `make install` resolves this by
copying the correct DLL locally. If the error still occurs, copy `libstdc++-6.dll`
from `/ucrt64/bin/` into the tcllunasvg install directory by hand.

### Crash on `$doc destroy` (the Tcl process exits without an error message)

Tcl mismatch between the build Tcl and the runtime Tcl. See the section
"Choosing the Tcl" above. Fix: build tcllunasvg against exactly the Tcl that will
load it.

### `package require tcllunasvg` → `can't find package tcllunasvg`

The Tcl does not have that directory in its `auto_path`. Verify:

```tcl
% puts $auto_path
```

If the install path is not in the list → set a different `--prefix`, or
`lappend auto_path "C:/.../lib"` before the `package require`.

### `cmake -G "MinGW Makefiles"` fails under UCRT64

That generator does not exist under UCRT64 — just drop the `-G` parameter (CMake
picks "Unix Makefiles" automatically).

---

## Uninstall

```bash
sudo rm -rf $(prefix)/lib/tcltk/tcllunasvg*
```
