#!/usr/bin/env tclsh
#global ip user ;# gesetzt für den Aufruf durch ccu_read_hue.tcl
set script_path [file dirname [info script]]
source [file join $script_path "config.tcl"]
source [file join $script_path "hue.inc.tcl"]
source [file join $script_path "json/json.tcl"]
json scene [hueGet "scenes"]

if {$argc > 0 } { ;# Aufruf durch ccu_read_hue.tcl
	return [array get scene]
} {
	parray scene
}