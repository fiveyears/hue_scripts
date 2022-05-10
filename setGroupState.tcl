#!/usr/bin/env tclsh
set script_path [file normalize [file dirname $argv0]]

if { "$env(HOME)" == "/root" } {
	set config [file join $script_path  "bin/.hue/0/config.hue.tcl"]
} else {
	set config [file join $env(HOME) ".hue/0/config.hue.tcl"]
}
source "$config"
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
