#!/usr/bin/env tclsh
global light ;# set in config.tcl
if { "[info script]" == "$::argv0" } {
	set script_path [file normalize [file dirname $argv0]]
	source [file join $script_path "preferences.tcl"]
} else {
	global script_path
}
source [file join $script_path "hue.inc.tcl"]
if {$argc > 0 } {
	set nr [lindex $argv 0]
	set nr [getLightNumberByName $nr]
	if { [string first Exit $nr] > 0} { 
		puts $nr
		exit 1	
	}
	set light(number) $nr
# #	json light [hueGet "lights/$nr"]
# 	load $script_path/bin/libTools[info sharedlibextension]
# 	eval [ jsonMapper [jsonparser light [hueGet "lights/$nr"]] ]
# 	# argc > 1 then long output else short
# 	# if { [info exists light(state,xy)] } {
#  #    	set light(rgb) [calcRGB $light(modelid) $light(state,xy)]	
# 	# }
# 	set a "s"
# 	if {$argc > 1} { 
# 		set a [lindex $argv 1]
# 	}
# 	if {$argc < 2 || "$a" == "l"} { ;# Aufruf nicht durch ccu_read_hue.tcl
# 		if { "$a" != "l" } {
# 			unset light(swversion)
# 			unset light(swupdate,state)
# 			unset light(swupdate,lastinstall)
# 			unset light(state,mode)
# 			unset light(type)
# 			unset light(uniqueid)
# 			unset light(capabilities,streaming,proxy)
# 			unset light(capabilities,streaming,renderer)
# 			unset light(manufacturername)
# 			if { [info exists light(swconfigid) ] } {
# 				unset light(swconfigid) 
# 			}
# 			if { [info exists light(productid) ] } {
# 				unset light(productid) 
# 			}
# 		} else {
# 			set light(gamut) [gamutForModel $light(modelid)]	
# 		}
# 		parray light
# 	} else {
# 		return [array get light]
# 	}
# } {
# 	puts "Usage: [info script] Lightnumber"
}
# unset light
global light
getV1 lights/$nr "" "swversion streaming certified config modelid uniqueid productid swconfigid mode (type swupdate swversion manufacturername" 0 light
set m "light("
	load $script_path/bin/v2/libTools[info sharedlibextension]
if {[info exists "${m}state,xy,00)"] && [info exists "${m}state,xy,01)"] \
	&& [info exists "${m}capabilities,control,colorgamut,00,00)"] \
	&& [info exists "${m}capabilities,control,colorgamut,00,01)"] \
	&& [info exists "${m}capabilities,control,colorgamut,01,00)"] \
	&& [info exists "${m}capabilities,control,colorgamut,01,01)"] \
	&& [info exists "${m}capabilities,control,colorgamut,02,00)"] \
	&& [info exists "${m}capabilities,control,colorgamut,02,01)"] \
	} {
	set "${m}rgb)" "[calcRGB  [set "${m}state,xy,00)"] [set "${m}state,xy,01)"] \
	[set "${m}capabilities,control,colorgamut,00,00)"] \
	[set "${m}capabilities,control,colorgamut,00,01)"] \
	[set "${m}capabilities,control,colorgamut,01,00)"] \
	[set "${m}capabilities,control,colorgamut,01,01)"] \
	[set "${m}capabilities,control,colorgamut,02,00)"] \
	[set "${m}capabilities,control,colorgamut,02,01)"] \
	]"
	# puts "$br $i [set "${m}rgb)"]"
} else {
	set "${m}rgb)" "not available"
}
if {$argc == 1 } {
	parray light
}
