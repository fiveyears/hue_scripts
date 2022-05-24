#!/usr/bin/env tclsh
global bridgeNr resolveV1 lightsV1 bridgeListgroupsV1 bridgeListNgroupsV1 
set script_path [file normalize [file dirname $argv0]]
source [file join $script_path "preferences.tcl"]
source [file join $script_path "hue.inc.tcl"]
source [file join $script_path "hue2.inc.tcl"]
set v2 "/v2"
# set v2 ""
load $script_path/bin$v2/libTools[info sharedlibextension]
set places 2
# if all bridges
set all 0
set reset 0
if {$argc > 1 && "[lindex $argv 0]" == "bridge" } { 
	if { "[lindex $argv 1]" == "--all" || "[lindex $argv 1]" == "-all" } {
		set all 1
		set argv [lrange $argv 2 end]
		set argc [expr $argc - 2]
	}
} elseif {$argc > 0 } { 
	if { "[lindex $argv 0]" == "--all" || "[lindex $argv 0]" == "-all" } {
		set all 1
		set argv [lrange $argv 1 end]
		set argc [expr $argc - 1]
	} elseif { "[lindex $argv 0]" == "--reset" || "[lindex $argv 0]" == "-reset" } {
		set all 1
		set reset 1
		set argv [lrange $argv 1 end]
		set argc [expr $argc - 1]
	}
}
#test only local bridge
if { "$bridgeNr" == 0  &&  "$all" == 0} {
	set writeItParameter2 0
} elseif { "$all" == 1} {
	set writeItParameter2 0
} else {
	set writeItParameter2 -1	
}
set a ""
if {$argc > 0} { 
	set a [lindex $argv 0]
}
if {[testIt lightsV1 0] != 1 || $reset != 0 || $writeItParameter2 == 0 } {
	# all bridges
	testIt light 1
	testIt device 1
	writeIt lightsV1 $writeItParameter2
	readIt lightsV1 * 0 0 $writeItParameter2
	foreach br $bridgeListlightsV1 {
		set i 1
		while { [info exists lightsV1($br,[format "%0${places}d" $i],name) ] } {
			readIt light "($br,.*lights/$i\"$" 1
			set nr [lindex [split [pparray light return] ,] 1]
			# nr index in light array
			set m "lightsV1($br,[format "%0${places}d" $i]"
			if { $nr != "" } {
				readIt light "($br,$nr,id)" 1
				set deviceId $light($br,$nr,id)
				if { $deviceId == "" } {
					exit
				}
				# deviceId from array light
				set "$m,lightId)" $deviceId
				readIt device "$deviceId" 1
				# devNr index in array device
				set devNr [split [array names device] ,]
				set rid "device([lindex $devNr 0],[lindex $devNr 1],id)"
				set name "device([lindex $devNr 0],[lindex $devNr 1],metadata,name)"
				if { $m == "" || $rid == "" } {
					exit
				}
				readIt device "$name" 1	
				set name [set $name]
				readIt device "$rid" 1	
				set rid [set $rid]
				set "$m,metadata,name)" $name
				set "$m,deviceId)" $rid
				if {$v2 == "" } {
					if {[info exists "$m,state,xy,00)"] && [info exists "$m,state,xy,01)"] \
						&& [info exists "$m,modelid)"]} {
						set "$m,rgb)" "[calcRGB  [set "$m,modelid)"] [set "$m,state,xy,00)"],[set "$m,state,xy,01)"]]"
						# puts "$br $i [set "$m,rgb)"]"
					} else {
						set "$m,rgb)" "not available"
					}
				} else {
					if {[info exists "$m,state,xy,00)"] && [info exists "$m,state,xy,01)"] \
						&& [info exists "$m,capabilities,control,colorgamut,00,00)"] \
						&& [info exists "$m,capabilities,control,colorgamut,00,01)"] \
						&& [info exists "$m,capabilities,control,colorgamut,01,00)"] \
						&& [info exists "$m,capabilities,control,colorgamut,01,01)"] \
						&& [info exists "$m,capabilities,control,colorgamut,02,00)"] \
						&& [info exists "$m,capabilities,control,colorgamut,02,01)"] \
						} {
						set "$m,rgb)" "[calcRGB  [set "$m,state,xy,00)"] [set "$m,state,xy,01)"] \
						[set "$m,capabilities,control,colorgamut,00,00)"] \
						[set "$m,capabilities,control,colorgamut,00,01)"] \
						[set "$m,capabilities,control,colorgamut,01,00)"] \
						[set "$m,capabilities,control,colorgamut,01,01)"] \
						[set "$m,capabilities,control,colorgamut,02,00)"] \
						[set "$m,capabilities,control,colorgamut,02,01)"] \
						]"
						# puts "$br $i [set "$m,rgb)"]"
					} else {
						set "$m,rgb)" "not available"
					}

				}
			}
		incr i
		}
	}
	set out [open "[file join $script_path ".lightsV1"]" w]
	pparray lightsV1 $out
	close $out	
} else {
	readIt lightsV1 "lightsV1($bridgeNr,*"
}
if {"$a" == "h"} {
	if { "$all" == 1} {
		# read all lights again
		readIt lightsV1
	}
	set filename "Lights.html"
	set fileId [open $filename "w"]
	puts $fileId  "<html><meta charset=\"utf-8\" />"
	puts $fileId "<head><style>"
	puts $fileId ".box {
  float: none;
  height: 30px;
  width: 30px;
  border: 1px solid black;
  clear: both;
}
"
	puts $fileId "th, td {padding: 10px;}"
	puts $fileId "</style></head>"
	puts $fileId "<table  width=100%>"
	set tr1 "<tr style=\"height:40px;background:#00688B; color:white\">"
	set tr2 "<tr style=\"height:35px;background:#A3A3A3; color:red\">"
	set tr "<tr style=\"height:30px;background:#F0F0F0\">"
	set tr_off "<tr style=\"height:30px;background:#A3A3A3; color:white\">"
	set out {}
	set dummy 0
	foreach j $bridgeListlightsV1 {
		set strBridge [lindex $bridgeListNlightsV1 $j]
		lappend out "<span dummy=\"$dummy\">$tr2<td colspan=\"9\">Bridge $strBridge</td></tr>"
		incr dummy
		set i 1
		while { [info exists lightsV1($j,[format "%0${places}d" $i],name) ] } {
			set sc [format "%0${places}d" $i]
			set bri ""
			catch { set bri "bri $lightsV1($j,$sc,state,bri) "	}
			set effect ""
			catch { set effect "effect  $lightsV1($j,$sc,state,effect) "	}
			set xy ""
			catch { set xy "xy  $lightsV1($j,$sc,state,xy) "	}
			set alert ""
			catch { set alert "alert  $lightsV1($j,$sc,state,alert) "	}
			set sat ""
			catch { set sat "sat  $lightsV1($j,$sc,state,sat) "	}
			set state "on $lightsV1($j,$sc,state,on) $bri$effect$xy$alert$sat"
			if {$lightsV1($j,$sc,state,on) == "true" } {
				set ttr $tr
				set opacity 1
			} else {
				set ttr $tr_off
				set opacity 0.5
			}
			set ct none
			if { [info exists lightsV1($j,$sc,state,ct) ] } {
				set ct $lightsV1($j,$sc,state,ct)
			}
			set other ""
			catch { set other "$lightsV1($j,$sc,state,colormode)"	}
			set hue ""
			catch { set hue "$lightsV1($j,$sc,state,hue)"	}
			if { $lightsV1($j,$sc,rgb) != "not available"} {
				set rgb "<div class=\"box\" style=\"background:#$lightsV1($j,$sc,rgb);opacity:$opacity\"></div>"
			} else {
				set rgb "<div class=\"box\" style=\"background:white;opacity:$opacity\"></div>"
			}
			lappend out "<span dummy=\"$dummy\">$ttr<td>$sc</td><td>$lightsV1($j,$sc,name)</td><td>$lightsV1($j,$sc,modelid)</td><td>$state</td><td>$lightsV1($j,$sc,rgb)</td><td>$rgb</td><td>$ct</td></td><td>$hue</td><td>$other</td></tr>"
			incr i
			incr dummy
		}
	}
	puts $fileId "<span dummy=\"$dummy\">$tr1<td>ID</td><td>Name</td><td>Model ID</td><td>State</td><td>RGB</td><td style=\"width: 33px\"> </td><td>CT</td><td>Hue</td><td>Colormode</td></tr>"
	puts $fileId [join [lsort -dictionary $out] "\n"]
	puts $fileId "</table></html>"
	close $fileId
	exec sed -i "" "s/,/, /g" $filename
	exec open $filename
	exit
} elseif {"$a" == "l"} { ;# Aufruf nicht durch ccu_read_hue.tcl
	parray lightsV1
}

