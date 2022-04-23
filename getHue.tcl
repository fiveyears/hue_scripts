#!/usr/bin/env tclsh
# Created with /Users/ivo/Dropbox/Shell-Scripts/cmd/crea at 2021-11-30 13:11:13
if {[package vcompare [package provide Tcl] 8.4] < 0} {
	set script_path [file dirname $argv0]
} else {
	set script_path [file normalize [file dirname $argv0]]
}
global id ip key
source [file join $script_path "hue2.inc.tcl"]
if { [string first Tools [info loaded]] < 0 } {
	load $script_path/bin/libTools[info sharedlibextension]
}

set ip [ exec  ifconfig | grep "inet " | grep "broadcast\\\|Bcast" | awk "{print \$2}" ]
if {  [regexp {192\.168\.3\.} $ip]} {
	# puts berlin
	set user "set user wGKZzEOsw7IhkhrYcdyFlKXquCBzpthZPqeySvs5"
    set key "set key WtgJYMIaRlK1yUEJ8pNLSBWNQzUSkE9D6PinLHp3"
} else {
	# puts Dresden
	set user "set user 4w5m2-1-0nf-CmVv8gf6V4zFBawat6haJMxorwGw"
	set key "set key Dsyc5kb5hQkMTtAT9qipDJNuBoXtHylwyVBDMEej"
}
if { "$env(HOME)" == "/root" } {
	set config [file join $script_path  "bin/.config.hue.tcl"]
} else {
	set config [file join $env(HOME) ".config.hue.tcl"]
}
set url https://discovery.meethue.com
set again {}
set dagain { (again)}
#
# read config
catch {
	set ret {}; set ret [exec cat "$config" | grep "set user" | "sed s/set user *//g"]
}
if {[string trim $ret] != ""} {
	set user "set user $ret"
}
catch {
	set ret {}; set ret [exec cat "$config" | grep "set key"  | "sed s/set key *//g"]
}
if {[string trim $ret] != ""} {
	set key "set key $ret"
}
proc Discovery {} {
	global url script_path Base
	global options dagain again
	set dagain " (again)"
	set again ""
	set s ""
	set baseCount 0
	set options {}
	set s [exec curl -s "$url"  | [file dirname [info script]]/bin/jsondump] 
    eval  [readYaml $s Base]
    set j 0
    set k 1
    while {[info exists "Base($j)(id)"]} {
		puts "$k ... Save Bridge ID: [set Base($j)(id)] IP: [set Base($j)(internalipaddress)]"
		lappend options $k
    	incr j
    	incr k
    }
}

proc mDNS {} {
	global options again dagain
	set again " (again)"
	set dagain ""
	set options {}
	set service [exec ./bin/mdns --discovery | grep _hue | sed "s/.*PTR //" | sed "s/ rclass.*//" | sort | uniq]
	set services [split $service "\n"]
	foreach s $services {
		set res [exec ./bin/mdns --query "$s" | grep { A \|TXT}  | sort | uniq]
	}
	set bridgeIPs [string trim [exec echo "$res" | awk -F ":5353 : additional" {{print $1}}  |  awk {{ sub(/^[ \t]+/, ""); print }} | grep -v {^\s*\[} | sort | uniq]]
	set bridgeIPs [split $bridgeIPs "\n"]
	set bridgeCount [llength $bridgeIPs]
	set j 0
	foreach aBridgeIP $bridgeIPs {
		set tmpBridgeIP ""
		set tmpid ""
		set tmpModelID ""
		set tmpBridgeIPv6 ""
		catch {
			set tmpBridgeIP [string trim [exec echo "$res" | grep "^\\s*$aBridgeIP" | grep " A " | awk -F " A " {{print $2}}]]
		}
		catch {
			set tmpid [string trim [exec echo "$res" | grep "^\\s*$aBridgeIP" | grep -E " TXT (bridge)?id = " | awk -F " TXT (bridge)?id = " {{print $2}}]]
		}
		catch {
			set tmpModelID [string trim [exec echo "$res" | grep "^\\s*$aBridgeIP" | grep " TXT modelid = " | awk -F " TXT modelid = " {{print $2}}]]
		}
		catch {
			set tmpBridgeIPv6 [string trim [exec echo "$res" | grep "$aBridgeIP"  | grep "^\\s*\\\[" | grep " A " | awk -F ":5353 : " {{print $1}}]]
		}
		global Base
		if {[string trim $tmpBridgeIP] != ""} {
		    set Base(${j})(internalipaddress) $tmpBridgeIP
		} else {
			puts "shit tmpBridgeIP"
		}
		if {[string trim $tmpid] != ""} {
		    set Base(${j})(id) $tmpid
		} else {
			puts "shit tmpid"
		}
		if {[string trim $tmpModelID] != ""} {
		    set Base(${j})(modelID) $tmpModelID
		} 
		if {[string trim $tmpBridgeIPv6] != ""} {
		    set Base(${j})(IPv6) "{$tmpBridgeIPv6}"
		} 
		set k $j
		incr j
		puts "$j ... Save Bridge ID: [set Base(${k})(id)] IP: [set Base(${k})(internalipaddress)]"
		lappend options $j
	}
}

Discovery

while 1 {
	lappend options s m d q 
	puts "s ... Show config"
	puts "m ... Try Multicast-DSN$again"
	puts "d ... Try Discovery endpoint$dagain"
	puts "q ... Quit"
	set c "" 
	while 1 {
		puts "Please choose ($options): "
		set c [string trim [string tolower [read stdin 2]]]
		if {[lsearch "$options" "$c"] >= 0 } {
			break
		}
	}
	if {$c == "q"} {
		break
	} elseif {$c == "s"} {
		puts "Config-file: $config"
		puts [exec cat $config]
		break
	} elseif {$c == "d"} {
		Discovery
	} elseif {$c == "m"} {
		mDNS
	} elseif {[lsearch "$options" "$c"] >= 0 } {
		incr c -1
		set fileId [open $config "w"]
		if {[info exists Base(${c})(internalipaddress)]} {
			puts $fileId "set ip \"[set Base(${c})(internalipaddress)]\""
			set ip [set Base(${c})(internalipaddress)]
		}
		if {[info exists Base(${c})(id)]} {
			puts $fileId "set id \"[set Base(${c})(id)]\""
			set id [set Base(${c})(id)]
		}
		if {[info exists Base(${c})(modelID)]} {
			puts $fileId "set modelid \"[set Base(${c})(modelID)]\""
		}
		if {[info exists Base(${c})(IPv6)]} {
			puts $fileId "set ipv6 [set Base(${c})(IPv6)]"
		}
		if {[info exists key]} {
			puts $fileId "$key"
			eval $key
		}
		if {[info exists user]} {
			puts $fileId "$user"
		}
		if { [info exists id] && [info exists ip]} {
			getLight -1
			foreach {key value} [array get lightIDarray] {
				puts $fileId "set \"lightIDarray($key)\" \"$value\""
			}
		}
		close $fileId
		break
	}
}

