#-----------------------------------------------------------------------
# Makefile.in -- tcllunasvg
# Wird durch ./configure zu Makefile generiert
#-----------------------------------------------------------------------

# -----------------------------------------------------------------------
# Plattform-Erkennung: Shared-Library-Suffix
# (eigen-detektiert, weil TEA's @SHLIB_SUFFIX@ nicht ueberall substituiert
#  wird — z.B. BAWT-Tcl unter Windows)
# -----------------------------------------------------------------------
ifeq ($(OS),Windows_NT)
    SHLIB_EXT  := .dll
    IS_WINDOWS := 1
else
    KERNEL := $(shell uname -s 2>/dev/null)
    ifeq ($(findstring MINGW,$(KERNEL)),MINGW)
        SHLIB_EXT  := .dll
        IS_WINDOWS := 1
    else ifeq ($(findstring CYGWIN,$(KERNEL)),CYGWIN)
        SHLIB_EXT  := .dll
        IS_WINDOWS := 1
    else ifeq ($(findstring MSYS,$(KERNEL)),MSYS)
        SHLIB_EXT  := .dll
        IS_WINDOWS := 1
    else ifeq ($(findstring UCRT,$(KERNEL)),UCRT)
        SHLIB_EXT  := .dll
        IS_WINDOWS := 1
    else ifeq ($(KERNEL),Darwin)
        SHLIB_EXT  := .dylib
        IS_WINDOWS := 0
    else
        SHLIB_EXT  := .so
        IS_WINDOWS := 0
    endif
endif

PKG_SOURCES  =  src/tcllunasvg.cpp
PKG_OBJECTS  = tcllunasvg.o

VPATH = ./src
PKG_TCL_SOURCES = 
PKG_HEADERS  = 
PKG_LIB_FILE = libtcllunasvg0.1.1.so
PKG_DIR      = $(PACKAGE_NAME)$(PACKAGE_VERSION)

PACKAGE_NAME    = tcllunasvg
PACKAGE_VERSION = 0.1.1

CC          = gcc
CXX         = g++
CLEANFILES  = 
EXEEXT      = 
OBJEXT      = o
RANLIB      = :
RANLIB_STUB = ranlib
SHLIB_LD    = ${CXX} ${CXXFLAGS} ${LDFLAGS_DEFAULT} -shared -static-libstdc++ -static-libgcc
SHLIB_LD_LIBS = ${LIBS} -L/usr/lib/x86_64-linux-gnu -ltclstub8.6
TCL_BIN_DIR = /usr/lib/tcl8.6
TCL_SRC_DIR = /usr/include/tcl8.6/tcl-private
TCL_VERSION = 8.6
TCLSH       ?= /usr/bin/tclsh8.6
INSTALL         = install
INSTALL_DATA    = install -m 644
INSTALL_PROGRAM = install -m 755

prefix      = /usr
exec_prefix = /usr
libdir      = $(prefix)/lib/tcltk
includedir  = ${prefix}/include
datarootdir = ${prefix}/share
datadir     = ${datarootdir}

PACKAGE_DIR = $(DESTDIR)$(libdir)/$(PKG_DIR)

PKG_CFLAGS  = 

INCLUDES    =  -I/home/greg/src/lunasvg/include -I"/usr/include/tcl8.6"
DEFINES     = -DPACKAGE_NAME=\"tcllunasvg\" -DPACKAGE_TARNAME=\"tcllunasvg\" -DPACKAGE_VERSION=\"0.1.1\" -DPACKAGE_STRING=\"tcllunasvg\ 0.1.1\" -DPACKAGE_BUGREPORT=\"\" -DPACKAGE_URL=\"\" -DBUILD_tcllunasvg=/\*\*/ -DHAVE_STDIO_H=1 -DHAVE_STDLIB_H=1 -DHAVE_STRING_H=1 -DHAVE_INTTYPES_H=1 -DHAVE_STDINT_H=1 -DHAVE_STRINGS_H=1 -DHAVE_SYS_STAT_H=1 -DHAVE_SYS_TYPES_H=1 -DHAVE_UNISTD_H=1 -DSTDC_HEADERS=1 -DTcl_Size=int -DUSE_THREAD_ALLOC=1 -D_REENTRANT=1 -D_THREAD_SAFE=1 -DTCL_THREADS=1 -DUSE_TCL_STUBS=1 -DUSE_TCLOO_STUBS=1 -DMODULE_SCOPE=extern\ __attribute__\(\(__visibility__\(\"hidden\"\)\)\) -DHAVE_HIDDEN=1 -DHAVE_CAST_TO_UNION=1 -DHAVE_STDBOOL_H=1 -DTCL_WIDE_INT_IS_LONG=1 -DTCL_CFG_OPTIMIZED=1 -DUSE_TCL_STUBS=1 -DTCL_MAJOR_VERSION=8 -DTK_MAJOR_VERSION=8 -DUSE_TCL_STUBS \
              -DPACKAGE_NAME=\"$(PACKAGE_NAME)\" \
              -DPACKAGE_VERSION=\"$(PACKAGE_VERSION)\"

# C++ flags computed by tea-cxx (TEA_SETUP_CXX): -std=c++NN plus TEA's
# CFLAGS_DEFAULT / CFLAGS_WARNING / SHLIB_CFLAGS (-O2 -Wall -fPIC). The component
# variables must be defined here, because  ${CXXFLAGS_STD} ${CFLAGS_DEFAULT} ${CFLAGS_WARNING} ${SHLIB_CFLAGS} references them by name.
CXXFLAGS_STD   = -std=c++17
CFLAGS_DEFAULT = -O2 -fomit-frame-pointer -DNDEBUG
CFLAGS_WARNING = -Wall
SHLIB_CFLAGS   = -fPIC
CXXFLAGS    =  ${CXXFLAGS_STD} ${CFLAGS_DEFAULT} ${CFLAGS_WARNING} ${SHLIB_CFLAGS} \
              $(INCLUDES) $(DEFINES) $(PKG_CFLAGS)

# The C++ driver and the static-runtime flags come from SHLIB_LD (tea-cxx:
# TEA_SETUP_CXX rewrites ${CC}->${CXX}, TEA_CXX_RUNTIME appends -static-libstdc++
# -static-libgcc). The libraries are split the TEA way:
#   PKG_LIBS       -- lunasvg (from TEA_ADD_LIBS)
#   SHLIB_LD_LIBS  -- Tcl stub lib, base libs, Windows link flags
# LDFLAGS is left empty for user-supplied -L/-l on the command line.
PKG_LIBS    =  -L/home/greg/src/lunasvg/build_shared -llunasvg
LDFLAGS     =

# Output-Dateiname mit Plattform-Suffix
# Generation-aware library name from TEA (TEA_MAKE_LIB):
#   Tcl 8.6 -> libtcllunasvg0.1.1.so       (libtcllunasvg0.1.1.so)
#   Tcl 9.0 -> libtcl9tcllunasvg0.1.1.so   (libtcl9tcllunasvg0.1.1.so)
# One ./configure + make per Tcl produces its own name, so both can live side by
# side in the same package directory; pkgIndex.tcl loads the matching one.
PKG_LIB_FILE8 = libtcllunasvg0.1.1.so
PKG_LIB_FILE9 = libtcl9tcllunasvg0.1.1.so
TCLLUNASVG_SO = libtcllunasvg0.1.1.so

# Pfade zu Laufzeit-Bibliotheken (lunasvg + plutovg) fuer test/demo
LUNASVG_BIN    = /home/greg/src/lunasvg/build_shared
LUNASVG_BIN_PV = /home/greg/src/lunasvg/build_shared/plutovg

# Quell-DLLs fuer das install-Target (Windows)
LUNASVG_DLL    = /home/greg/src/lunasvg/build_shared/liblunasvg.dll
PLUTOVG_DLL_1  = /home/greg/src/lunasvg/build_shared/libplutovg.dll
PLUTOVG_DLL_2  = /home/greg/src/lunasvg/build_shared/plutovg/libplutovg.dll

# UCRT64 Runtime-DLLs (nur Windows). Pfad ueber MSYS2_BIN override-bar.
MSYS2_BIN ?= /ucrt64/bin
RUNTIME_STDCPP    = $(MSYS2_BIN)/libstdc++-6.dll
RUNTIME_GCC_SEH   = $(MSYS2_BIN)/libgcc_s_seh-1.dll
RUNTIME_PTHREAD   = $(MSYS2_BIN)/libwinpthread-1.dll

# ================================================================
# Ziele
# ================================================================

.PHONY: all clean distclean install test binaries libraries demo

all: binaries libraries

binaries: $(TCLLUNASVG_SO)

libraries:

# Portable suffix rule (works with BSD make too). VPATH (above) makes the
# src/ sources reachable by base name.
.SUFFIXES: .cpp .o

.cpp.o:
	$(CXX) -c $(CXXFLAGS) $< -o $@

$(TCLLUNASVG_SO): $(PKG_OBJECTS)
	$(SHLIB_LD) -o $@ $(PKG_OBJECTS) $(PKG_LIBS) $(SHLIB_LD_LIBS) $(LDFLAGS)

# ================================================================
# Install
#
# Linux/macOS: nur libtcllunasvg.{so,dylib} und pkgIndex.tcl
# Windows:     plus liblunasvg.dll, libplutovg.dll, libstdc++-6.dll,
#              libgcc_s_seh-1.dll, libwinpthread-1.dll — damit das
#              Paket out-of-the-box ladbar ist, ohne dass irgendeine
#              andere DLL-Quelle (z.B. tclmcairo-Verzeichnis) im PATH
#              steht und falsche Versionen liefert.
# ================================================================

install: all
	@mkdir -p $(PACKAGE_DIR)
	@mkdir -p $(PACKAGE_DIR)/tcllunasvg
	$(INSTALL_PROGRAM) $(TCLLUNASVG_SO) $(PACKAGE_DIR)/
	$(INSTALL_DATA) pkgIndex.tcl $(PACKAGE_DIR)/
	@if [ -f ./tcl/compat-$(PACKAGE_VERSION).tm ]; then \
	    $(INSTALL_DATA) ./tcl/compat-$(PACKAGE_VERSION).tm \
	        $(PACKAGE_DIR)/tcllunasvg/; \
	fi
ifeq ($(IS_WINDOWS),1)
	@echo ""
	@echo "Windows: kopiere lunasvg + Runtime-DLLs nach $(PACKAGE_DIR)/"
	@if [ -f "$(LUNASVG_DLL)" ]; then \
	    cp "$(LUNASVG_DLL)" "$(PACKAGE_DIR)/" && echo "   OK: liblunasvg.dll"; \
	else \
	    echo "   WARN: $(LUNASVG_DLL) nicht gefunden — manuell kopieren!"; \
	fi
	@if [ -f "$(PLUTOVG_DLL_1)" ]; then \
	    cp "$(PLUTOVG_DLL_1)" "$(PACKAGE_DIR)/" && echo "   OK: libplutovg.dll"; \
	elif [ -f "$(PLUTOVG_DLL_2)" ]; then \
	    cp "$(PLUTOVG_DLL_2)" "$(PACKAGE_DIR)/" && echo "   OK: libplutovg.dll (aus plutovg/)"; \
	else \
	    echo "   INFO: libplutovg.dll nicht separat (evtl. statisch in liblunasvg eingebettet)"; \
	fi
	@for d in $(RUNTIME_STDCPP) $(RUNTIME_GCC_SEH) $(RUNTIME_PTHREAD); do \
	    if [ -f "$$d" ]; then \
	        cp "$$d" "$(PACKAGE_DIR)/" && echo "   OK: $$(basename $$d)"; \
	    else \
	        echo "   INFO: $$d nicht gefunden (mglw. statisch eingebettet)"; \
	    fi; \
	done
endif
	@echo ""
	@echo "tcllunasvg $(PACKAGE_VERSION) installed to:"
	@echo "    $(PACKAGE_DIR)"

# ================================================================
# Test — setzt PATH/LD_LIBRARY_PATH fuer lunasvg-DLLs
# ================================================================

test: all
	@echo "Running tests with $(TCLSH)..."
	@PATH="$(LUNASVG_BIN):$(LUNASVG_BIN_PV):$(PATH)" \
	 LD_LIBRARY_PATH="$(LUNASVG_BIN):$(LUNASVG_BIN_PV):$(LD_LIBRARY_PATH)" \
	 TCLLUNASVG_LIBDIR=. \
	 $(TCLSH) ./tests/all.tcl

demo: all
	@PATH="$(LUNASVG_BIN):$(LUNASVG_BIN_PV):$(PATH)" \
	 LD_LIBRARY_PATH="$(LUNASVG_BIN):$(LUNASVG_BIN_PV):$(LD_LIBRARY_PATH)" \
	 TCLLUNASVG_LIBDIR=. \
	 $(TCLSH) ./demos/demo-svg-png.tcl

# ================================================================
# Release-ZIP
# ================================================================

zip: distclean
	cd .. && zip -r tcllunasvg_$(PACKAGE_VERSION).zip tcllunasvg/ \
	    --exclude "*.git*" --exclude "*.bak" --exclude "*.o"
	@echo "Created: ../tcllunasvg_$(PACKAGE_VERSION).zip"

# ================================================================
# Clean
# ================================================================

clean:
	-rm -f $(TCLLUNASVG_SO) $(PKG_LIB_FILE8) $(PKG_LIB_FILE9) $(PKG_OBJECTS) $(CLEANFILES)
	-rm -f *.lib *.pdb *.exp

distclean: clean
	-rm -f Makefile pkgIndex.tcl config.cache config.log config.status
