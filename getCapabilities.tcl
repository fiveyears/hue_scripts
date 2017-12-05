#!/usr/bin/env tclsh
set script_path [file dirname [info script]]
source [file join $script_path "config.tcl"]
source [file join $script_path "hue.inc.tcl"]
source [file join $script_path "json/json.tcl"]
set cap "capabilities"
foreach aArg $argv {
	set cap "$cap/$aArg"
}
json cap_ar [hueGet "$cap"]
parray cap_ar
