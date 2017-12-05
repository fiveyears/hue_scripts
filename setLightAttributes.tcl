#!/usr/bin/env tclsh
source [file join [file dirname [info script]] "config.tcl"]
source [file join [file dirname [info script]] "hue.inc.tcl"]
if {$::argc > 1} {
	set light [lindex $argv 0];# erstes Argument ist das Light ( 1, 2, ...)
	set url "lights/$light"
	puts [huePut $url "{\"name\":\"[lindex $argv 1]\"}"]
} {
		puts "Usage: [info script] LightNr \"Neuer Name\""
		exit
}
