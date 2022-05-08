#!/usr/bin/env tclsh
set script_path [file normalize [file dirname $argv0]]
if { "$env(HOME)" == "/root" } {
	set config [file join $script_path  "bin/.config.hue.tcl"]
} else {
	set config [file join $env(HOME) ".config.hue.tcl"]
}
source "$config"
source [file join $script_path "hue.inc.tcl"]
load $script_path/bin/libTools[info sharedlibextension]


set a "s"
if {$argc > 1} { 
	set a [lindex $argv 1]
}
if {$argc > 0 } {
	set nr [lindex $argv 0]
	set nr [getScheduleNumberByName $nr]
	if { [string first Exit $nr] > 0} { 
		puts $nr
		exit 1	
	}
	set schedule(number) $nr
	set get [hueGet "schedules/$nr"]
	if { [string first  \[\{\"error\" $get] >= 0} { 
		puts $get
		exit 1	
	}
	eval [ jsonMapper [jsonparser schedule $get] ]
	if { "$a" != "l" } {
		#unset schedule(action,alert)
		#unset schedule(action,bri)
		#unset schedule(action,colormode)
		#unset schedule(action,ct)
		#unset schedule(action,effect)
		#unset schedule(action,hue)
		#unset schedule(action,sat)
		#unset schedule(recycle)
	}
	parray schedule
} {
	puts "Usage: [info script] Groupnumber"
}

