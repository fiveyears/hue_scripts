#!/usr/bin/env tclsh
set script_path [file dirname [info script]]
source [file join $script_path "config.tcl"]
source [file join $script_path "hue.inc.tcl"]
load $script_path/json/libJSON[info sharedlibextension]
set cap "capabilities"
foreach aArg $argv {
	set cap "$cap/$aArg"
}
eval [jsonparser cap_ar [hueGet "$cap"]]
unset cap_ar(timezones,values)
parray cap_ar
