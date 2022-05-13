#!/usr/bin/env tclsh
set script_path [file normalize [file dirname $argv0]]
source [file join $script_path "preferences.tcl"]
source [file join $script_path "hue.inc.tcl"]


load $script_path/bin/libTools[info sharedlibextension]
eval [ jsonMapper [jsonparser info [string range [huePost "lights" ""] 1 end-1]] ]
parray info
