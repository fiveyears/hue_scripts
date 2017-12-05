#!/usr/bin/env tclsh
source [file join [file dirname [info script]] "config.tcl"]
source [file join [file dirname [info script]] "hue.inc.tcl"]
set lights ""
set name ""
if {$argc > 2 } {
	set group [lindex $argv 0]
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
	   		}
	   }
	}
	if {$name == "" && $lights == ""} {
		puts "Keine Argumente: name \"Neuer Name\" und/oder lights \"Lampennummern\" wählen."
		exit
	}
	set body ""
	if {$name != ""} {
		set body  "\"name\":\"$name\","
	}
	if {$lights != ""} {
		set l [string map {"\""  ""} $lights]
		regsub -all {(\d+)} $l {"\1"} l
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

