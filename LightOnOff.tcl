#!/usr/bin/env tclsh

# nr Nummer/Name der Lampe
# sw ... on, off, read, toogle
proc LightOnOff {args} {
	# for not sourced
	set argsLength  [llength $args]
	if {$argsLength < 1} {
		puts "Usage: [info script] LighNr \[read|on|off|toggle\]"
		exit 1
	} elseif {$argsLength == 1} {
		set nr [lindex $args 0]
		set sw true
	} else  {
		set nr [lindex $args 0]
		set sw [string tolower [lindex $args 1]]
	}
	set nr [getLightNumberByName $nr]
	if { [string first Exit $nr] > 0} { 
		return $nr
		exit 1	
	}
	if {[regexp $sw "ontrue1"]} {
	  set sw true
	} elseif {[regexp $sw "offalse0"]} {
	  set sw false
	} elseif {[regexp $sw "switchtoggle"]} {
	  set sw "toggle"
	} elseif {[regexp $sw "read"]} {
	  set sw "read"
	} else {
		puts "Wrong parameter $args]"
		exit 1
	}
	set l "$nr on " ;# erstes Argument ist das Light ( 1, 2, ...)
	if { [string first Tools [info loaded]] < 0 } {
		global script_path
		load $script_path/bin/libTools[info sharedlibextension]
	}
	eval [ jsonMapper [jsonparser light [hueGet "lights/$nr"] places ] ]
	set onOff $light(state,on)
	if { "$sw" == "read" } {
		return "$onOff"
		exit 0
	} elseif { "$sw" == "$onOff" } {
		exit 0
	}  elseif { "$sw" == "toggle" } {
		if { $onOff == true } {
			set sw  false
		} else {
			set sw  true
		}		
	}
	set l "$l $sw"
	set body ""
	if { [info exists l] } {
		set body [getBody $l];# Paare von Bodyarguments in beliebiger Reihenfolge
	}
	if { $body != ""} {
		# set body [string range $body 1 end]
		set url "lights/$nr/state"
		puts [huePut $url "{$body}"]
	}
}
if { [info script] eq $::argv0 } {
	set script_path [file normalize [file dirname $argv0]]
	source [file join $script_path "preferences.tcl"]
	source [file join $script_path "hue.inc.tcl"]
	puts [LightOnOff {*}$argv]
} 
