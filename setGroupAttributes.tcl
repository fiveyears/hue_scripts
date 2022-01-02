#!/usr/bin/env tclsh
if {[package vcompare [package provide Tcl] 8.4] < 0} {
	set script_path [file dirname $argv0]
} else {
	set script_path [file normalize [file dirname $argv0]]
}

source [file join $env(HOME) ".config.hue.tcl"]
source [file join $script_path "hue.inc.tcl"]
set lights ""
set name ""
set class ""
if {$argc > 2 } {
	set group [lindex $argv 0]
	set group [getGroupNumberByName $group]
	if { [string first Exit $group] > 0} { 
		puts $group
		exit 1	
	}
	for {set i 1} {$i<$::argc} {incr i} {
	   set n [lindex $argv $i]
	   incr i
	   set v [lindex $argv $i]
	   if {$v != ""} {
	   		switch -glob $n {
	   			nam* {
	   				set name "$v"
	   			}
	   			lig* {
	   				set lights "$v"
	   			}
	   			cla* {
	   				set class "$v"
	   			}
	   		}
	   }
	}
	if {$name == "" && $lights == "" && $class == ""} {
		puts "Keine Argumente: name \"Neuer Name\" und/oder lights \"Lampennummern\" und/oder class \"neue Klasse\" wählen."
		exit
	}
	set body ""
	if {$name != ""} {
		set body  "\"name\":\"$name\","
	}
	if {$class != ""} {
		set body  "\"class\":\"$class\","
	}
	if {$lights != ""} {
		set l [string map {"\""  ""} $lights]
		set l [split $l ,]
		set newL {}
		foreach lightNr $l {
			set nr [getLightNumberByName $lightNr]
			if { [string first Exit $nr] > 0} { 
				puts $nr
				exit 1	
			}
			if { [lsearch $newL $nr] < 0  } {
				lappend newL $nr
			}
		}
		regsub -all {(\d+)} [join $newL ,]  {"\1"} l
		set body  "$body\"lights\":\\\[$l\\\]\,"
	}
	set body [string range $body 0 end-1]
	set body  "\{$body\}"
	#puts $body
	set other [huePut "groups/$group" $body]
	puts $other
} {
	puts "Usage: [info script] GroupNr name \"Neuer Name\" | lights Lampennummern"
}

