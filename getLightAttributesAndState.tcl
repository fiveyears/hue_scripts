#!/usr/bin/env tclsh
global ip user light ;# gesetzt für den Aufruf durch ccu_read_hue.tcl
set script_path [file dirname [info script]]
source [file join $script_path "config.tcl"]
source [file join $script_path "hue.inc.tcl"]
source [file join $script_path "json/json.tcl"]
if {$argc > 0 } {
	set nr [lindex $argv 0]
	set light(number) $nr
	json light [hueGet "lights/$nr"]
	if {$argc < 2 } { ;# Aufruf nicht durch ccu_read_hue.tcl
		parray light
	}
} {
	puts "Usage: [info script] Lightnumber"
}

