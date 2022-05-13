#!/usr/bin/env tclsh
global ip user light ;# set in config.tcl
set script_path [file normalize [file dirname $argv0]]
source [file join $script_path "preferences.tcl"]
source [file join $script_path "hue.inc.tcl"]
#source [file join $script_path "json/json.tcl"]
#json light [hueGet "lights"]
#set_places light 
if {$argc > 0 } {
	set nr [lindex $argv 0]
	set nr [getLightNumberByName $nr]
	if { [string first Exit $nr] > 0} { 
		puts $nr
		exit 1	
	}
	set light(number) $nr
#	json light [hueGet "lights/$nr"]
	load $script_path/bin/libTools[info sharedlibextension]
	eval [ jsonMapper [jsonparser light [hueGet "lights/$nr"]] ]
	# argc > 1 then long output else short
	if { [info exists light(state,xy)] } {
    	set light(rgb) [calcRGB $light(modelid) $light(state,xy)]	
	}
	set a "s"
	if {$argc > 1} { 
		set a [lindex $argv 1]
	}
	if {$argc < 2 || "$a" == "l"} { ;# Aufruf nicht durch ccu_read_hue.tcl
		if { "$a" != "l" } {
			unset light(swversion)
			unset light(swupdate,state)
			unset light(swupdate,lastinstall)
			unset light(state,mode)
			unset light(type)
			unset light(uniqueid)
			unset light(capabilities,streaming,proxy)
			unset light(capabilities,streaming,renderer)
			unset light(manufacturername)
			if { [info exists light(swconfigid) ] } {
				unset light(swconfigid) 
			}
			if { [info exists light(productid) ] } {
				unset light(productid) 
			}
		} else {
			set light(gamut) [gamutForModel $light(modelid)]	
		}
		parray light
	} else {
		return [array get light]
	}
} {
	puts "Usage: [info script] Lightnumber"
}

