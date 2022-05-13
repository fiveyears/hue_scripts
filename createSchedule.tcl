#!/usr/bin/env tclsh
set script_path [file normalize [file dirname $argv0]]

source [file join $script_path "preferences.tcl"]
source [file join $script_path "hue.inc.tcl"]
if {$::argc > 1} {
	set body [getBody "0 $argv"]
	set other [huePost "schedules" $body]
	load $script_path/bin/libTools[info sharedlibextension]
	eval [ jsonMapper [jsonparser info [string range $other 1 end-1]] ]
	parray info
} {
		puts "Usage: [info script] groupname lights ?type? ?class?"
		exit
}
