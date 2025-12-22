#!/usr/bin/env tclsh
set script_path [file normalize [file dirname $argv0]]
source [file join $script_path "preferences.tcl"]
source [file join $script_path "hue.inc.tcl"]
load $script_path/bin/libTools[info sharedlibextension]
set pattern ""
set reset 1
set p 0
if {$argc > 0} { set pattern "[lindex $argv 0]"}
if {$argc > 1} { set p "[lindex $argv 1]"}
if {$argc > 2} { set reset "[lindex $argv 2]"}
allV1 capabilities $pattern $reset $p
