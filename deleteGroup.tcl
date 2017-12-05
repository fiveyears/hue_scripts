#!/usr/bin/env tclsh
source [file join [file dirname [info script]] "config.tcl"]
source [file join [file dirname [info script]] "hue.inc.tcl"]
if {$::argc > 0} {
	set nr [lindex $argv 0]
	set other [hueDelete "groups/$nr"]
	puts [string range $other 1 end-1]
} {
		puts "Usage: [info script] GroupNr"
		exit
}
