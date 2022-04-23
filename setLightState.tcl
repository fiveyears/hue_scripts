#!/usr/bin/env tclsh
if {[package vcompare [package provide Tcl] 8.4] < 0} {
	set script_path [file dirname $argv0]
} else {
	set script_path [file normalize [file dirname $argv0]]
}

if { "$env(HOME)" == "/root" } {
	set config [file join $script_path  "bin/.config.hue.tcl"]
} else {
	set config [file join $env(HOME) ".config.hue.tcl"]
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
if { $body != ""} {
	# set body [string range $body 1 end]
	set url "lights/$light/state"
	puts [huePut $url "{$body}"]
} {
		puts "Usage: [info script] LighNr on false ..."
		exit
}
