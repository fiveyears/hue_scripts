#!/usr/bin/env tclsh
source [file join [file dirname [info script]] "config.tcl"]
source [file join [file dirname [info script]] "hue.inc.tcl"]

if {$::argc > 1} {set light [lindex $argv 0]};# erstes Argument ist das Light ( 1, 2, ...)
set body [getBody $argv];# Paare von Bodyarguments in beliebiger Reihenfolge
if { $body != ""} {
	set body [string range $body 1 end]
	set url "lights/$light/state"
	puts [huePut $url "{$body}"]
} {
		puts "Usage: [info script] LighNr on false ..."
		exit
}
