#!/usr/bin/env tclsh
global ip user light ;# set in config.tcl
set script_path [file normalize [file dirname $argv0]]
source [file join $script_path "preferences.tcl"]
source [file join $script_path "hue.inc.tcl"]
set places 2
load $script_path/bin/libTools[info sharedlibextension]
eval [ jsonMapper [jsonparser light [hueGet "lights"] $places ] ]
set a "s"
if {$argc > 0} { 
	set a [lindex $argv 0]
}
if { "$a" != "l" && "$a" != "h" } {
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
		if {[info exists light([format "%0${places}d" $i],state,xy)] } {
        	set light([format "%0${places}d" $i],rgb) [calcRGB $light([format "%0${places}d" $i],modelid) $light([format "%0${places}d" $i],state,xy)]	
        } else {
        	set light([format "%0${places}d" $i],rgb) "not available"
        }
		incr i
	}
}
if {"$a" == "h"} {
	set filename "Lights.html"
	set fileId [open $filename "w"]
	puts $fileId  "<html><meta charset=\"utf-8\" />"
	puts $fileId "<head><title>All Lights</title><style>"
	puts $fileId "th, td {padding: 10px;}"
	puts $fileId "</style></head>"
	puts $fileId "<table  width=100%>"
	set tr1 "<tr style=\"height:40px;background:#00688B; color:white\">"
	set tr "<tr style=\"height:30px;background:#7FFF00\">"
	set tr_off "<tr style=\"height:30px;background:#A3A3A3; color:white\">"
	set i 1
	while { [info exists light([format "%0${places}d" $i],name) ] } {
		set sc [format "%0${places}d" $i]
		set bri ""
		catch { set bri "bri $light($sc,state,bri) "	}
		set effect ""
		catch { set effect "effect  $light($sc,state,effect) "	}
		set xy ""
		catch { set xy "xy  $light($sc,state,xy) "	}
		set alert ""
		catch { set alert "alert  $light($sc,state,alert) "	}
		set sat ""
		catch { set sat "sat  $light($sc,state,sat) "	}
		set state "on $light($sc,state,on) $bri$effect$xy$alert$sat"
		if {$light($sc,state,on) == "true" } {
			set ttr $tr
		} else {
			set ttr $tr_off
		}
		set ct none
		if { [info exists light($sc,state,ct) ] } {
			set ct $light($sc,state,ct)
		}
		set other ""
		catch { set other "$light($sc,state,colormode)"	}
		set hue ""
		catch { set hue "$light($sc,state,hue)"	}
		lappend out "$ttr<td>$sc</td><td>$light($sc,name)</td><td>$light($sc,modelid)</td><td>$state</td><td>$light($sc,rgb)</td><td>$ct</td></td><td>$hue</td><td>$other</td></tr>"
		incr i
	}
	puts $fileId "$tr1<td>ID</td><td>Name</td><td>Model ID</td><td>State</td><td>RGB</td><td>CT</td><td>Hue</td><td>Colormode</td></tr>"
	puts $fileId [join  $out "\n"]
	puts $fileId "</table></html>"
	close $fileId
	exec open $filename
	exit
} elseif { "$a" == "s" } {
	parray light
} else {
	return [array get light]
}

