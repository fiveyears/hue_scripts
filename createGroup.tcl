#!/usr/bin/env tclsh
set script_path [file normalize [file dirname $argv0]]

if { "$env(HOME)" == "/root" } {
	set config [file join $script_path  "bin/.hue/0/config.hue.tcl"]
} else {
	set config [file join $env(HOME) ".hue/0/config.hue.tcl"]
}
source "$config"
source [file join $script_path "hue.inc.tcl"]
set types "Luminaire Lightsource LightGroup Room"
set rooms {{Living room} Kitchen Dining Bedroom {Kids bedroom} Bathroom Nursery Recreation Office Gym Hallway Toilet {Front door} Garage Terrace Garden Driveway Carport Other}
if {$::argc > 1} {
	set name [lindex $argv 0]
	set lights [lindex $argv 1]
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
	set body  "{\"lights\": \\\[ $l \\\], \"name\": \"$name\"}"
	if {$::argc > 2} {
		set type [lindex $argv 2]
		set i [lsearch -regexp $types (?i)^${type} ]
		if { $i >=0 } {
			set type [lindex $types $i]
			set body  "{\"lights\": \\\[ $l \\\], \"name\": \"$name\", \"type\": \"$type\"}"  
		} else {
			puts "Wrong type $type! The type must be in '$types'"
			exit 0
		}
		if { $type == "Room" } {
			if {$::argc > 3} {
				set room [lindex $argv 3]
				set i [lsearch -regexp $rooms (?i)^${room} ]
				if { $i >=0 } {
					set room [lindex $rooms $i]
					set body  "{\"lights\": \\\[ $l \\\], \"name\": \"$name\", \"type\": \"$type\", \"class\": \"$room\"}"  
				} else {
					puts "Wrong room $room! The room must be in '$rooms'"
					exit 0
				}
			} else {
				set body  "{\"lights\": \\\[ $l \\\], \"name\": \"$name\", \"type\": \"$type\", \"class\": \"Other\"}"  
			}
		}
	}
	set other [huePost "groups" $body]
	load $script_path/bin/libTools[info sharedlibextension]
	eval [ jsonMapper [jsonparser info [string range $other 1 end-1]] ]
	parray info
} {
		puts "Usage: [info script] groupname lights ?type? ?class?"
		exit
}
