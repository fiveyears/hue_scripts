#!/usr/bin/env tclsh
set isc [info script]
if { "$isc" == $::argv0 } {
  global ip user id key
  set sourced 0
	if {[package vcompare [package provide Tcl] 8.4] < 0} {
		set script_path [file dirname $argv0]
	} else {
		set script_path [file normalize [file dirname $argv0]]
	}
	if { "$env(HOME)" == "/root" } {
		set config [file join $script_path  "bin/.config.hue.tcl"]
	} else {
		set config [file join $env(HOME) ".config.hue.tcl"]
	}
	source "$config"
} else {
	set sourced 1
}
package require http

proc jsonMapper { s} {
	return [string map { \[ \{ \] \} } $s]
}

proc hueGet {{url ""}} {
	global ip user
	set url "http://$ip/api/$user/$url"
	# puts $url
	set r [http::geturl $url]
	set ret [http::data $r]
	::http::cleanup $r
	regsub -all  {^.*application/json\s*} $ret "" newret
	return [encoding convertfrom utf-8 $newret]
}

proc hueDelete {{url ""}} {
	global ip user
	catch {
		set ret [exec curl -s --insecure --location --request DELETE https://$ip/api/$user/$url]
	}
	regsub -all  {^.*application/json\s*} $ret "" newret
	return [encoding convertfrom utf-8 $newret]
}

proc huePut {url body} {
	global ip user
	set body [subst $body]
	set header {PUT /api/$user/$url HTTP/1.1
HOST: $ip
Content-Length: [string length $body]
Content-Type: text/plain; charset=UTF-8
Connection: keep-alive

$body
}
	set s [socket $ip 80]
	puts $s [subst $header]
	flush $s
	set ret [read $s]
	close $s
	regsub -all  {^.*application/json\s*} $ret "" newret
	return [encoding convertfrom utf-8 $newret]
}

proc huePost {url body} {
	global ip user
	set body [subst $body]
	set body "{$body}"
	if {$url == ""} {
		set api "/api"  ;# Create Config
	} else {
		set api "/api/$user/$url"
	}
	set header {POST $api HTTP/1.1
HOST: $ip
Content-Length: [string length $body]
Content-Type: application/json; charset=UTF-8
Connection: keep-alive

$body
}
	set s [socket $ip 80]
	puts $s [subst $header]
	flush $s
	set ret [read $s]
	close $s
	regsub -all  {^.*application/json\s*} $ret "" newret
	return [encoding convertfrom utf-8 $newret]
}

proc getBody {bodyarray} {
	set body ""
	if {[llength $bodyarray] > 1} {
		for {set i 1} {$i<[llength $bodyarray]} {incr i} {
		   set n [lindex $bodyarray $i]
		   incr i
		   set v [lindex $bodyarray $i]
		   # puts "$n $v"
		   if {$v != ""} {
		   		switch $n {
		   			on {
		   				set body "$body,\"on\":$v"
		   			}
		   			bri {
		   				set body "$body,\"bri\":$v"
		   			}
		   			bri_inc {
		   				set body "$body,\"bri_inc\":$v"
		   			}
		   			hue {
		   				set body "$body,\"hue\":$v"
		   			}
		   			name {
		   				set body "$body,\"name\":\"$v\""
		   			}
		   			description {
		   				set body "$body,\"description\":\"$v\""
		   			}
		   			time {
		   				set body "$body,\"time\":\"$v\""
		   			}
		   			lat {
		   				set body "$body,\"lat\":\"$v\""
		   			}
		   			long {
		   				set body "$body,\"long\":\"$v\""
		   			}
		   			localtime {
		   				set body "$body,\"localtime\":\"$v\""
		   			}
		   			status {
		   				set body "$body,\"status\":\"$v\""
		   			}
		   			autodelete {
		   				set body "$body,\"autodelete\":$v"
		   			}
		   			address {
		   				set body "$body,\"address\":\"$v\""
		   			}
		   			method {
		   				set body "$body,\"method\":\"$v\""
		   			}
		   			hue_inc {
		   				set body "$body,\"hue_inc\":$v"
		   			}
		   			sat {
		   				set body "$body,\"sat\":$v"
		   			}
		   			sat_inc {
		   				set body "$body,\"sat_inc\":$v"
		   			}
		   			transitiontime {
		   				set body "$body,\"transitiontime\":$v"
		   			}
		   			effect {
		   				set body "$body,\"effect\":\"$v\""
		   			}
		   			alert {
		   				set body "$body,\"alert\":\"$v\""
		   			}
		   			scene {
		   				set body "$body,\"scene\":\"$v\""
		   			}
		   			ct {
		   				set body "$body,\"ct\":$v"
		   			}
		   			ct_inc {
		   				set body "$body,\"ct_inc\":$v"
		   			}
		   			xy {
		   				set body "$body,\"xy\":\\\[$v\\\]"
		   			}
		   			xy_inc {
		   				set body "$body,\"xy_inc\":\\\[$v\\\]"
		   			}
		   			command {
		   				set innerBody [lrange $bodyarray $i end]
		   				set i [llength $bodyarray]
		   				set body "$body,\"command\":{[getBody "0 $innerBody"]}"
		   			}
		   			body {
		   				set innerBody [lrange $bodyarray $i end]
		   				set i [llength $bodyarray]
		   				set body "$body,\"body\":{[getBody "0 $innerBody"]}"
		   			}
		   		}
		   } else {
		   		switch $n {
		   			on {
		   				set body "$body,\"on\":true"
		   			}
		   			off {
		   				set body "$body,\"on\":false"
		   			}
		   		}
		   }
		}

	}
	if { $body != "" } {
		set body [string range $body 1 end]
	}
	return $body
}

proc wsplit {str sep} {
  split [string map [list $sep \0] $str] \0
}

proc getSensorNumberByName { str } {
	global script_path
  if { [string first Tools [info loaded]] < 0 } {
		load $script_path/bin/libTools[info sharedlibextension]
	}
	# set places 2
	set nr $str
	if { [string is digit $nr ]} {
		set nr [string trimleft $nr 0]
	} else {
		eval [ jsonMapper [jsonparser t [hueGet "sensors"] 1 ] ]
		set names [array get t "*,name*"]
		set pos [lsearch  $names $nr]
		if { $pos < 0 } 	{
			puts "Sensor '$nr' not found! Exit"
			exit 0
		}
		incr pos -1
		set nr [lindex $names $pos]
		set nr  [lindex [split $nr , ] 0 ]
	}
	return $nr
}

proc getScheduleNumberByName { str } {
	global script_path
	if { [string first Tools [info loaded]] < 0 } {
		load $script_path/bin/libTools[info sharedlibextension]
	}
	# set places 2
	set nr $str
	if { [string is digit $nr ]} {
		set nr [string trimleft $nr 0]
	} else {
		eval [ jsonMapper [jsonparser t [hueGet "schedules"] 1 ] ]
		set names [array get t "*,name*"]
		set pos [lsearch  $names $nr]
		if { $pos < 0 } 	{
			puts "Schedule '$nr' not found! Exit"
			exit 0
		}
		incr pos -1
		set nr [lindex $names $pos]
		set nr  [lindex [split $nr , ] 0 ]
	}
	return $nr
}

proc getLightNumberByName { str } {
	global script_path
	if { [string first Tools [info loaded]] < 0 } {
		load $script_path/bin/libTools[info sharedlibextension]
	}
	# set places 2
	set nr $str
	if { [string is digit $nr ]} {
		set nr [string trimleft $nr 0]
	} else {
		eval [ jsonMapper [jsonparser t [hueGet "lights"] 1 ] ]
		set names [array get t "*,name*"]
		set pos [lsearch  $names $nr]
		if { $pos < 0 } 	{
			puts "Light '$nr' not found! Exit"
			exit 0
		}
		incr pos -1
		set nr [lindex $names $pos]
		set nr  [lindex [split $nr , ] 0 ]
	}
	return $nr
}

proc getGroupNumberByName { str } {
	global script_path
	if { [string first Tools [info loaded]] < 0 } {
		load $script_path/bin/libTools[info sharedlibextension]
	}
	# set places 2
	set nr $str
	if { [string is digit $nr ]} {
		set nr [string trimleft $nr 0]
		if { $nr == {} } {
			set nr 0
		}
	} else {
		eval [ jsonMapper [jsonparser t [hueGet "groups"] 1 ] ]
		set names [array get t "*,name*"]
		set pos [lsearch  $names $nr]
		if { $pos < 0 } 	{
			puts "Group '$nr' not found! Exit"
			exit 0
		}
		incr pos -1
		set nr [lindex $names $pos]
		set nr  [lindex [split $nr , ] 0 ]
	}
	return $nr
}
