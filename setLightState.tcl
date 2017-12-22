#!/usr/bin/env tclsh
set script_path [file dirname [info script]]
source [file join $script_path "config.tcl"]
source [file join $script_path "hue.inc.tcl"]

if {$::argc > 1} {
	set light [lindex $argv 0]
	set light [exec $script_path/getLightNumberByName.tcl $light]
	if { [string first Exit $light] > 0} { 
		puts $light
		exit 1	
	}
}
# erstes Argument ist das Light ( 1, 2, ...)
set body [getBody $argv];# Paare von Bodyarguments in beliebiger Reihenfolge
if { $body != ""} {
	set body [string range $body 1 end]
	set url "lights/$light/state"
	puts [huePut $url "{$body}"]
} {
		puts "Usage: [info script] LighNr on false ..."
		exit
}
