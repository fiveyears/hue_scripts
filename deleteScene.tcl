#!/usr/bin/env tclsh
set script_path [file normalize [file dirname $argv0]]
source [file join $script_path "preferences.tcl"]
source [file join $script_path "hue.inc.tcl"]
if {$::argc > 0} {
	set nr [lindex $argv 0]
	set other [hueDelete "scenes/$nr"]
	load $script_path/bin/libTools[info sharedlibextension]
	eval [ jsonMapper [jsonparser info [string range $other 1 end-1]] ]
	parray info
} {
		puts "Usage: [info script] Scene-ID"
		exit
}
