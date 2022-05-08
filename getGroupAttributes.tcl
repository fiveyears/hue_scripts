#!/usr/bin/env tclsh
set script_path [file normalize [file dirname $argv0]]
if { "$env(HOME)" == "/root" } {
	set config [file join $script_path  "bin/.config.hue.tcl"]
} else {
	set config [file join $env(HOME) ".config.hue.tcl"]
}
source "$config"
source [file join $script_path "hue.inc.tcl"]
load $script_path/bin/libTools[info sharedlibextension]


set a "s"
if {$argc > 1} { 
	set a [lindex $argv 1]
}
if {$argc > 0 } {
	set nr [lindex $argv 0]
	set nr [getGroupNumberByName $nr]
	if { [string first Exit $nr] > 0} { 
		puts $nr
		exit 1	
	}
	set group(number) $nr
	eval [ jsonMapper [jsonparser group [hueGet "groups/$nr"]] ]
	set l $group(lights)
	set l [string map {"\""  ""} $l]
	set group(lights) $l
	set l [split $l ,]
	set lightNames {}
	foreach lightNr $l {
		eval [ jsonMapper [jsonparser light [hueGet "lights/$lightNr"]] ]
		lappend lightNames $light(name)
	}
	if { "$a" != "l" } {
		catch {
			unset group(action,alert)
			unset group(action,bri)
			unset group(action,colormode)
			unset group(action,ct)
			unset group(action,effect)
			unset group(action,hue)
			unset group(action,sat)
			unset group(recycle)
		}
	}
	set group(lightNames) [join $lightNames ,]
	# argc > 1 then long output else short
	#if {$argc > 1} { 
	#	unset 
	#}
	parray group
} {
	puts "Usage: [info script] Groupnumber"
}

