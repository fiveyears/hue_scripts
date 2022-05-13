#!/usr/bin/env tclsh
set script_path [file normalize [file dirname $argv0]]

source [file join $script_path "preferences.tcl"]
source [file join $script_path "hue.inc.tcl"]

if {$::argc > 1} {
	set sensor [lindex $argv 0]
	set sensor [getSensorNumberByName $sensor]
	if { [string first Exit $sensor] > 0} { 
		puts $sensor
		exit 1	
	}
}
# erstes Argument ist das sensor ( 1, 2, ...)
set body [getBody $argv];# Paare von Bodyarguments in beliebiger Reihenfolge
if { $body != ""} {
	# set body [string range $body 1 end]
	set url "sensors/$sensor/config"
	puts [huePut $url "{$body}"]
} {
		puts "Usage: [info script] SensorNr|Name on false ..."
		exit
}
