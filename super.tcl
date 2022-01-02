#!/usr/bin/env tclsh
if {[package vcompare [package provide Tcl] 8.4] < 0} {
	set script_path [file dirname $argv0]
} else {
	set script_path [file normalize [file dirname $argv0]]
}

source [file join $env(HOME) ".config.hue.tcl"]
source [file join $script_path "hue.inc.tcl"]
source [file join $script_path "ccu_helper.tcl"]
set i 1
if {$argc == 0 } {
  set m 0
} else {
  set m [lindex $argv 0]
  if { ($m == "-h") || ([lsearch -exact {0 1 2 3 -h} $m] < 0)} {
  	puts "usage $argv0 \[ 0 | 1 | 2 | 3 | -h]"
  	puts "  0 or no argument - switch light off "
  	puts "  1                - switch light on "
  	puts "  2                - toogle light"
  	puts "  3                - switch light on or dim when on"
  	puts " -h                - this help"
  	exit 0
  }
}


if [testRega] {
	set rega remoteRegascript
} else {
	load tclrega.so
	set rega rega_script
}
array set values [$rega {var k = dom.GetObject ("Kueche Schalter Kuehlschrank").State();} ]
set k $values(k)
if { ($k == "false" && $m == 0)  || ($k == "true" && $m == 1)} {
	puts "Nothing to do, lightstate is $m!"
	exit 0
}
if { ($k == "false" && $m ==2 ) } {
	set m 1
} elseif { ($k == "true" && $m == 2) } {
	set m 0
} elseif { ($k == "true" && $m > 2) } {
	set m 0
	set i 2
} elseif { ($k == "false" && $m > 2) } {
	set m 1
}
set x 0
while {$x<$i} {
	$rega " dom.GetObject (\"Kueche Schalter Kuehlschrank\").State($m);"
	incr x
	incr m
}
array set values [$rega {var k = dom.GetObject ("Kueche Schalter Kuehlschrank").State();} ]
set k $values(k)
if { $k == "false" } {
	puts "Light is off"
} elseif { $k == "true" } {
	puts "Light is on"
}
