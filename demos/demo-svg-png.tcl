#!/usr/bin/env tclsh
# demos/demo-svg-png.tcl
#
# Einfachster Anwendungsfall: SVG laden, als PNG schreiben.
# Zeigt beide Wege — One-Shot (file_to_png) und Document-Handle.

if {[info exists ::env(TCLLUNASVG_LIBDIR)]} {
    set ::auto_path [linsert $::auto_path 0 $::env(TCLLUNASVG_LIBDIR)]
}

package require tcllunasvg

set demo_dir [file dirname [info script]]
set out_dir  [file join $demo_dir tmp]
file mkdir $out_dir

# Inline-SVG für die Demo (kein externer Asset nötig)
set svg_data {<?xml version="1.0" encoding="UTF-8"?>
<svg width="400" height="200" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0%"   stop-color="#4078c0"/>
      <stop offset="100%" stop-color="#6dc23d"/>
    </linearGradient>
  </defs>
  <rect x="0" y="0" width="400" height="200" fill="url(#g)"/>
  <text x="200" y="115" text-anchor="middle" fill="white"
        font-family="sans-serif" font-size="40" font-weight="bold">
    tcllunasvg
  </text>
</svg>}

puts "tcllunasvg version: [tcllunasvg::version]"
puts ""

# ----------------------------------------------------------------------
# Variante 1: Document-Handle, mehrfaches Rendering verschiedener Größen
# ----------------------------------------------------------------------

puts "=== Variante 1: Handle ==="
set doc [tcllunasvg::load data $svg_data]
puts "Dokumentgröße: [$doc size]"

$doc to_png [file join $out_dir small.png]   -width 100
$doc to_png [file join $out_dir medium.png]  -scale 1.0
$doc to_png [file join $out_dir large.png]   -scale 3.0
$doc to_png [file join $out_dir on_white.png] -scale 2.0 -bg white

$doc destroy

foreach f {small.png medium.png large.png on_white.png} {
    set path [file join $out_dir $f]
    puts "  geschrieben: $path ([file size $path] bytes)"
}

# ----------------------------------------------------------------------
# Variante 2: file_to_png One-Shot
# ----------------------------------------------------------------------

puts ""
puts "=== Variante 2: file_to_png One-Shot ==="

# Erst das Inline-SVG als Datei ablegen
set svg_file [file join $out_dir demo.svg]
set fp [open $svg_file w]
puts -nonewline $fp $svg_data
close $fp

tcllunasvg::file_to_png $svg_file [file join $out_dir oneshot.png] -scale 2 -bg white
puts "  geschrieben: [file join $out_dir oneshot.png]"

puts ""
puts "Fertig. Ausgabe-Verzeichnis: $out_dir"
