#!/usr/bin/env tclsh
set script_path [file dirname [info script]]
source [file join $script_path "config.tcl"]
source [file join $script_path "hue.inc.tcl"]


load $script_path/json/libJSON[info sharedlibextension]
eval [jsonparser info [string range [huePost "lights" ""] 1 end-1]]
parray info
