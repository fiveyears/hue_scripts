#!/usr/bin/env tclsh
source [file join [file dirname [info script]] "config.tcl"]
source [file join [file dirname [info script]] "hue.inc.tcl"]

set body ""
if {$::argc > 2} {
	set group [lindex $argv 0]
	set body [getBody $argv];# Paare von Bodyarguments in beliebiger Reihenfolge
} {

		puts "Usage: [info script] GroupNr on false ..."
		exit
}
if { $body != ""} {
	set body [string range $body 1 end]
	puts $body
	set url "groups/$group/action"
	puts [huePut $url "{$body}"]
}
