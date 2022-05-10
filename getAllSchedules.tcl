#!/usr/bin/env tclsh
set script_path [file normalize [file dirname $argv0]]
if { "$env(HOME)" == "/root" } {
	set config [file join $script_path  "bin/.hue/0/config.hue.tcl"]
} else {
	set config [file join $env(HOME) ".hue/0/config.hue.tcl"]
}
source "$config"
source [file join $script_path "hue.inc.tcl"]
load $script_path/bin/libTools[info sharedlibextension]
set places 2
eval [ jsonMapper [jsonparser schedule [hueGet "schedules"] $places] ]
set a "s"
if {$argc > 0} { 
	set a [lindex $argv 0]
}
set i 1
if { [array exists schedule] } {

	if {$argc < 2 || "$a" == "l"} { ;# Aufruf nicht durch ccu_read_hue.tcl
		parray schedule
		
	}
} else {
	puts "There are no schedules!"
}
