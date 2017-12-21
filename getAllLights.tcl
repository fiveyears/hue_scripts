#!/usr/bin/env tclsh
global ip user light ;# gesetzt für den Aufruf durch ccu_read_hue.tcl
set script_path [file dirname [info script]]
source [file join $script_path "config.tcl"]
source [file join $script_path "hue.inc.tcl"]
#source [file join $script_path "json/json.tcl"]
#json light [hueGet "lights"]
#set_places light 
set places 2
load $script_path/json/libTools[info sharedlibextension]
eval [jsonparser light [hueGet "lights"] $places ]
set a "s"
if {$argc > 0} { 
	set a [lindex $argv 0]
}
if { "$a" != "l" } {
	set i 1
	while { [info exists light([format "%0${places}d" $i],swversion) ] } {
		unset light([format "%0${places}d" $i],swversion)
		unset light([format "%0${places}d" $i],swupdate,state)
		unset light([format "%0${places}d" $i],swupdate,lastinstall)
		if { [info exists light([format "%0${places}d" $i],productid) ] } {
			unset light([format "%0${places}d" $i],productid) 
		}
		if { [info exists light([format "%0${places}d" $i],swconfigid) ] } {
			unset light([format "%0${places}d" $i],swconfigid) 
		}
		unset light([format "%0${places}d" $i],state,mode)
		unset light([format "%0${places}d" $i],type)
		unset light([format "%0${places}d" $i],uniqueid)
		unset light([format "%0${places}d" $i],capabilities,streaming,proxy)
		unset light([format "%0${places}d" $i],capabilities,streaming,renderer)
		unset light([format "%0${places}d" $i],manufacturername)
		incr i
	}
} else {
	set i 1
	while { [info exists light([format "%0${places}d" $i],swversion) ] } {
		set light([format "%0${places}d" $i],gamut) [gamutForModel $light([format "%0${places}d" $i],modelid)]	
		incr i
	}
}
parray light

