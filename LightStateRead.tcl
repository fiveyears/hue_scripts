#!/usr/bin/env tclsh
global ip user light ;# gesetzt für den Aufruf durch ccu_read_hue.tcl
set script_path [file dirname [info script]]
source [file join $script_path "config.tcl"]
source [file join $script_path "hue.inc.tcl"]
source [file join $script_path "ccu_helper.tcl"]

proc readFile {strFile} {
	global script_path
	set f [file join $script_path $strFile]
	if { [file exists $f ]  } {
		set fp [open $f r]
		set file_data [read $fp]
		close $fp
	} else {
			puts "File '$strFile' not readable! Exit."
			exit 1
	}
	return $file_data
}

proc setLight {l light} {
	set body [getBody $l];# Paare von Bodyarguments in beliebiger Reihenfolge
	if { $body != ""} {
		set body [string range $body 1 end]
		set url "lights/$light/state"
		puts [huePut $url "{$body}"]
	}
}

if {$argc > 0 } {
	set nr [lindex $argv 0]
	set nr [exec $script_path/getLightNumberByName.tcl $nr]
	if { [string first Exit $nr] > 0} { 
		puts $nr
		exit 1	
	}
	set light(number) $nr

#	json light [hueGet "lights/$nr"]
	load $script_path/json/libTools[info sharedlibextension]
	eval [jsonparser light [hueGet "lights/$nr"]]
	if {$light(state,reachable) == "false" } {
		puts "Lamp '$nr' not reachable! Exit."
		exit 1
	}
    if { [testRega] } {
        set l [readFile ".state${nr}_($light(name)).txt"]
    } else {
		array set info [infoVariable "state${nr}"]
		if { [info exists info(err_text)] } {
			puts "state${nr}: $info(err_text), Exit!"
			exit 1
		}
		set l $info(Variable)
    }
    array set info [lrange $l 1 end]
    if { $info(on) == "false" } {
    	setLight " $nr on true " $nr
    }
    setLight $l $nr
    if { $info(on) == "false" } {
    	setLight " $nr on false " $nr
    }

} {
	puts "Usage: [info script] Lightnumber|Name"
}

