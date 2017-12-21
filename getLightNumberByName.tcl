#!/usr/bin/env tclsh
global ip user light ;# gesetzt für den Aufruf durch ccu_read_hue.tcl
set script_path [file dirname [info script]]
source [file join $script_path "config.tcl"]
source [file join $script_path "hue.inc.tcl"]
if {$::argc > 0} {
	load $script_path/json/libTools[info sharedlibextension]
	set places 2
	set nr [lindex $argv 0]
	if { [string is digit $nr ]} {
		set nr [string trimleft $nr 0]
	} else {
		eval [jsonparser t [hueGet "lights"] 1 ]
		set names [array get t "*,name*"]
		set pos [lsearch  $names $nr]
		if { $pos < 0 } 	{
			puts "Lamp '$nr' not found! Exit"
			exit 0
		}
		incr pos -1
		set nr [lindex $names $pos]
		set nr  [lindex [split $nr , ] 0 ]
	}
	puts $nr
} {
		puts "Usage: [info script] LightName"
		exit 1
}
