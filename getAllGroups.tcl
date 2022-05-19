#!/usr/bin/env tclsh
set script_path [file normalize [file dirname $argv0]]
source [file join $script_path "preferences.tcl"]
source [file join $script_path "hue.inc.tcl"]
source [file join $script_path "hue2.inc.tcl"]
load $script_path/bin/libTools[info sharedlibextension]
set places 2
# eval [ jsonMapper [jsonparser group [hueGet "groups"] $places] ]
# parray group
# unset group
set a "s"
if {$argc > 0} { 
	set a [lindex $argv 0]
}
if { "$a" != "l" } {
	getV1 "groups" "" "action sensors state recycle" 0 group
} else {
	getV1 "groups" "" "" 0 group
}


set i 1
while { [info exists group([format "%0${places}d" $i],name) ] } {
	set m "([format "%0${places}d" $i],lights,"
	joinItems "group" "$m"
	set l $group([format "%0${places}d" $i],lights)
	set j [format "%0${places}d" $i]
	set l [split $l ,]
	set lightNames {}
	getResources light "name) id_v1" "" 0 lightnames
	set k 0
	while { [info exists lightnames([format "%0${places}d" $k],metadata,name) ] } {
		set kk [format "%0${places}d" $k]
		lappend lightNames $lightnames($kk,metadata,name) 
		incr k
	}
	set group($j,lightNames) [join $lightNames ,]
	incr i
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
	set tr "<tr style=\"height:30px;background:#A3A3A3; color:white\">"
	set i 1
	set out {}
	while { [info exists group([format "%0${places}d" $i],name) ] } {
		set sc [format "%0${places}d" $i]
		set class ""
		if {[info exists group($sc,class)]} {
			set class $group($sc,class)
		}
		lappend out "$tr<td>$sc</td><td>$group($sc,name)</td><td>$group($sc,type)</td><td>$class</td><td>$group($sc,lightNames)</td><td>$group($sc,lights)</td></tr>"
		incr i
	}
	puts $fileId "$tr1<td>ID</td><td>Name</td><td>Type</td><td>Class</td><td>Lightnames</td><td>Lights</td></tr>"
	puts $fileId [join [lsort -dictionary $out] "\n"]
	puts $fileId "</table></html>"
	close $fileId
	exec sed -i "" "s/,/, /g" $filename
	exec open $filename
	exit
}
if {$argc < 2 || "$a" == "l"} { ;# Aufruf nicht durch ccu_read_hue.tcl
	parray group
}

