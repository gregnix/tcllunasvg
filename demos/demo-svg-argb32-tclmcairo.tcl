#!/usr/bin/env tclsh
# demos/demo-svg-argb32-tclmcairo.tcl
#
# End-to-End-Bridge: SVG via tcllunasvg → ARGB32-Bytes → tclmcairo → PDF
#
# Demonstriert die saubere Trennung:
#   1. SVG mit tcllunasvg in ARGB32-Bytes rendern (lunasvg-Welt)
#   2. Bytes als Cairo-Surface aufnehmen (cairo-Welt)
#   3. Eigene cairo-Operationen drueberzeichnen
#   4. PDF + PNG speichern
#
# Solange tclmcairo image_from_argb32 noch nicht hat (vor 0.4.0),
# laeuft das Demo ueber einen PNG-Roundtrip als Fallback.

if {[info exists ::env(TCLLUNASVG_LIBDIR)]} {
    set ::auto_path [linsert $::auto_path 0 $::env(TCLLUNASVG_LIBDIR)]
}

package require tcllunasvg
package require tclmcairo

set demo_dir [file dirname [info script]]
set out_dir  [file join $demo_dir tmp]
file mkdir $out_dir

# Inline-SVG: einfaches Logo
set svg_data {<?xml version="1.0" encoding="UTF-8"?>
<svg width="120" height="120" xmlns="http://www.w3.org/2000/svg">
  <circle cx="60" cy="60" r="55" fill="#4078c0" stroke="#234578" stroke-width="3"/>
  <text x="60" y="72" text-anchor="middle" fill="white"
        font-family="sans-serif" font-size="42" font-weight="bold">Tcl</text>
</svg>}

# 1. SVG rendern -> ARGB32 -----------------------------------------------
puts "1. SVG rendern (tcllunasvg)"
set doc [tcllunasvg::load data $svg_data]
set img [$doc to_argb32 -scale 2 -bg transparent]
$doc destroy

set w      [dict get $img width]
set h      [dict get $img height]
set stride [dict get $img stride]
set data   [dict get $img data]
puts "   gerendert: ${w}x${h}, stride=$stride, [string length $data] bytes"

# Feature-Query auf Package-Ebene
set has_argb32 [tclmcairo hasFeature image_from_argb32]
puts "   tclmcairo image_from_argb32: [expr {$has_argb32 ? "verfuegbar" : "nicht vorhanden, Fallback ueber PNG-Datei"}]"

# 2. Cairo-Seite aufbauen ------------------------------------------------
puts "2. PDF-Seite mit Cairo aufbauen (tclmcairo)"
set ctx [tclmcairo::new 595 842]   ;# A4 portrait, 72dpi
$ctx clear 1 1 1

# Ueberschrift
$ctx text 297 80 "tcllunasvg + tclmcairo" \
    -font {Sans Bold 24} -fill {0.15 0.25 0.45 1} -anchor center

# Logo einbetten — Image-Pool-Pattern:
#   image_load / image_from_argb32 -> img_id
#   image_blit img_id x y          -> auf den Kontext malen
#   image_free img_id              -> Pool-Eintrag freigeben
set logo_x [expr {297 - $w/2}]
set logo_y 150

if {$has_argb32} {
    # Direkter, schneller Weg (ab tclmcairo 0.4.0)
    set img_id [$ctx image_from_argb32 $data $w $h]
} else {
    # Fallback: PNG-Roundtrip ueber Datei
    set tmp_png [file join $out_dir _logo_tmp.png]
    set d2 [tcllunasvg::load data $svg_data]
    $d2 to_png $tmp_png -scale 2 -bg transparent
    $d2 destroy
    set img_id [$ctx image_load $tmp_png]
}

$ctx image_blit $img_id $logo_x $logo_y
$ctx image_free $img_id

# Zusatztext unter dem Logo
$ctx text 297 [expr {$logo_y + $h + 60}] \
    "SVG via lunasvg, drumherum cairo." \
    -font {Sans 14} -fill {0.2 0.2 0.2 1} -anchor center

# 3. Speichern -----------------------------------------------------------
puts "3. Speichern"
$ctx save [file join $out_dir page.pdf]
$ctx save [file join $out_dir page.png]
$ctx destroy

puts "   geschrieben: [file join $out_dir page.pdf]"
puts "   geschrieben: [file join $out_dir page.png]"
puts ""
puts "Fertig. Beachte: keine direkte C-Kopplung zwischen tcllunasvg und tclmcairo."
puts "Die einzige Bruecke sind ARGB32-Pixeldaten (bzw. PNG-Bytes im Fallback)."
