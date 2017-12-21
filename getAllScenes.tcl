#!/usr/bin/env tclsh
set script_path [file dirname [info script]]
source [file join $script_path "config.tcl"]
source [file join $script_path "hue.inc.tcl"]
load $script_path/json/libTools[info sharedlibextension]
eval [jsonparser scene [hueGet "scenes"]]

if {$argc > 0 } { ;# Aufruf durch ccu_read_hue.tcl
	return [array get scene]
} {
	parray scene
}