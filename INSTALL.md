# tcllunasvg — Installation

## Voraussetzungen

| Komponente | Version | Anmerkung |
|------------|---------|-----------|
| Tcl        | 8.6 oder 9.0 | Stubs werden verwendet |
| C++-Compiler | C++17 | g++ 7+ / clang 5+ |
| autoconf   | 2.69+   | Generiert `configure` aus `configure.in` |
| make       | GNU make | |
| lunasvg    | 3.5+    | https://github.com/sammycage/lunasvg |
| cmake      | 3.15+   | Nur zum Bauen von lunasvg |

---

## Wichtig: Tcl-Auswahl

Wenn auf dem System **mehrere Tcl-Installationen** parallel existieren
(z. B. BAWT-Tcl unter `C:\Bawt\` und ein System-Tcl unter `C:\Tcl\`):

**Das Tcl, gegen das hier gebaut wird (`--with-tcl=...`), MUSS dasselbe
sein, das später die Lib lädt.**

Stubs fangen viele Kompatibilitätsprobleme ab, aber **nicht alle**: bei
unterschiedlichen Tcls gibt es subtile Crashes in Destruktor-Pfaden
(z. B. wenn ein Document-Handle freigegeben wird). Das ist während der
0.1.0-Entwicklung konkret beobachtet worden.

Wenn beide Tcls benötigt werden → zwei separate Builds, einer pro Tcl,
jeweils in das passende `lib/`-Verzeichnis installieren.

### BAWT-Tcl und ähnliche Distributionen

Einige Tcl-Distributionen (BAWT, manche Vendor-Builds) baken den
ursprünglichen Build-Pfad fest in `tclConfig.sh` ein und werden dann
unter einem anderen Pfad ausgeliefert. Symptom beim Linken:

```
ld.exe: cannot find -ltclstub: No such file or directory
```

mit einem `-L`-Pfad, der auf eine BAWT-interne Build-Location zeigt,
die auf deinem System nicht existiert.

**tcllunasvg erkennt das automatisch ab 0.1.0**: wenn der in
`tclConfig.sh` eingetragene `TCL_EXEC_PREFIX` nicht existiert, aber
`--with-tcl=PATH/lib` einen gültigen Ort angibt, ersetzt configure die
toten Pfade transparent. Die Configure-Ausgabe meldet das deutlich:

```
configure: tclConfig.sh points to non-existent path:
configure:     /C/BawtBuilds/.../Install/Tcl
configure: rewriting to user-supplied --with-tcl prefix:
configure:     /c/Tcl903
```

Kein händisches Patchen von `tclConfig.sh` mehr nötig.

---

## Linux (Ubuntu/Debian/Fedora/Arch)

### Schritt 1 — lunasvg bauen (einmalig)

```bash
mkdir -p ~/src && cd ~/src
git clone https://github.com/sammycage/lunasvg.git
cd lunasvg
cmake -B build_shared -DBUILD_SHARED_LIBS=ON .
cmake --build build_shared -j$(nproc)
```

Optional systemweit installieren:

```bash
sudo cmake --install build_shared
sudo ldconfig
```

### Schritt 2 — tcllunasvg bauen

```bash
cd /path/to/tcllunasvg
autoconf
./configure --with-tcl=/usr/lib/tcl8.6 \
            --with-lunasvg=$HOME/src/lunasvg
make
sudo make install
make test
```

Wenn lunasvg systemweit installiert wurde, kann `--with-lunasvg=...` weggelassen werden.

---

## Windows mit MSYS2 UCRT64

Empfohlene Umgebung. Klassische CMD/PowerShell wird unterstützt, aber der
**Build** erfolgt aus der MSYS2 UCRT64 Bash heraus.

### Schritt 1 — MSYS2-Pakete installieren

In der **MSYS2 UCRT64 Shell** (nicht MINGW64, nicht MSYS):

```bash
pacman -S autoconf automake make pkgconf \
          mingw-w64-ucrt-x86_64-gcc \
          mingw-w64-ucrt-x86_64-cmake \
          mingw-w64-ucrt-x86_64-ninja
```

> **Warum UCRT64?** UCRT64 ist die moderne, von MSYS2 empfohlene
> C-Runtime-Welt. lunasvg, tcllunasvg und alle Runtime-DLLs müssen aus
> **derselben** MSYS2-Welt stammen — sonst gibt es DLL-Hell durch
> inkompatible `libstdc++-6.dll`-Versionen.

### Schritt 2 — lunasvg bauen

In MSYS2 UCRT64 Bash:

```bash
cd ~/src
git clone https://github.com/sammycage/lunasvg.git
cd lunasvg
cmake -B build_shared -DBUILD_SHARED_LIBS=ON .
cmake --build build_shared -j
```

> **Hinweis:** Der CMake-Generator-Schalter `-G "MinGW Makefiles"` wird
> hier **nicht** gebraucht — den gibt es in UCRT64 ohnehin nicht.

Resultat:
- `~/src/lunasvg/build_shared/liblunasvg.dll`
- `~/src/lunasvg/build_shared/plutovg/libplutovg.dll`

### Schritt 3 — tcllunasvg bauen und installieren

In MSYS2 UCRT64 Bash:

```bash
cd ~/src/tcllunasvg
autoconf

# Beispiel: gegen System-Tcl unter C:\Tcl
./configure --with-tcl=/c/Tcl/lib \
            --with-lunasvg=$HOME/src/lunasvg

# oder gegen BAWT-Tcl
./configure --with-tcl=/c/Bawt/Bawt86/Windows/x64/Development/opt/Tcl/lib \
            --with-lunasvg=$HOME/src/lunasvg

make
make install     # kopiert auch Runtime-DLLs
make test        # 19/19 Tests sollten gruen sein
```

### Was `make install` unter Windows tut

Kopiert nach `$(prefix)/lib/tcltk/tcllunasvg<version>/`:

1. `libtcllunasvg.dll`
2. `pkgIndex.tcl`
3. `liblunasvg.dll` — SVG-Engine
4. `libplutovg.dll` — lunasvg's Vector-Backend
5. `libstdc++-6.dll` — C++-Runtime (aus UCRT64)
6. `libgcc_s_seh-1.dll` — gcc Exception-Unwind
7. `libwinpthread-1.dll` — Threading-Support

Damit ist das Paket **selbstgenügsam**. Windows findet alle benötigten
DLLs im selben Verzeichnis.

### Tcl 9.0

```bash
./configure --with-tcl=/path/to/tcl9.0/lib --with-lunasvg=$HOME/src/lunasvg
```

---

## Verifikation nach Installation

```tcl
% package require tcllunasvg
0.1.0
% tcllunasvg::version
3.5.0
% set doc [tcllunasvg::load data {<svg width="100" height="50" xmlns="http://www.w3.org/2000/svg"><rect width="100" height="50" fill="red"/></svg>}]
% $doc to_png "test.png"
% $doc destroy
```

---

## Troubleshooting

### `lunasvg not found`

`--with-lunasvg=DIR` zeigt nicht auf das Lunasvg-Checkout. Erwartet:

```
$LUNASVG_DIR/
├── include/lunasvg.h
└── build_shared/liblunasvg.{so,dll}
```

### `Der Prozedure-Einsprungpunkt 'clock_gettime64' wurde in der DLL libstdc++-6.dll nicht gefunden`

**DLL-Hell**: Windows findet eine ältere `libstdc++-6.dll` (z. B. aus einem
MINGW64-Build eines anderen Pakets) bevor die neuere UCRT64-Variante.
`make install` löst das durch lokale Kopie der korrekten DLL. Falls der
Fehler trotzdem auftritt, `libstdc++-6.dll` aus `/ucrt64/bin/` manuell
ins tcllunasvg-Installationsverzeichnis kopieren.

### Crash beim `$doc destroy` (Tcl-Prozess exitet ohne Fehlermeldung)

Tcl-Mismatch zwischen Build- und Lauf-Tcl. Siehe Abschnitt
"Tcl-Auswahl" oben. Lösung: tcllunasvg gegen genau das Tcl bauen, das
es laden soll.

### `package require tcllunasvg` → `can't find package tcllunasvg`

Das Tcl findet sein `auto_path` nicht in dem Verzeichnis. Verifizieren:

```tcl
% puts $auto_path
```

Falls der Installationspfad nicht in der Liste ist → anders `--prefix`
setzen, oder `lappend auto_path "C:/.../lib"` vor dem `package require`.

### `cmake -G "MinGW Makefiles"` schlägt unter UCRT64 fehl

Unter UCRT64 gibt es diesen Generator nicht — einfach den `-G`-Parameter
weglassen (CMake wählt automatisch "Unix Makefiles").

---

## Deinstallation

```bash
sudo rm -rf $(prefix)/lib/tcltk/tcllunasvg*
```
