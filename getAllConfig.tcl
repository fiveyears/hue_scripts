#!/usr/bin/env tclsh
set script_path [file normalize [file dirname $argv0]]
source [file join $script_path "preferences.tcl"]
source [file join $script_path "hue.inc.tcl"]
load $script_path/bin/libTools[info sharedlibextension]
eval [ jsonMapper [jsonparser config [hueGet config]] ]
if {$argc > 0 } { ;# Aufruf durch ccu_read_hue.tcl
	return [array get config]
} {
	parray config
}