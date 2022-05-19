#!/usr/bin/env tclsh
if { "[info script]" == "$::argv0" } {
	puts "$::argv0 can't be started directly!"
	exit 1 
}
if { ! [info exists bridge ]} {
	set bridge 0
}
if {$argc > 1} { 
	if { "[lindex $argv 0]" == "bridge" && [regexp -all {[0-9]} "[lindex $argv 1]"] == 1} {
		set bridge "[lindex $argv 1]"
		set argv [lrange $argv 2 end]
		set argc [expr $argc - 2]
	}
}
if { "$env(HOME)" == "/root" } {
	set config [file join $script_path  "bin/.hue/$bridge/config.hue.tcl"]
} else {
	set config [file join $env(HOME) ".hue/$bridge/config.hue.tcl"]
}
if { ! [file exists "$config" ]  } {
	puts "The bridge $bridge doesn't exist!"
	exit 1
}
source "$config"
