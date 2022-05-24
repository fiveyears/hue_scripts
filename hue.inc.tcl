#!/usr/bin/env tclsh
set isc [info script]
if { "$isc" == $::argv0 } {
  global ip user id
  set sourced 0
	set script_path [file normalize [file dirname $argv0]]
	if { "$env(HOME)" == "/root" } {
		set config [file join $script_path  "bin/.hue/0/config.hue.tcl"]
	} else {
		set config [file join $env(HOME) ".hue/0/config.hue.tcl"]
	}
	source "$config"
} else {
	set sourced 1
}

proc curlerr {curl_err} {
	global ip id
	puts [exec echo $curl_err | head -n 1 ]
	if {[string first "(49)" $curl_err] != -1} {
		puts "Maybe wrong ip: $ip"
	} elseif {[string first "(28)" $curl_err] != -1} {
		puts "Maybe wrong ip: $ip"
	} elseif {[string first "(60)" $curl_err] != -1} {
		puts "Maybe wrong id: $id"
	}
	exit
}

proc curltest {curl url {addition {}} } {
	global user bridgeNr
	if { [file exists "$curl"] } {
		set curly [exec cat "$curl" ]
	} else {
		set curly $curl
	}
	# puts $curly;exit
	if {[string first "Oops, there appears to be no lighting here" $curly] != -1} {
		puts "No lights found!"
		puts "Maybe wrong user: $user"
	  exit
	} elseif {[string first "faultstring\":\"Invalid Access Token" $curly] != -1} {
		puts "Invalid access token!"
		puts "Please do > ./remote.sh $bridgeNr refreshToken"
	  exit
	} elseif {[string first "description\":\"Not Found" $curly] != -1} {
		puts "Resource not found!"
		puts "Maybe wrong resource: $url"
	  exit
	} elseif {[string first "\"description\":\"JSON parse error" $curly] != -1} {
		puts "JSON parse error!"
		puts "Maybe wrong raw data: $addition"
	  exit
	} elseif {[string first "\"description\":\"method, GET, not available for resource" $curly] != -1} {
		puts "Resource (v1) not found!"
		puts "Maybe wrong url: $url"
	  exit
	} elseif {[string first "not available\"\}\}" $curly] != -1} {
		puts "Resource (v1) not found!"
		puts "Maybe wrong url: $addition"
	  exit
	} elseif {[string first "\"description\":\"unauthorized user\"" $curly] != -1} {
		puts "Not authorized (v1)!"
		puts "Maybe wrong user: $user"
	  exit
	}
}

proc jsonMapper { s} {
	return [string map { \[ \{ \] \} $ \\$} $s]
}

proc hueGet {{url ""}} {
	global resolveV1
	set curl "$resolveV1/$url"
	if { [catch {
		set ret [exec curl -s -S -m 2.0 {*}$curl]
	} curl_err]} {
		curlerr $curl_err
	}
	curltest $ret $curl $url
	regsub -all  {^.*application/json\s*} $ret "" newret
	return [encoding convertfrom utf-8 $newret]
}

proc hueDelete {{url ""}} {
	global resolveV1
	set curl "$resolveV1/$url"
	if { [catch {
		set ret [exec curl -s -S -m 2.0  -X DELETE {*}$curl]
	} curl_err]} {
		curlerr $curl_err
	}
	curltest $ret $curl $url 
	regsub -all  {^.*application/json\s*} $ret "" newret
	return [encoding convertfrom utf-8 $newret]
}

proc huePut {url body} {
	global resolveV1
	set curl "$resolveV1/$url"
	set body [subst $body]
	if { [regexp "^{.*}$" $body] == 0} {
		set body "{$body}"
	}
	if { [catch {
		set ret [exec curl -s -S -m 2.0  -X PUT {*}$curl \
		--header "Content-Type: application/json" \
		--header "Content-Length: [string length $body]" \
    --data-raw "$body" \
		]
	} curl_err]} {
		curlerr $curl_err
	}
	curltest $ret $curl $url
	regsub -all  {^.*application/json\s*} $ret "" newret
	return [encoding convertfrom utf-8 $newret]
}

proc huePost {url body} {
	global resolveV1
	set curl "$resolveV1/$url"
	set body [subst $body]
	if { [regexp "^{.*}$" $body] == 0} {
		set body "{$body}"
	}
	if { [catch {
		set ret [exec curl -s -S -m 2.0  -X POST {*}$curl \
		--header "Content-Type: application/json" \
		--header "Content-Length: [string length $body]" \
    --data-raw "$body" \
		]
	} curl_err]} {
		curlerr $curl_err
	}
	curltest $ret $curl $url 
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
