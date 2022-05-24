#!/usr/bin/env tclsh
global bridgeNr resolveV1 groupsV1 bridgeListgroupsV1 bridgeListNgroupsV1 
set script_path [file normalize [file dirname $argv0]]
source [file join $script_path "preferences.tcl"]
source [file join $script_path "hue.inc.tcl"]
source [file join $script_path "hue2.inc.tcl"]
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
		set reset 1
		set argv [lrange $argv 1 end]
		set argc [expr $argc - 1]
	}
}
set a "s"
if {$argc > 0} { 
	set a [lindex $argv 0]
}
if {[testIt groupsV1 0] != 1 || $reset != 0 } {
	# all bridges
	testIt light 1
	testIt device 1
	writeIt groupsV1
	readIt groupsV1 
	foreach br $bridgeListgroupsV1 {
		set i 1
		while { [info exists groupsV1($br,[format "%0${places}d" $i],name) ] } {
			set m "($br,[format "%0${places}d" $i],lights,"
			joinItems "groupsV1" "$m"
			set j [format "%0${places}d" $i]
			set l $groupsV1($br,$j,lights)
			set l [split $l ,]
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
} else {
	if { $all == 1 } {
		readIt groupsV1 
	} else {
		readIt groupsV1 "groupsV1($bridgeNr,*"
	}
}
if {"$a" == "h"} {
	set filename "Groups.html"
	set fileId [open $filename "w"]
	puts $fileId  "<html><meta charset=\"utf-8\" />"
	puts $fileId "<head><style>"
	puts $fileId "th, td {padding: 10px;}"
	puts $fileId "</style></head>"
	puts $fileId "<table  width=100%>"
	set tr1 "<tr style=\"height:40px;background:#00688B; color:white\">"
	set tr2 "<tr style=\"height:35px;background:#A3A3A3; color:red\">"
	set tr "<tr style=\"height:30px;background:#A3A3A3; color:white\">"
	set out {}
	set dummy 0
	foreach j $bridgeListgroupsV1 {
		set strBridge [lindex $bridgeListNgroupsV1 $j]
		lappend out "<span dummy=\"$dummy\">$tr2<td colspan=\"6\">Bridge $strBridge</td></tr>"
		incr dummy
		set i 1
		while { [info exists groupsV1($j,[format "%0${places}d" $i],name) ] } {
			set sc [format "%0${places}d" $i]
			set class ""
			if {[info exists groupsV1($j,$sc,class)]} {
				set class $groupsV1($j,$sc,class)
			}
			lappend out "<span dummy=\"$dummy\">$tr<td>$sc</td><td>$groupsV1($j,$sc,name)</td><td>$groupsV1($j,$sc,type)</td><td>$class</td><td>$groupsV1($j,$sc,lightNames)</td><td>$groupsV1($j,$sc,lights)</td></tr>"
			incr i
			incr dummy
		}
	}
	puts $fileId "$tr1<td>ID</td><td>Name</td><td>Type</td><td>Class</td><td>Lightnames</td><td>Lights</td></tr>"
	puts $fileId [join [lsort -dictionary $out] "\n"]
	puts $fileId "</table></html>"
	close $fileId
	exec sed -i "" "s/,/, /g" $filename
	exec open $filename
	exit
} elseif {"$a" == "l"} { ;# Aufruf nicht durch ccu_read_hue.tcl
	parray groupsV1
}

