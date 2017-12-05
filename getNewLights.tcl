#!/usr/bin/env tclsh
source [file join [file dirname [info script]] "config.tcl"]
source [file join [file dirname [info script]] "hue.inc.tcl"]


puts [string map { "\"" {}} [string range [hueGet "lights/new"]  1 end-1  ]]
