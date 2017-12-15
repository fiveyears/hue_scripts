#!/usr/bin/env tclsh
set script_path [file dirname [info script]]
source [file join $script_path "config.tcl"]
source [file join $script_path "hue.inc.tcl"]
if {$::argc > 1} {
	set name [lindex $argv 0]
	set lights [lindex $argv 1]
	set l [string map {"\""  ""} $lights]
	regsub -all {(\d+)} $l {"\1"} l
	set body  "{\"lights\": \\\[ $l \\\], \"name\": \"$name\"}"
	set other [huePost "groups" $body]
	load $script_path/json/libJSON[info sharedlibextension]
	eval [jsonparser info [string range $other 1 end-1]]
	parray info
} {
		puts "Usage: [info script] groupname lights"
		exit
}
