#!/usr/bin/env tclsh
set script_path [file normalize [file dirname $argv0]]
if { "$env(HOME)" == "/root" } {
	set config [file join $script_path  "bin/.hue/0/config.hue.tcl"]
} else {
	set config [file join $env(HOME) ".hue/0/config.hue.tcl"]
}
source "$config"
source [file join $script_path "hue.inc.tcl"]
load $script_path/bin/libTools[info sharedlibextension]
if {$argc > 0 } {
	set id [lindex $argv 0]

eval [ jsonMapper [jsonparser scene [hueGet "scenes/$id"]] ]
eval [ jsonMapper [jsonparser config [hueGet "config"]] ]
set l $scene(lights)
set l [string map {"\""  ""} $l]
set scene(lights) $l
set l [split $l ,]
set lightNames {}
foreach lightNr $l {
	eval [ jsonMapper [jsonparser light [hueGet "lights/$lightNr"]] ]
	lappend lightNames $light(name)
}
set scene(lightNames) [join $lightNames ,]
set o_n $scene(owner)
if { [info exists config(whitelist,$o_n,name)] } {
	set scene(ownerName) $config(whitelist,$o_n,name)
}
parray scene
exit
eval [ jsonMapper [jsonparser config [hueGet "config"]] ]
array set  so [array get scene *owner ]
set ll [array names  so]
foreach sceneowner $ll {
	set s [lindex [split $sceneowner , ] 0 ]
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
}