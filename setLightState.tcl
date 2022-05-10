#!/usr/bin/env tclsh
global ip user light ;# set in config.tcl
set script_path [file normalize [file dirname $argv0]]

if { "$env(HOME)" == "/root" } {
	set config [file join $script_path  "bin/.hue/0/config.hue.tcl"]
} else {
	set config [file join $env(HOME) ".hue/0/config.hue.tcl"]
}
source "$config"
source [file join $script_path "hue.inc.tcl"]

if {$::argc > 1} {
	set light [lindex $argv 0]
	set light [getLightNumberByName $light]
	if { [string first Exit $light] > 0} { 
		puts $light
		exit 1	
	}
}
# erstes Argument ist das Light ( 1, 2, ...)
set body [getBody $argv];# Paare von Bodyarguments in beliebiger Reihenfolge
puts $body
if { $body != ""} {
	# set body [string range $body 1 end]
	set url "lights/$light/state"
	puts [huePut $url "{$body}"]
} {
		puts "Usage: [info script] LighNr on false ..."
		exit
}
