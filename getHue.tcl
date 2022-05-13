#!/usr/bin/env tclsh
# Created with /Users/ivo/Dropbox/Shell-Scripts/cmd/crea at 2021-11-30 13:11:13
set script_path [file normalize [file dirname $argv0]]
global id ip user
source [file join $script_path "hue.inc.tcl"]
source [file join $script_path "hue2.inc.tcl"]
if { [string first Tools [info loaded]] < 0 } {
	load $script_path/bin/libTools[info sharedlibextension]
}

# set ip [ exec  ifconfig | grep "inet " | grep "broadcast\\\|Bcast" | awk "{print \$2}" ]
set bridgeNr 0
if { $argc > 0 && [string length "$argv"] == 1 } {
	set bridgeNr  "$argv"
}
if { "$env(HOME)" == "/root" } {
	set config [file join $script_path  "bin/.hue/$bridgeNr/config.hue.tcl"]
	set info [file join $script_path  "bin/.hue/$bridgeNr/info.txt"]
} else {
	set config [file join $env(HOME) ".hue/$bridgeNr/config.hue.tcl"]
	set info [file join $env(HOME) ".hue/$bridgeNr/info.txt"]
}
if { ! [file exist $config] } {
	puts "Bridge $bridgeNr does not exists!"
	exit 1
}
set url https://discovery.meethue.com
set again {}
set dagain { (again)}
#
# read config
catch {
	set ret {}; set ret [exec cat "$config" | grep "set user" | grep -vi "# default values" | sed "s/set user *//g"]
}
if {[string trim $ret] != ""} {
	set user "$ret"
} else {
	set user {}
}
proc Discovery {} {
	global url script_path Base
	global options dagain again
	set dagain " (again)"
	set again ""
	set s ""
	set baseCount 0
	set options {}
	if {[catch {set s [exec curl -s -S "$url"] } erri]} {
		puts "Discovery without success (no connection)"
		return
	}
	set s [string trim $s ]
	if {"$s" == ""  || "$s" == "\[\]"} {
		puts "Discovery without success (no data)"
		return		
	}
	set s [exec echo $s | [file dirname [info script]]/bin/jsondump]
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
	if { [catch {
		set service [exec ./bin/mdns --discovery | grep _hue | sed "s/.*PTR //" | sed "s/ rclass.*//" | sort | uniq]
		set services [split $service "\n"]
		foreach s $services {
			set res [exec ./bin/mdns --query "$s" | grep { A \|TXT}  | sort | uniq]
		}
		set bridgeIPs [string trim [exec echo "$res" | awk -F ":5353 : additional" {{print $1}}  |  awk {{ sub(/^[ \t]+/, ""); print }} | grep -v {^\s*\[} | sort | uniq]]
		set bridgeIPs [split $bridgeIPs "\n"]
		set bridgeCount [llength $bridgeIPs]  } ]
	} {
		set bridgeIPs ""
		puts "mDNS without success"		
	}
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

puts "Bridge: [exec cat $info ]"
Discovery

while 1 {
	lappend options r s m d q 
	puts "r ... remote access"
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
	} elseif {$c == "r" } {
		set fileId [open $config "w"]
		puts $fileId {set user 0; set ip "0.0.0.0"; set id 0 ;# default values}
		if { "$user" != "" } {
			puts $fileId "set user $user"
		}
		set ip "api.meethue.com/route"
		puts $fileId "set ip \"$ip\""
		if { [catch {
			set s [	exec $script_path/remote.sh $bridgeNr token 1>/dev/null ]
		} curl_err]} {
			puts "Didn't get token for remote access!"
			puts "Please exec remote.sh $bridgeNr getToken first!"
			exit
		}
		set token [	exec $script_path/remote.sh $bridgeNr token ]
		set resolveV1 "--header \\\"Authorization: Bearer \[exec $script_path/remote.sh $bridgeNr token\]\\\" https://$ip/api/\$user"
		set resolveV2 "--header \\\"hue-application-key: \$user\\\" --header \\\"Authorization: Bearer \[exec $script_path/remote.sh $bridgeNr token\]\\\" https://$ip/clip/v2"
		puts $fileId "set resolveV1 \"$resolveV1\""
		puts $fileId "set resolveV2 \"$resolveV2\""
		set resolveV1 "[subst $resolveV1]"
		set resolveV2 "[subst $resolveV2]"
		if { [info exists ip] && "$user" != "" } {
			getLight -1
			foreach {key value} [array get lightIDarray] {
				puts $fileId "set \"lightIDarray($key)\" \"$value\""
			}
		}
		close $fileId
		break
	} elseif {[lsearch "$options" "$c"] >= 0 } {
		incr c -1
		set fileId [open $config "w"]
		puts $fileId {set user 0; set ip "0.0.0.0"; set id 0 ;# default values}
		if { "$user" != "" } {
			puts $fileId "set user $user"
		}
		if {[info exists Base(${c})(internalipaddress)]} {
			puts $fileId "set ip \"[set Base(${c})(internalipaddress)]\""
			set ip [set Base(${c})(internalipaddress)]
			set theName [exec cat $info | grep -vi last]
			set fileId1 [open $info "w"]
			puts $fileId1 "$theName"
			puts $fileId1 "   Last used local ip: $ip"
			close $fileId1
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
		if { [info exists id] && [info exists ip] && "$user" != "" } {
			set resolveV1 "--insecure --resolve $id:443:$ip https://$id/api/\$user"
			set resolveV2 "--insecure --header \\\"hue-application-key: \$user\\\" --resolve $id:443:$ip https://$id/clip/v2"
			puts $fileId "set resolveV1 \"$resolveV1\""
			puts $fileId "set resolveV2 \"$resolveV2\""
			set resolveV1 "[subst $resolveV1]"
			set resolveV2 "[subst $resolveV2]"
			getLight -1
			foreach {key value} [array get lightIDarray] {
				puts $fileId "set \"lightIDarray($key)\" \"$value\""
			}
		}
		close $fileId
		break
	}
}

