#!/usr/bin/env tclsh
global resolveV1 groupsV1 
if { "[info script]" == "$::argv0" } {
	set script_path [file normalize [file dirname $argv0]]
	source [file join $script_path "preferences.tcl"]
	source [file join $script_path "hue.inc.tcl"]
	load $script_path/bin/v2/libTools[info sharedlibextension]
	set places 2
	if { "$reset" == 1 } {
		writeIt group
		writeIt device
		writeIt groupsV1
		set bridges [i_getBridgeList]
	} elseif  { "$all" == 1 } {
		testIt group 1
		testIt device 1
		testIt groupsV1 1	
		set bridges [i_getBridgeList]
	} else {
		testIt group 1 "" $bridge 
		testIt device 1 "" $bridge
		testIt groupsV1 1 "" $bridge	
		set bridges $bridge
	}
} else {
	global all bridge places bridges reset group light device script_path
	if { "$reset" == 1 } {
		writeIt groupsV1
		set bridges [i_getBridgeList]
	} elseif  { "$all" == 1 } {
		testIt groupsV1 1	
		set bridges [i_getBridgeList]
	} else {
		testIt groupsV1 1 "" $bridge	
	}
}
readIt groupsV1 "" 1 0 "" $bridges
set a "s"
if {$argc > 0} { 
	set a [lindex $argv 0]
}
source_with_args [file join [file dirname [info script]] "getAllLights.tcl" ] 
foreach br $bridges {
	foreach li [lsort [array names groupsV1  -regexp "$br,\[0-9\]*,name"]] {
		set i [scan [lindex [split $li , ] 1] %d]
			set m "($br,[format "%0${places}d" $i],lights,"
			joinItems "groupsV1" "$m"
			set j [format "%0${places}d" $i]
			set l $groupsV1($br,$j,lights)
			set l [split $l " "]
			set lightNames {}
			set k 0
			foreach ll $l {
				readIt light "($br,.*lights/$ll\"$" 1
				set nr [lindex [split [pparray light return] ,] 1]
				if { $nr != "" } {
					readIt light "($br,$nr,id)" 1
					set deviceId $light($br,$nr,id)
					if { $deviceId == "" } {
						exit
					}
					set groupsV1($br,$j,lightId,[format "%0${places}d" $k]) $deviceId
					readIt device "$deviceId" 1
					set m [split [array names device] ,]
					set rid "device([lindex $m 0],[lindex $m 1],id)"
					set m "device([lindex $m 0],[lindex $m 1],metadata,name)"
					if { $m == "" || $rid == "" } {
						exit
					}
					readIt device "$m" 1	
					set strLight [set $m]
					readIt device "$rid" 1	
					set rid [set $rid]
					set groupsV1($br,$j,lightName,[format "%0${places}d" $k]) $strLight
					set groupsV1($br,$j,deviceId,[format "%0${places}d" $k]) $rid
					incr k
					lappend lightNames $strLight
				}
			}
			set groupsV1($br,$j,lightNames) [join $lightNames ,]
			incr i
		}
	}
	set out [open "[file join $script_path ".groupsV1"]" w]
	pparray groupsV1 $out
	close $out	

if {"$a" == "h"} {
	if { "$product" == "raspmatic_rpi3" } {
		set filename "/usr/local/etc/config/addons/www/hue/Groups.html"
	} else {
		set filename "Groups.html"
	}
	set fileId [open $filename "w"]
	puts $fileId  "<html><meta charset=\"utf-8\" />"
	puts $fileId "<head><link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/bootstrap@4.1.3/dist/css/bootstrap.min.css\" integrity=\"sha384-MCw98/SFnGE8fJT3GXwEOngsV7Zt27NXFoaoApmYm81iuXoPkFOJwJ8ERdknLPMO\" crossorigin=\"anonymous\">"
	puts $fileId "</head><body onload=\"doIt();\"><table class='table'>"
	set tr_bridge "<tr class='table-info'>"
	set out {}
	foreach j $groupsV1(bridgeList) {
		set strBridge $groupsV1($j,bridgeName)
		lappend out "$tr_bridge<td colspan=\"7\">Bridge $strBridge</td></tr>"
		foreach li [lsort [array names groupsV1  -regexp "$j,\[0-9\]*,name"]] {
			set i [scan [lindex [split $li , ] 1] %d]
			set sc [format "%0${places}d" $i]
			if {$groupsV1($j,$sc,state,any_on) == "true" } {
				# set buttontext on
				set ttr "<tr id='tr${j}_$i' class='table-light'>"
				set opacity 1
				set buttontext on
			} else {
				set ttr "<tr id='tr${j}_$i' class='table-active'>"
				set buttontext off
				set opacity 0.5
			}
			set button "<button id='b${j}_$i' onClick='toggle(this.id)' class=' btn-sm' role='button' style='width: 35px; border: 1px solid black;background-color:white;opacity:$opacity'>$buttontext</button>"
			set i [scan [lindex [split $li , ] 1] %d]
			set sc [format "%0${places}d" $i]
			set class ""
			if {[info exists groupsV1($j,$sc,class)]} {
				set class $groupsV1($j,$sc,class)
			}
			lappend out "$ttr<td>$sc</td><td>$groupsV1($j,$sc,name)</td><td>$button</td><td>$groupsV1($j,$sc,type)</td><td>$class</td><td>$groupsV1($j,$sc,lightNames)</td><td>$groupsV1($j,$sc,lights)</td></tr>"

		}
	}
	puts $fileId "<thead class='thead-dark'><tr><th class='text-left'>ID</th><th class='text-left'>Name</th><th style=\"width: 33px\">Switch</th><th class='text-left'>Type</th><th class='text-left'>Class</th><th class='text-left'>Lightnames</th><th class='text-left'>Lights</th></tr></thead><tbody>"
	puts $fileId [join  $out "\n"]
	puts $fileId "</tbody></table></html>"
	close $fileId
	if {[catch {exec sed -i "" "s/,/, /g" $filename}]} {
		exec sed -i "s/,/, /g" $filename
	}
	if { "$product" == "raspmatic_rpi3" } {
		puts "https://192.168.2.30/addons/hue/Groups.html"
	} else {
		exec open $filename
	}
} elseif {"$a" == "l"} { ;# Aufruf nicht durch ccu_read_hue.tcl
	parray groupsV1
}

