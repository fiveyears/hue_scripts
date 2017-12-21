#!/usr/bin/env tclsh
global ip user light ;# gesetzt für den Aufruf durch ccu_read_hue.tcl
set script_path [file dirname [info script]]
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
    set l "$nr alert $light(state,alert) bri $light(state,bri) effect $light(state,effect) on $light(state,on) sat $light(state,sat) xy $light(state,xy) "
    if { [testRega] } {
        writeFile ".state${nr}_($light(name)).txt" $l
    } else {
		setVariable "state${nr}" "Status of light $nr ($light(name))" "str" 0 0 ""    "" "" "" false "" "" $l
    }

} {
	puts "Usage: [info script] Lightnumber|Name"
}

