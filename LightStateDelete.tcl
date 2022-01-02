#!/usr/bin/env tclsh
global ip user light lightcount;# gesetzt für den Aufruf durch ccu_read_hue.tcl
if {[package vcompare [package provide Tcl] 8.4] < 0} {
	set script_path [file dirname $argv0]
} else {
	set script_path [file normalize [file dirname $argv0]]
}

source [file join $env(HOME) ".config.hue.tcl"]
source [file join $script_path "hue.inc.tcl"]
source [file join $script_path "ccu_helper.tcl"]
if { [info exists lightcount] == 0 } {
	set lightcount 50
}
if {$argc > 0 } {
	set nr [lindex $argv 0]
	if { $nr == "0" } {

		if { [testRega] } {
			file delete {*} [glob -nocomplain $script_path/.state*.txt] 
		} else {
			for {set i  1} { $i <= $lightcount } {incr i} {
				deleteVariable "state${i}"
			}
		}
		exit 0
	}
	set nr [getLightNumberByName $nr]
	if { [string first Exit $nr] > 0} { 
		puts $nr
		exit 1	
	}
	load $script_path/bin/libTools[info sharedlibextension]
	eval [ jsonMapper [jsonparser light [hueGet "lights/$nr"]] ]
    if { [testRega] } {
        exec rm -rf "$script_path/.state${nr}_($light(name)).txt" 
    } else {
		deleteVariable "state${nr}"
    }

} {
	puts "Usage: [info script] Lightnumber|Name"
}

