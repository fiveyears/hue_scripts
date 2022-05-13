#!/usr/bin/env tclsh
set script_path [file normalize [file dirname $argv0]]
source [file join $script_path "preferences.tcl"]
source [file join $script_path "hue.inc.tcl"]

if {$::argc > 1} {
	set light [lindex $argv 0];# erstes Argument ist das Light ( 1, 2, ...)
	set url "lights/$light"
	puts [huePut $url "{\"name\":\"[lindex $argv 1]\"}"]
} {
		puts "Usage: [info script] LightNr \"Neuer Name\""
		exit
}
