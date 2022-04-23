#!/usr/bin/env tclsh
global ip user light ;# set in config.tcl
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
	load $script_path/bin/libTools[info sharedlibextension]
	set places 2
	set nr [lindex $argv 0]
	set nr [getLightNumberByName $nr]
	if { [string first Exit $nr] > 0} { 
		puts $nr
		exit 1	
	}
	set l "$nr on true" ;# erstes Argument ist das Light ( 1, 2, ...)
	eval [ jsonMapper [jsonparser light [hueGet "lights/$nr"] places ] ]
	set model $light(modelid)
	set rgb [lindex $argv 1]
	set newRgb [realRGB $rgb]
	set xy [calcXY $model $newRgb]
	if { $newRgb != $rgb} {
		puts "$rgb is $newRgb, xy calculated for model $model: $xy."
	} else {
		puts "$rgb, xy calculated for model $model: $xy."
	}
	set l "$l xy $xy"
	if {$::argc > 2} {
		set bri [lindex $argv 2]
		set l "$l bri $bri"
	}
	if {$::argc > 3} {
		set sat [lindex $argv 3]
		set l "$l sat $sat"
	}
}
set body ""
if { [info exists l] } {
	set body [getBody $l];# Paare von Bodyarguments in beliebiger Reihenfolge
}
if { $body != ""} {
	# set body [string range $body 1 end]
	set url "lights/$nr/state"
	puts [huePut $url "{$body}"]
} {
		puts "Usage: [info script] LighNr Rgb ?bri? ?sat? ..."
		exit
}
