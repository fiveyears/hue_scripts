#!/usr/bin/env tclsh
global ip user light ;# gesetzt für den Aufruf durch ccu_read_hue.tcl
set script_path [file dirname [info script]]
source [file join $script_path "config.tcl"]
source [file join $script_path "hue.inc.tcl"]
#source [file join $script_path "json/json.tcl"]
#json light [hueGet "lights"]
#set_places light 
if {$argc > 0 } {
	set nr [lindex $argv 0]
	set light(number) $nr
#	json light [hueGet "lights/$nr"]
	load $script_path/json/libTools[info sharedlibextension]
	eval [jsonparser light [hueGet "lights/$nr"]]
	# argc > 1 then long output else short
    set light(rgb) [calcRGB $light(modelid) $light(state,xy)]	
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
	} 
} {
	puts "Usage: [info script] Lightnumber"
}

