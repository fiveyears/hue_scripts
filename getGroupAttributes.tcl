#!/usr/bin/env tclsh
set script_path [file dirname [info script]]
source [file join $script_path "config.tcl"]
source [file join $script_path "hue.inc.tcl"]
source [file join $script_path "json/json.tcl"]

if {$argc > 0 } {
	set nr [lindex $argv 0]
	json group [hueGet "groups/$nr"]
	parray group
} {
	puts "Usage: [info script] Groupnumber"
}

