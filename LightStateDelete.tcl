#!/usr/bin/env tclsh
global ip user light ;# gesetzt für den Aufruf durch ccu_read_hue.tcl
set script_path [file dirname [info script]]
source [file join $script_path "config.tcl"]
source [file join $script_path "hue.inc.tcl"]
source [file join $script_path "ccu_helper.tcl"]


if {$argc > 0 } {
	set nr [lindex $argv 0]
	set nr [exec $script_path/getLightNumberByName.tcl $nr]
	if { [string first Exit $nr] > 0} { 
		puts $nr
		exit 1	
	}
	load $script_path/json/libTools[info sharedlibextension]
	eval [jsonparser light [hueGet "lights/$nr"]]
    if { [testRega] } {
        exec rm -rf "$script_path/.state${nr}_($light(name)).txt" 
    } else {
		deleteVariable "state${nr}"
    }

} {
	puts "Usage: [info script] Lightnumber|Name"
}

