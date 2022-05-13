#!/usr/bin/env tclsh
set script_path [file normalize [file dirname $argv0]]
source [file join $script_path "preferences.tcl"]
source [file join $script_path "hue.inc.tcl"]
load $script_path/bin/libTools[info sharedlibextension]

if {$argc > 0 } {
	set nr [lindex $argv 0]
	set nr [getSensorNumberByName $nr]
    eval [ jsonMapper [jsonparser sensor [hueGet "sensors/$nr"]] ]
	parray sensor
} {
	puts "Usage: [info script] Groupnumber"
}
