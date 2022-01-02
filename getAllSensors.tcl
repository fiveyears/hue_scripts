#!/usr/bin/env tclsh
if {[package vcompare [package provide Tcl] 8.4] < 0} {
	set script_path [file dirname $argv0]
} else {
	set script_path [file normalize [file dirname $argv0]]
}

source [file join $env(HOME) ".config.hue.tcl"]
source [file join $script_path "hue.inc.tcl"]
load $script_path/bin/libTools[info sharedlibextension]
eval [ jsonMapper [jsonparser sensor [hueGet "sensors"]] ]

if {$argc > 0 } { ;# Aufruf durch ccu_read_hue.tcl
	return [array get sensor]
} {
	parray sensor
}