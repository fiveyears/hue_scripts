#!/usr/bin/env tclsh
global resolveV1 groupsV1 PRODUCT
if { "[info script]" == "$::argv0" } {
	set script_path [file normalize [file dirname $argv0]]
	source [file join $script_path "preferences.tcl"]
	source [file join $script_path "hue.inc.tcl"]
	load $script_path/bin/v2/libTools[info sharedlibextension]
	set places 2
	if { "$reset" == 1 } {
		writeIt device
		writeIt groupsV1
	} else {
		testIt device 1
		testIt groupsV1 1
	}
} else {
	global places reset group light device script_path
	if { "$reset" == 1 } {
		writeIt groupsV1
	} else {
		testIt groupsV1 1
	}
}
readIt groupsV1 "" 1 0
set a "s"
if {$argc > 0} { 
	set a [lindex $argv 0]
}
source_with_args [file join [file dirname [info script]] "getAllLights.tcl" ] 
foreach li [lsort [array names groupsV1 -regexp {^[0-9]+,name$}]] {
	set i [scan [lindex [split $li , ] 0] %d]
	set j [format "%0${places}d" $i]
	joinItems "groupsV1" "($j,lights,"
	set l [split $groupsV1($j,lights) " "]
	set lightNames {}
	set k 0
	foreach ll $l {
		readIt light "(\[0-9\]*,id_v1).*/lights/$ll\"$" 1
		set nr ""
		foreach n [array names light *,id_v1] {
			set nr [lindex [split $n ,] 0]
		}
		if { $nr != "" } {
			readIt light "($nr,id)" 1
			set deviceId $light($nr,id)
			if { $deviceId == "" } {
				exit
			}
			set groupsV1($j,lightId,[format "%0${places}d" $k]) $deviceId
			readIt device "$deviceId" 1
			set devNr [lindex [split [lindex [array names device] 0] ,] 0]
			set m "device($devNr,metadata,name)"
			set rid "device($devNr,id)"
			readIt device "$m" 1	
			set strLight [set $m]
			readIt device "$rid" 1	
			set rid [set $rid]
			set groupsV1($j,lightName,[format "%0${places}d" $k]) $strLight
			set groupsV1($j,deviceId,[format "%0${places}d" $k]) $rid
			incr k
			lappend lightNames $strLight
		}
	}
	set groupsV1($j,lightNames) [join $lightNames ,]
}

if {"$a" == "h"} {
	if { "$PRODUCT" == "raspmatic_rpi3" } {
		set filename "/usr/local/etc/config/addons/www/hue/Groups.html"
	} else {
		set filename "Groups.html"
	}
	set fileId [open $filename "w"]
	puts $fileId  "<html><meta charset=\"utf-8\" />"
	puts $fileId "<head><link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/bootstrap@4.1.3/dist/css/bootstrap.min.css\" integrity=\"sha384-MCw98/SFnGE8fJT3GXwEOngsV7Zt27NXFoaoApmYm81iuXoPkFOJwJ8ERdknLPMO\" crossorigin=\"anonymous\">"
	puts $fileId "</head><body onload=\"doIt();\"><table class='table'>"
	set strBridge [exec head -n 1 [file join $configPath info.txt]]
	set out {}
	lappend out "<tr class='table-info'><td colspan=\"7\">Bridge $strBridge</td></tr>"
	foreach li [lsort [array names groupsV1 -regexp {^[0-9]+,name$}]] {
		set i [scan [lindex [split $li , ] 0] %d]
		set sc [format "%0${places}d" $i]
		if {$groupsV1($sc,state,any_on) == "true" } {
			# set buttontext on
			set ttr "<tr id='tr$i' class='table-light'>"
			set opacity 1
			set buttontext on
		} else {
			set ttr "<tr id='tr$i' class='table-active'>"
			set buttontext off
			set opacity 0.5
		}
		set button "<button id='b$i' onClick='toggle(this.id)' class=' btn-sm' role='button' style='width: 35px; border: 1px solid black;background-color:white;opacity:$opacity'>$buttontext</button>"
		set class ""
		if {[info exists groupsV1($sc,class)]} {
			set class $groupsV1($sc,class)
		}
		lappend out "$ttr<td>$sc</td><td>$groupsV1($sc,name)</td><td>$button</td><td>$groupsV1($sc,type)</td><td>$class</td><td>$groupsV1($sc,lightNames)</td><td>$groupsV1($sc,lights)</td></tr>"
	}
	puts $fileId "<thead class='thead-dark'><tr><th class='text-left'>ID</th><th class='text-left'>Name</th><th style=\"width: 33px\">Switch</th><th class='text-left'>Type</th><th class='text-left'>Class</th><th class='text-left'>Lightnames</th><th class='text-left'>Lights</th></tr></thead><tbody>"
	puts $fileId [join  $out "\n"]
	puts $fileId "</tbody></table></html>"
	close $fileId
	if {[catch {exec sed -i "" "s/,/, /g" $filename}]} {
		exec sed -i "s/,/, /g" $filename
	}
	if { "$PRODUCT" == "raspmatic_rpi3" } {
		puts "https://192.168.2.30/addons/hue/Groups.html"
	} else {
		exec open $filename
	}
} elseif {"$a" == "l"} { ;# Aufruf nicht durch ccu_read_hue.tcl
	parray groupsV1
}

