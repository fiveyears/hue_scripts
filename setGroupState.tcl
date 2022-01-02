#!/usr/bin/env tclsh
if {[package vcompare [package provide Tcl] 8.4] < 0} {
	set script_path [file dirname $argv0]
} else {
	set script_path [file normalize [file dirname $argv0]]
}

source [file join $env(HOME) ".config.hue.tcl"]
source [file join $script_path "hue.inc.tcl"]

set body ""
if {$::argc > 2} {
	set group [lindex $argv 0]
	set group [getGroupNumberByName $group]
	set body [getBody $argv];# Paare von Bodyarguments in beliebiger Reihenfolge
} {

		puts "Usage: [info script] GroupNr on false ..."
		exit
}
if { $body != ""} {
	# set body [string range $body 1 end]
	set url "groups/$group/action"
	puts [huePut $url "{$body}"]
}
