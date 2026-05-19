#!/usr/bin/env tclsh
# tests/all.tcl -- tcllunasvg test runner

set script_dir [file dirname [info script]]

# Allow running before install: TCLLUNASVG_LIBDIR points to build dir
if {[info exists ::env(TCLLUNASVG_LIBDIR)]} {
    set ::auto_path [linsert $::auto_path 0 $::env(TCLLUNASVG_LIBDIR)]
}

package require tcltest 2.5
namespace import ::tcltest::*

configure -testdir $script_dir -verbose {body error}

runAllTests
