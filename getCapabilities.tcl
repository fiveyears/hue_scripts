#!/usr/bin/env tclsh
set script_path [file normalize [file dirname $argv0]]
source [file join $script_path "preferences.tcl"]
source [file join $script_path "hue.inc.tcl"]
load $script_path/bin/libTools[info sharedlibextension]
set cap "capabilities"
foreach aArg $argv {
	set cap "$cap/$aArg"
}
eval [ jsonMapper [jsonparser cap_ar [hueGet "$cap"]] ]
unset cap_ar(timezones,values)
parray cap_ar
