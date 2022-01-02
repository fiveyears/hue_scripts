#!/usr/bin/env tclsh
if {[package vcompare [package provide Tcl] 8.4] < 0} {
	set script_path [file dirname $argv0]
} else {
	set script_path [file normalize [file dirname $argv0]]
}

source [file join $env(HOME) ".config.hue.tcl"]
source [file join $script_path "hue.inc.tcl"]
load $script_path/bin/libTools[info sharedlibextension]
set a "s"
if {$argc > 0} { 
	set a [lindex $argv 0]
}
eval [ jsonMapper [jsonparser scene [hueGet "scenes"]] ]
eval [ jsonMapper [jsonparser config [hueGet "config"]] ]
array set  so [array get scene *owner ]
set ll [array names  so]
set scenes {}
foreach sceneowner $ll {
	set s [lindex [split $sceneowner , ] 0 ]
	lappend scenes $s
	if { "$a" != "l" } {
		if { [info exists scene($s,locked)] } {
			unset  scene($s,locked)
		}
		if { [info exists scene($s,recycle)] } {
			unset  scene($s,recycle)
		}
		if { [info exists scene($s,version)] } {
			unset  scene($s,version)
		}
		if { [info exists scene($s,picture)] } {
			unset  scene($s,picture)
		}
		if { [info exists scene($s,lastupdated)] } {
			unset  scene($s,lastupdated)
		}
		if { [info exists scene($s,appdata,data)] } {
			unset  scene($s,appdata,data)
		}
		if { [info exists scene($s,appdata,version)] } {
			unset  scene($s,appdata,version)
		}
	}
	set o_n $scene($s,owner)
	if { [info exists config(whitelist,$o_n,name)] } {
		set scene($s,ownerName) $config(whitelist,$o_n,name)
	}
	set l $scene($s,lights)
	set l [string map {"\""  ""} $l]
	set scene($s,lights) $l
	set l [split $l ,]
	set lightNames {}
	foreach lightNr $l {
		eval [ jsonMapper [jsonparser light [hueGet "lights/$lightNr"]] ]
		lappend lightNames $light(name)
	}
	set scene($s,lightNames) [join $lightNames ,]
}
set out {}
if { "$a" == "t" } {
	set tr "\t"
	foreach sc $scenes {
		lappend out "[format "%-24s" $scene($sc,ownerName)]$tr[format "%-28s" $scene($sc,name)]$tr$sc$tr$tr[format "%-65s" $scene($sc,lightNames)]$tr$scene($sc,lights)"
	}
	puts " "
	puts "[format "%-24s" ownerName]$tr[format "%-28s" name]$tr$sc$tr$tr[format "%-65s" lightNames]${tr}lights"
	puts " "
	puts [join [lsort -dictionary $out] "\n"]
} elseif {"$a" == "h"} {
	set filename "Scenes.html"
	set fileId [open $filename "w"]
	puts $fileId  "<html><meta charset=\"utf-8\" />"
	puts $fileId "<head><style>"
	puts $fileId "th, td {padding: 10px;}"
	puts $fileId "</style></head>"
	puts $fileId "<table  width=100%>"
	set tr1 "<tr style=\"height:40px;background:#00688B; color:white\">"
	set tr "<tr style=\"height:30px;background:#A3A3A3; color:white\">"
	foreach sc $scenes {
		lappend out "$tr<td>$scene($sc,ownerName)</td><td>$scene($sc,name)</td><td>$sc</td><td>$scene($sc,lightNames)</td><td>$scene($sc,lights)</td></tr>"
	}
	puts $fileId "$tr1<td>Ownername</td><td>Name</td><td>Scene</td><td>Lightnames</td><td>Lights</td></tr>"
	puts $fileId [join [lsort -dictionary $out] "\n"]
	puts $fileId "</table></html>"
	close $fileId
	exec sed -i "" "s/,/, /g" $filename
	exec open $filename
} else {
	parray scene
}
