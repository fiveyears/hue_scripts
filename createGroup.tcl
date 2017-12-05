#!/usr/bin/env tclsh
source [file join [file dirname [info script]] "config.tcl"]
source [file join [file dirname [info script]] "hue.inc.tcl"]
if {$::argc > 1} {
	set name [lindex $argv 0]
	set lights [lindex $argv 1]
	set l [string map {"\""  ""} $lights]
	regsub -all {(\d+)} $l {"\1"} l
	set body  "{\"lights\": \\\[ $l \\\], \"name\": \"$name\"}"
	set other [huePost "groups" $body]
	puts $other
} {
		puts "Usage: [info script] groupname lights"
		exit
}
