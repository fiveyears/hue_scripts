#!/usr/bin/env tclsh
# Created with /Users/ivo/Dropbox/Shell-Scripts/cmd/crea at 2021-11-30 13:11:13
proc helper {} {
	puts "No command is given or command without parameter!"
	puts "Usage: "
	puts "   configUser.tcl -s | --store  <User or application-key> ... stores user"
	puts "   configUser.tcl -d | --delete                           ... remove user"
	puts "   configUser.tcl -s | --show                             ... show user"
	puts "" 
	exit
}

set script_path [file normalize [file dirname $argv0]]
global user
if { "$env(HOME)" == "/root" } {
	set config [file join $script_path  "bin/.hue/0/config.hue.tcl"]
	set info [file join $script_path  "bin/.hue/0/info.txt"]
} else {
	set config [file join $env(HOME) ".hue/0/config.hue.tcl"]
	set info [file join $env(HOME) ".hue/0/info.txt"]
}
#
# read config
catch {
	set ret {}; set ret [exec cat "$config" | grep -v "set user" ]
}
if {[string trim $ret] != ""} {
	set conf "$ret"
} else {
	set conf {}
}
if {$argc == 2 } {
	set what [lindex $argv 0]
	if { $what == "-s" || $what == "--store" } {
		set user [lindex $argv 1]
		set fileId [open $config "w"]
		puts $fileId {set user 0; set ip "0.0.0.0"; set id 0 ;# default values}
		puts $fileId "set user $user"
		puts $fileId $conf
		close $fileId
	} else {
		helper
	}
} elseif {$argc == 1 } {
	set what [lindex $argv 0]
	if { $what == "-d" || $what == "--delete" } {
		set fileId [open $config "w"]
		puts $fileId {set user 0; set ip "0.0.0.0"; set id 0 ;# default values}
		puts $fileId $conf
		close $fileId
	} elseif { $what == "-s" || $what == "--show" } {
		puts "Current user: [ exec $script_path/remote.sh user ]"
		puts "Current bridge: [exec cat $info | sed "s/Last/   Last/"]"
	} else {
		helper
	}
} else {
	helper
}

