#!/usr/bin/env tclsh
global ip user light ;# set in config.tcl
if {[package vcompare [package provide Tcl] 8.4] < 0} {
	set script_path [file dirname $argv0]
} else {
	set script_path [file normalize [file dirname $argv0]]
}

source [file join $script_path "config.tcl"]
source [file join $script_path "hue.inc.tcl"]
source [file join $script_path "ccu_helper.tcl"]

proc writeFile {strFile data} {
	global script_path
	set fileId [open [file join $script_path $strFile] "w"]
	puts -nonewline $fileId $data
	close $fileId
}

if {$argc > 0 } {
	set echo 0
	set nr [lindex $argv 0]
	if { $nr == "-e" } {
		if {$argc > 1 } {
			set nr [lindex $argv 1]
			set echo 1
		} else {
			puts "Usage: [info script] \[-e\] Lightnumber|Name"
			exit
		}
	}
	set nr [getLightNumberByName $nr]
	if { [string first Exit $nr] > 0} { 
		puts $nr
		exit 1	
	}
	set light(number) $nr

#	json light [hueGet "lights/$nr"]
	load $script_path/bin/libTools[info sharedlibextension]
	eval [ jsonMapper [jsonparser light [hueGet "lights/$nr"]] ]
	if {$light(state,reachable) == "false" } {
		puts "Lamp '$nr' not reachable! Exit."
		exit 1
	}
    set l "$nr alert $light(state,alert) bri $light(state,bri) effect $light(state,effect) on $light(state,on) sat $light(state,sat) xy $light(state,xy) "
    if {$echo == "1" } {
		puts $l
    } elseif { [testRega] } {
        writeFile ".state${nr}_($light(name)).txt" $l
    } else {
		setVariable "state${nr}" "Status of light $nr ($light(name))" "str" 0 0 ""    "" "" "" false "" "" $l
    }

} {
	puts "Usage: [info script] \[-e\] Lightnumber|Name"
}

