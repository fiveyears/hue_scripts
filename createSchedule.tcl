#!/usr/bin/env tclsh
set script_path [file normalize [file dirname $argv0]]

if { "$env(HOME)" == "/root" } {
	set config [file join $script_path  "bin/.config.hue.tcl"]
} else {
	set config [file join $env(HOME) ".config.hue.tcl"]
}
source "$config"
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
