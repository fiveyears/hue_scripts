#!/usr/bin/env tclsh
set script_path [file dirname [info script]]
source [file join $script_path "config.tcl"]
source [file join $script_path "hue.inc.tcl"]
load $script_path/json/libTools[info sharedlibextension]
eval [jsonparser info [hueGet "lights/new"] ]
parray info

