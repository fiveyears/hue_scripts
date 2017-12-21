#!/usr/bin/env tclsh
set script_path [file dirname [info script]]
source [file join $script_path "config.tcl"]
source [file join $script_path "hue.inc.tcl"]
if {$::argc > 0} {
	set nr [lindex $argv 0]
	set other [hueDelete "groups/$nr"]
	load $script_path/json/libTools[info sharedlibextension]
	eval [jsonparser info [string range $other 1 end-1]]
	parray info
} {
		puts "Usage: [info script] GroupNr"
		exit
}
