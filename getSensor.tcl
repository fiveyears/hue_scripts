#!/usr/bin/env tclsh
set script_path [file normalize [file dirname $argv0]]
if { "$env(HOME)" == "/root" } {
	set config [file join $script_path  "bin/.hue/0/config.hue.tcl"]
} else {
	set config [file join $env(HOME) ".hue/0/config.hue.tcl"]
}
source "$config"
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
