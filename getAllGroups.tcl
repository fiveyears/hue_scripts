#!/usr/bin/env tclsh
set script_path [file dirname [info script]]
source [file join $script_path "config.tcl"]
source [file join $script_path "hue.inc.tcl"]
load $script_path/json/libJSON[info sharedlibextension]
eval [jsonparser group [hueGet "groups"]]

if {$argc > 0 } { ;# Aufruf durch ccu_read_hue.tcl
	return [array get group]
} {
	parray group
}
