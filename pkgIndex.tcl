# pkgIndex.tcl.in -- tcllunasvg
# Wird durch ./configure zu pkgIndex.tcl substituiert.
#
# Auf Windows enthaelt das Paket-Verzeichnis die Abhaengigkeits-DLLs
# (liblunasvg.dll, libplutovg.dll, libstdc++-6.dll, libgcc_s_seh-1.dll,
# libwinpthread-1.dll). Diese werden temporaer auf den PATH gehaengt,
# damit der Windows-Loader sie findet, wenn libtcllunasvg.dll geladen
# wird -- unabhaengig vom aktuellen Arbeitsverzeichnis.

if {![package vsatisfies [package provide Tcl] 8.6-]} { return }

package ifneeded tcllunasvg 0.1.1 [list apply {{dir} {
    if {$::tcl_platform(platform) eq "windows"} {
        # DLL-Verzeichnis temporaer in den PATH einfuegen, damit Windows
        # die Abhaengigkeiten beim Laden von libtcllunasvg.dll findet.
        set _oldpath $::env(PATH)
        set ::env(PATH) "$dir;$_oldpath"

        # Explizites Vor-Laden der Abhaengigkeiten mit absoluten Pfaden:
        # robuster als nur PATH-Aenderung, falls Windows die DLL aus dem
        # System32 oder einer anderen Lokation zuerst auswaehlen wuerde.
        foreach dep {
            libwinpthread-1.dll
            libgcc_s_seh-1.dll
            libstdc++-6.dll
            libplutovg.dll
            liblunasvg.dll
        } {
            set p [file join $dir $dep]
            if {[file exists $p]} { catch {load $p} }
        }
    }

    # Load the binary built for this Tcl generation. The 8.6 and 9.0 stub ABIs
    # are incompatible, so each generation gets its own file; both can be
    # installed in this directory at once (libtcllunasvg0.1.1.so / libtcl9tcllunasvg0.1.1.so).
    if {[package vsatisfies [package provide Tcl] 9-]} {
        set lib [file join $dir libtcl9tcllunasvg0.1.1.so]
    } else {
        set lib [file join $dir libtcllunasvg0.1.1.so]
    }
    load $lib Tcllunasvg

    if {$::tcl_platform(platform) eq "windows"} {
        # PATH zuruecksetzen -- die DLL ist geladen, weitere Abhaengigkeiten
        # nicht mehr noetig.
        set ::env(PATH) $_oldpath
    }
}} $dir]
