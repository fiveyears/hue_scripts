#!/usr/bin/env tclsh
set script_path [file dirname [info script]]
source [file join $script_path "config.tcl"]
source [file join $script_path "hue.inc.tcl"]
load $script_path/json/libJSON[info sharedlibextension]


if {$argc > 0 } {
	set nr [lindex $argv 0]
	set group(number) $nr
	eval [jsonparser group [hueGet "groups/$nr"]]
	parray group
} {
	puts "Usage: [info script] Groupnumber"
}

