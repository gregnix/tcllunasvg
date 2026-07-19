#-----------------------------------------------------------------------
# configure.in -- tcllunasvg TEA Build-System
#
# tcllunasvg: SVG-Rendering fuer Tcl via lunasvg
#             (kein Tk, kein Cairo -- Output PNG-Datei oder ARGB32-Bytes)
#
# Build:
#   autoconf
#   ./configure --with-tcl=/usr/lib/tcl8.6 \
#               --with-lunasvg=/pfad/zum/lunasvg-checkout
#   make
#   make install
#   make test
#
# WICHTIG: Das Tcl, gegen das hier gebaut wird (--with-tcl), MUSS
# dasselbe sein, das nachher die Lib laedt. Bei mehreren parallel
# installierten Tcls (z. B. BAWT + System-Tcl) gibt es sonst subtile
# Crashes beim Aufraeumen — siehe INSTALL.md "Tcl-Auswahl".
#-----------------------------------------------------------------------

AC_INIT([tcllunasvg], [0.1.1])

TEA_INIT([3.9])

AC_CONFIG_AUX_DIR(tclconfig)

# Tcl-Konfiguration laden
TEA_PATH_TCLCONFIG
TEA_LOAD_TCLCONFIG

#--------------------------------------------------------------------
# tclConfig.sh Path-Repair fuer relokierte Tcl-Distributionen
#
# Manche Tcl-Distributionen (BAWT, manche vendor-builds) baken den
# urspruenglichen Build-Pfad fest in tclConfig.sh ein, werden dann
# aber an einen anderen Ort distribuiert. Resultat: TCL_EXEC_PREFIX
# zeigt auf ein nicht-existentes Verzeichnis, und der Linker findet
# weder libtclstub noch libtcl.
#
# Fix: wenn TCL_EXEC_PREFIX nicht existiert UND der User --with-tcl=PATH
# angegeben hat, ersetzen wir den toten Pfad transparent durch den
# echten Install-Root (Parent von --with-tcl).
#--------------------------------------------------------------------

if test -n "$with_tclconfig" -a ! -d "$TCL_EXEC_PREFIX"; then
    TCL_USER_PREFIX=`dirname "$with_tclconfig"`
    if test -d "$TCL_USER_PREFIX/lib"; then
        AC_MSG_NOTICE([tclConfig.sh points to non-existent path:])
        AC_MSG_NOTICE([    $TCL_EXEC_PREFIX])
        AC_MSG_NOTICE([rewriting to user-supplied --with-tcl prefix:])
        AC_MSG_NOTICE([    $TCL_USER_PREFIX])

        old_prefix="$TCL_EXEC_PREFIX"
        TCL_EXEC_PREFIX="$TCL_USER_PREFIX"
        TCL_PREFIX="$TCL_USER_PREFIX"

        # Auch in den vorgefertigten -L/-I Specs ersetzen
        TCL_LIB_SPEC=`echo "$TCL_LIB_SPEC" | sed "s|$old_prefix|$TCL_USER_PREFIX|g"`
        TCL_STUB_LIB_SPEC=`echo "$TCL_STUB_LIB_SPEC" | sed "s|$old_prefix|$TCL_USER_PREFIX|g"`
        TCL_INCLUDE_SPEC=`echo "$TCL_INCLUDE_SPEC" | sed "s|$old_prefix|$TCL_USER_PREFIX|g"`
        TCL_BIN_DIR=`echo "$TCL_BIN_DIR" | sed "s|$old_prefix|$TCL_USER_PREFIX|g"`
        TCL_LIB_FILE=`echo "$TCL_LIB_FILE" | sed "s|$old_prefix|$TCL_USER_PREFIX|g"`
        TCL_STUB_LIB_FILE=`echo "$TCL_STUB_LIB_FILE" | sed "s|$old_prefix|$TCL_USER_PREFIX|g"`

        AC_SUBST(TCL_EXEC_PREFIX)
        AC_SUBST(TCL_PREFIX)
        AC_SUBST(TCL_LIB_SPEC)
        AC_SUBST(TCL_STUB_LIB_SPEC)
        AC_SUBST(TCL_INCLUDE_SPEC)
        AC_SUBST(TCL_BIN_DIR)
        AC_SUBST(TCL_LIB_FILE)
        AC_SUBST(TCL_STUB_LIB_FILE)

        # WICHTIG: TEA_PUBLIC_TCL_HEADERS sucht selbststaendig nach tcl.h.
        # Wenn auf dem System ein anderer Tcl (anderer Major) System-Header
        # liefert (z.B. MSYS2 /ucrt64/include mit Tcl 8.6), waehrend die Lib
        # aus /c/Tcl903/lib Tcl 9.0 ist, dann wird ein inkompatibler
        # Hybrid-Build gebaut. Wir steuern hier explizit nach.
        if test -z "$with_tclinclude" -a -f "$TCL_USER_PREFIX/include/tcl.h"; then
            with_tclinclude="$TCL_USER_PREFIX/include"
            AC_MSG_NOTICE([using header dir from --with-tcl prefix:])
            AC_MSG_NOTICE([    $with_tclinclude])
        fi
    fi
fi

#--------------------------------------------------------------------
# Header directory: always prefer the one belonging to --with-tcl.
#
# TEA_PUBLIC_TCL_HEADERS searches for tcl.h on its own. On a machine with
# more than one Tcl -- MSYS2 carries Tcl 8.6 headers in /mingw64/include,
# while the build may target a Tcl 9 under /c/Tcl9.0.4 -- it can pick the
# wrong ones, and the result is a hybrid: Tcl 9 stubs, Tcl 8.6 headers.
# That compiles until the first Tcl 9 type appears:
#
#     error: 'Tcl_Size' was not declared in this scope
#
# So whenever --with-tcl names a prefix that carries its own headers, use
# those. The repair branch above does the same for relocated trees; this
# applies to healthy ones as well.
#--------------------------------------------------------------------

if test -n "$with_tclconfig" -a -z "$with_tclinclude"; then
    tea_tcl_prefix=`dirname "$with_tclconfig"`
    if test -f "$tea_tcl_prefix/include/tcl.h"; then
        with_tclinclude="$tea_tcl_prefix/include"
        AC_MSG_NOTICE([using Tcl headers from the --with-tcl prefix:])
        AC_MSG_NOTICE([    $with_tclinclude])
    fi
fi

# TCLSH_PROG ableiten (fuer 'make test'/'make demo')
if test -z "$TCLSH_PROG"; then
    for candidate in \
        "${TCL_EXEC_PREFIX}/bin/tclsh${TCL_VERSION}" \
        "${TCL_EXEC_PREFIX}/bin/tclsh${TCL_MAJOR_VERSION}.${TCL_MINOR_VERSION}" \
        "${TCL_EXEC_PREFIX}/bin/tclsh${TCL_MAJOR_VERSION}${TCL_MINOR_VERSION}.exe" \
        "${TCL_EXEC_PREFIX}/bin/tclsh.exe" \
        "${TCL_EXEC_PREFIX}/bin/tclsh" \
        ; do
        if test -x "$candidate"; then
            TCLSH_PROG="$candidate"
            break
        fi
    done
    if test -z "$TCLSH_PROG"; then
        TCLSH_PROG="tclsh"
    fi
fi
AC_SUBST(TCLSH_PROG)

TEA_PREFIX
TEA_SETUP_COMPILER

# Sources -- declared before the C flags are computed; no compiler needed here.
TEA_ADD_SOURCES([src/tcllunasvg.cpp])
TEA_ADD_HEADERS([])
TEA_ADD_TCL_SOURCES([])

TEA_PUBLIC_TCL_HEADERS
# TEA_PRIVATE_TCL_HEADERS -- removed: we use Tcl stubs (USE_TCL_STUBS), so no
# private headers (tclInt.h etc.) are needed; it would also fail when
# tclConfig.sh points at a non-existent build dir (relocated BAWT Tcls).

#--------------------------------------------------------------------
# Safety net: the headers just located must belong to the same Tcl as
# tclConfig.sh. Mixing them builds an extension that links Tcl 9 stubs
# against Tcl 8.6 declarations, which fails in confusing places -- the
# first Tcl 9 type reported missing is usually Tcl_Size.
#--------------------------------------------------------------------

AC_MSG_CHECKING([whether the Tcl headers match tclConfig.sh])
tea_hdr_dir=`echo "$TCL_INCLUDES" | sed -e 's|^-I||' -e 's|"||g' -e 's| .*||'`
if test -f "$tea_hdr_dir/tcl.h"; then
    # The define may be indented after the '#': "#   define TCL_MAJOR_VERSION 8"
    tea_hdr_major=`sed -n 's|^#[[:space:]]*define[[:space:]][[:space:]]*TCL_MAJOR_VERSION[^0-9]*\([0-9][0-9]*\).*|\1|p' "$tea_hdr_dir/tcl.h" | head -1`
    tea_hdr_minor=`sed -n 's|^#[[:space:]]*define[[:space:]][[:space:]]*TCL_MINOR_VERSION[^0-9]*\([0-9][0-9]*\).*|\1|p' "$tea_hdr_dir/tcl.h" | head -1`
    tea_hdr_version="$tea_hdr_major.$tea_hdr_minor"
    if test "$tea_hdr_version" != "$TCL_VERSION"; then
        AC_MSG_RESULT([no])
        AC_MSG_ERROR([Tcl headers and library do not match.

tclConfig.sh reports Tcl $TCL_VERSION   ($with_tclconfig)
the headers found are Tcl $tea_hdr_version   ($tea_hdr_dir)

This happens when several Tcl versions live on the machine -- MSYS2 keeps
Tcl 8.6 headers in /mingw64/include, for instance. Point configure at the
matching headers:

    ./configure --with-tcl=DIR/lib --with-tclinclude=DIR/include
])
    fi
    AC_MSG_RESULT([yes ($tea_hdr_version)])
else
    AC_MSG_RESULT([cannot tell, no tcl.h under $tea_hdr_dir])
fi

TEA_ENABLE_THREADS
TEA_ENABLE_SHARED
TEA_CONFIG_CFLAGS
TEA_ENABLE_SYMBOLS

#--------------------------------------------------------------------
# C++ support (tea-cxx).
#
# tcl.m4 sets up only a C compiler. TEA_SETUP_CXX adds the C++ compiler and
# rewrites SHLIB_LD to link with it; TEA_CXX_RUNTIME links the C++ runtime
# statically (-static-libstdc++), so the extension carries no libstdc++
# dependency on the target -- important for single-file / zipkit builds.
#
# Both MUST come AFTER TEA_CONFIG_CFLAGS, because they rewrite the SHLIB_LD
# that macro computed. lunasvg is C++17 (the default of --with-cxx-standard).
#--------------------------------------------------------------------

TEA_SETUP_CXX
TEA_CXX_RUNTIME

#--------------------------------------------------------------------
# lunasvg detection runs in C++ mode, using the compiler TEA_SETUP_CXX set up.
# The probes need an *expandable* CXXFLAGS; the TEA-built CXXFLAGS holds make
# variable references (${CXXFLAGS_STD} …) that only resolve at build time, so
# use a clean value (just the -std flag) for the tests and restore it after.
#--------------------------------------------------------------------

AC_LANG_PUSH([C++])
tea_luna_save_CXXFLAGS="$CXXFLAGS"
CXXFLAGS="$CXXFLAGS_STD"

#--------------------------------------------------------------------
# lunasvg-Suche
#
# Suchreihenfolge:
#   1. --with-lunasvg=DIR  (explizit)
#   2. pkg-config          (systemweit installiert)
#   3. AC_LINK_IFELSE      (Default-Pfade)
#
# Bibliotheks-Dateinamen, die wir erkennen:
#   liblunasvg.so      Linux
#   liblunasvg.dylib   macOS
#   liblunasvg.dll     MinGW / MSYS2 (UCRT64, MINGW64)
#   lunasvg.dll        MSVC
#   liblunasvg.dll.a   MinGW Import-Library
#   liblunasvg.a       statisch
#--------------------------------------------------------------------

LUNASVG_CFLAGS=""
LUNASVG_LIBS=""
LUNASVG_FOUND="no"
LUNASVG_LIBDIR=""

AC_ARG_WITH([lunasvg],
    [AS_HELP_STRING([--with-lunasvg=DIR],
        [path to lunasvg checkout/build (with include/ and build_shared/)])],
    [LUNASVG_DIR=$withval],
    [LUNASVG_DIR=""])

AC_SUBST(LUNASVG_DIR)

# Strategie 1: expliziter Pfad
if test -n "$LUNASVG_DIR"; then
    AC_MSG_CHECKING([for lunasvg in $LUNASVG_DIR])
    if test -f "$LUNASVG_DIR/include/lunasvg.h"; then
        LUNASVG_CFLAGS="-I$LUNASVG_DIR/include"
        for d in "$LUNASVG_DIR/build_shared" \
                 "$LUNASVG_DIR/build" \
                 "$LUNASVG_DIR/lib" \
                 "$LUNASVG_DIR"; do
            for libname in liblunasvg.dll liblunasvg.so liblunasvg.dylib \
                           lunasvg.dll liblunasvg.dll.a liblunasvg.a; do
                if test -f "$d/$libname"; then
                    LUNASVG_LIBS="-L$d -llunasvg"
                    LUNASVG_FOUND="yes"
                    LUNASVG_LIBDIR="$d"
                    LUNASVG_LIBNAME="$libname"
                    break 2
                fi
            done
        done
        if test "$LUNASVG_FOUND" = "yes"; then
            AC_MSG_RESULT([yes ($LUNASVG_LIBDIR/$LUNASVG_LIBNAME)])
        else
            AC_MSG_RESULT([header found but no library in build_shared/build/lib])
            AC_MSG_ERROR([build lunasvg first:
       cd $LUNASVG_DIR
       cmake -B build_shared -DBUILD_SHARED_LIBS=ON .
       cmake --build build_shared])
        fi
    else
        AC_MSG_RESULT([no])
        AC_MSG_ERROR([lunasvg.h not found in $LUNASVG_DIR/include])
    fi
fi

# Strategie 2: pkg-config
if test "$LUNASVG_FOUND" = "no"; then
    AC_MSG_CHECKING([for lunasvg via pkg-config])
    if pkg-config --exists lunasvg 2>/dev/null; then
        LUNASVG_CFLAGS=`pkg-config lunasvg --cflags`
        LUNASVG_LIBS=`pkg-config lunasvg --libs`
        luna_ver=`pkg-config lunasvg --modversion`
        LUNASVG_FOUND="yes"
        AC_MSG_RESULT([yes (pkg-config: $luna_ver)])
    else
        AC_MSG_RESULT([no])
    fi
fi

# Strategie 3: Standard-Suchpfade
if test "$LUNASVG_FOUND" = "no"; then
    AC_MSG_CHECKING([for system-installed lunasvg])
    ac_save_CXXFLAGS="$CXXFLAGS"
    ac_save_LIBS="$LIBS"
    LIBS="$LIBS -llunasvg"
    AC_LINK_IFELSE([AC_LANG_PROGRAM(
        [[#include <lunasvg.h>]],
        [[(void)lunasvg_version();]])],
        [LUNASVG_LIBS="-llunasvg"
         LUNASVG_FOUND="yes"
         AC_MSG_RESULT([yes])],
        [AC_MSG_RESULT([no])])
    CXXFLAGS="$ac_save_CXXFLAGS"
    LIBS="$ac_save_LIBS"
fi

if test "$LUNASVG_FOUND" = "no"; then
    AC_MSG_ERROR([lunasvg not found.
       Either: install lunasvg system-wide, or
       pass:   --with-lunasvg=/path/to/lunasvg/checkout
       Build lunasvg first via:
          cmake -B build_shared -DBUILD_SHARED_LIBS=ON .
          cmake --build build_shared])
fi

# Header-Sanity-Check
ac_save_CXXFLAGS="$CXXFLAGS"
CXXFLAGS="$CXXFLAGS $LUNASVG_CFLAGS"
AC_CHECK_HEADER([lunasvg.h], [], [
    AC_MSG_ERROR([lunasvg.h not usable with current CFLAGS])
])

# Version pruefen.
#
# Bis hierher ist nur belegt, dass ein lunasvg da ist -- nicht, welches. Die
# Suche prueft, ob Header und Bibliothek existieren; ein lunasvg 2.x besteht
# das und laesst dann den Compiler mit C++-Fehlern auflaufen, weil Document
# und Bitmap dort anders aussehen. Die Versionsmakros beantworten das vorher.
# Der Praeprozessor ist dafuer zuverlaessiger als sed: er benutzt genau den
# Include-Pfad, der spaeter beim Uebersetzen gilt. Fehlt das Makro ganz (2.x
# kennt es nicht), wertet der Praeprozessor es als 0 -- die Bedingung greift.
AC_MSG_CHECKING([whether lunasvg is new enough (3.5+)])
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
#include <lunasvg.h>
#if !defined(LUNASVG_VERSION_MAJOR)
#  error "no version macros -- lunasvg 2.x or older"
#endif
#if LUNASVG_VERSION_MAJOR < 3 || (LUNASVG_VERSION_MAJOR == 3 && LUNASVG_VERSION_MINOR < 5)
#  error "lunasvg older than 3.5"
#endif
]], [[]])],
    [AC_MSG_RESULT([yes])],
    [AC_MSG_RESULT([no])
     AC_MSG_ERROR([lunasvg 3.5 or newer is required.

The headers found are older, or come from the 2.x series whose Document and
Bitmap classes differ. Building would fail with C++ errors that do not name
the real cause.

    git clone --depth=1 --branch v3.5.0 https://github.com/sammycage/lunasvg
])])
CXXFLAGS="$ac_save_CXXFLAGS"


CXXFLAGS="$tea_luna_save_CXXFLAGS"
AC_LANG_POP([C++])

# Erkannte Flags an Makefile durchreichen
TEA_ADD_INCLUDES([$LUNASVG_CFLAGS])
TEA_ADD_LIBS([$LUNASVG_LIBS])

AC_DEFINE(USE_TCL_STUBS, 1, [Use Tcl stubs])

TEA_MAKE_LIB

TEA_PROG_TCLSH

AC_CONFIG_FILES([Makefile pkgIndex.tcl])
AC_OUTPUT
