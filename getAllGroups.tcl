#!/usr/bin/env tclsh
if {[package vcompare [package provide Tcl] 8.4] < 0} {
	set script_path [file dirname $argv0]
} else {
	set script_path [file normalize [file dirname $argv0]]
}

source [file join $env(HOME) ".config.hue.tcl"]
source [file join $script_path "hue.inc.tcl"]
load $script_path/bin/libTools[info sharedlibextension]
set places 2
eval [ jsonMapper [jsonparser group [hueGet "groups"] $places] ]
set a "s"
if {$argc > 0} { 
	set a [lindex $argv 0]
}
set i 1
while { [info exists group([format "%0${places}d" $i],name) ] } {
	set l $group([format "%0${places}d" $i],lights)
	set l [string map {"\""  ""} $l]
	set j [format "%0${places}d" $i]
	set group($j,lights) $l
	set l [split $l ,]
	set lightNames {}
	foreach lightNr $l {
		eval [ jsonMapper [jsonparser light [hueGet "lights/$lightNr"]] ]
		lappend lightNames $light(name)
	}
	set group($j,lightNames) [join $lightNames ,]
	if { "$a" != "l" } {
		if { [info exists group($j,action,alert)] } {
			unset group($j,action,alert)
		}
		if { [info exists group($j,action,bri)] } {
			unset group($j,action,bri)
		}
		if { [info exists group($j,action,colormode)] } {
			unset group($j,action,colormode)
		}
		if { [info exists group($j,action,ct)] } {
			unset group($j,action,ct)
		}
		if { [info exists group($j,action,effect)] } {
			unset group($j,action,effect)
		}
		if { [info exists group($j,action,hue)] } {
			unset group($j,action,hue)
		}
		if { [info exists group($j,action,sat)] } {
			unset group($j,action,sat)
		}
		if { [info exists group($j,recycle)] } {
			unset group($j,recycle)
		}
	}
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

