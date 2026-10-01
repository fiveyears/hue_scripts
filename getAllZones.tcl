#!/usr/bin/env tclsh
# zones (v2 resource "zone") with their lights
# ./getAllZones.tcl l ... list the zone array
# ./getAllZones.tcl h ... write Zones.html
global zone light grouped_light PRODUCT
if { "[info script]" == "$::argv0" } {
	set script_path [file normalize [file dirname $argv0]]
	source [file join $script_path "preferences.tcl"]
	source [file join $script_path "hue.inc.tcl"]
} else {
	global script_path reset configPath
}
set places 2
if { "$reset" == 1 } {
	writeIt zone
	writeIt light
	writeIt grouped_light
} else {
	testIt zone 1
	testIt light 1
	testIt grouped_light 1
}
readIt zone "" 1
readIt light "" 1
readIt grouped_light "" 1
set a "s"
if {$argc > 0} {
	set a [lindex $argv 0]
}
# v2 light id -> index in array light
foreach k [array names light -regexp {^[0-9]+,id$}] {
	set lightIndex($light($k)) [lindex [split $k ,] 0]
}
# v2 grouped_light id -> on state
foreach k [array names grouped_light -regexp {^[0-9]+,id$}] {
	set nr [lindex [split $k ,] 0]
	if {[info exists grouped_light($nr,on,on)]} {
		set groupOn($grouped_light($k)) $grouped_light($nr,on,on)
	}
}
foreach li [lsort [array names zone -regexp {^[0-9]+,metadata,name$}]] {
	set j [lindex [split $li ,] 0]
	set zone($j,name) $zone($li)
	set zone($j,id_v1) [string map {"/groups/" {}} $zone($j,id_v1)]
	set lightNames {}
	set lights {}
	foreach c [lsort [array names zone -regexp "^$j,children,\[0-9\]+,rid$"]] {
		set rid $zone($c)
		if {[info exists lightIndex($rid)]} {
			set nr $lightIndex($rid)
			lappend lightNames $light($nr,metadata,name)
			lappend lights [string map {"/lights/" {}} $light($nr,id_v1)]
		}
	}
	set zone($j,lightNames) [join $lightNames ,]
	set zone($j,lights) [join $lights " "]
	set zone($j,on) false
	foreach s [array names zone -regexp "^$j,services,\[0-9\]+,rid$"] {
		if {[info exists groupOn($zone($s))]} {
			set zone($j,on) $groupOn($zone($s))
		}
	}
}

if {"$a" == "h"} {
	if { "$PRODUCT" == "raspmatic_rpi3" } {
		set filename "/usr/local/etc/config/addons/www/hue/Zones.html"
	} else {
		set filename "Zones.html"
	}
	set fileId [open $filename "w"]
	puts $fileId  "<html><meta charset=\"utf-8\" />"
	puts $fileId "<head><link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/bootstrap@4.1.3/dist/css/bootstrap.min.css\" integrity=\"sha384-MCw98/SFnGE8fJT3GXwEOngsV7Zt27NXFoaoApmYm81iuXoPkFOJwJ8ERdknLPMO\" crossorigin=\"anonymous\">"
	puts $fileId "</head><body><table class='table'>"
	set strBridge [exec head -n 1 [file join $configPath info.txt]]
	set out {}
	lappend out "<tr class='table-info'><td colspan=\"5\">Bridge $strBridge</td></tr>"
	foreach li [lsort [array names zone -regexp {^[0-9]+,name$}]] {
		set j [lindex [split $li ,] 0]
		if {$zone($j,on) == "true" } {
			set ttr "<tr class='table-light'>"
		} else {
			set ttr "<tr class='table-active'>"
		}
		lappend out "$ttr<td>$zone($j,id_v1)</td><td>$zone($j,name)</td><td>$zone($j,on)</td><td>$zone($j,lightNames)</td><td>$zone($j,lights)</td></tr>"
	}
	puts $fileId "<thead class='thead-dark'><tr><th class='text-left'>ID</th><th class='text-left'>Name</th><th class='text-left'>On</th><th class='text-left'>Lightnames</th><th class='text-left'>Lights</th></tr></thead><tbody>"
	puts $fileId [join  $out "\n"]
	puts $fileId "</tbody></table></html>"
	close $fileId
	if {[catch {exec sed -i "" "s/,/, /g" $filename}]} {
		exec sed -i "s/,/, /g" $filename
	}
	if { "$PRODUCT" == "raspmatic_rpi3" } {
		puts "https://192.168.2.30/addons/hue/Zones.html"
	} else {
		exec open $filename
	}
} elseif {"$a" == "l"} {
	parray zone
}
