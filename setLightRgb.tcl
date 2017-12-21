#!/usr/bin/env tclsh
global ip user light ;# gesetzt für den Aufruf durch ccu_read_hue.tcl
set script_path [file dirname [info script]]
source [file join $script_path "config.tcl"]
source [file join $script_path "hue.inc.tcl"]
if {$::argc > 1} {
	load $script_path/json/libTools[info sharedlibextension]
	set places 2
	set nr [lindex $argv 0]
	set nr [exec $script_path/getLightNumberByName.tcl $nr]
	if { [string first Exit $nr] > 0} { 
		puts $nr
		exit 1	
	}
	set l "$nr on true" ;# erstes Argument ist das Light ( 1, 2, ...)
	eval [jsonparser light [hueGet "lights/$nr"] places ]
	set model $light(modelid)
	set rgb [lindex $argv 1]
	set newRgb [realRGB $rgb]
	set xy [calcXY $model $rgb]
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
	set body [string range $body 1 end]
	set url "lights/$nr/state"
	puts [huePut $url "{$body}"]
} {
		puts "Usage: [info script] LighNr Rgb ?bri? ?sat? ..."
		exit
}
