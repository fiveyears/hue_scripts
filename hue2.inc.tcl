#!/usr/bin/env tclsh
if { "[info script]" == $::argv0 } {
  global ip user id key
  set sourced 0
	if {[package vcompare [package provide Tcl] 8.4] < 0} {
		set script_path [file dirname $argv0]
	} else {
		set script_path [file normalize [file dirname $argv0]]
	}
	source [file join $env(HOME) ".config.hue.tcl"]
} else {
	set sourced 1
}

# proc hue2Get {url }
# proc hue2Put {url header}
# proc hue1Get {url }
# proc hue2Post {url header}
# proc hueDelete {{url ""}}
# proc huePut {url body}
# proc huePost {url body}
# proc getV2Body {bodyarray}
# proc getSensorNumberByName { str }
# proc getScheduleNumberByName { str }
# proc getV1 {url {grep {}} {vgrep {}} {p 0}}
# proc getResources {res {grep {}} {vgrep {}} {p 0}}
# proc getLight {id_name}
# proc getLights {}
# proc getRoom {id_name}
# proc getRoomZones {}
# proc getRooms {}
# proc !# {args}
# proc readYaml {yaml gLabel {grep {}} {vgrep {}} }
#    proc i_splitLine {line} {
#    proc i_rev {gLabel} {

proc hue2Get {url } {
	global id ip key
	set s [exec curl -s --insecure --location \
	   --resolve "$id:443:$ip" "https://$id/clip/v2/$url" \
	   --header "hue-application-key: $key" \
	   ]

	set s [ exec echo "$s" | [file dirname [info script]]/bin/jsondump | sed "s/'/\"/g"]
	regsub -all {\n+} $s "\n" s
	regsub -all  {^\n} $s "" s
	regsub -all  {\n$} $s "" s
	return [encoding convertfrom utf-8 "$s"]
}

proc hue2Put {url header} {
	global id ip key
	catch {
	set s [exec curl -s --insecure --location --request PUT \
		--resolve "$id:443:$ip" "https://$id/clip/v2/$url" \
		--header "hue-application-key: $key" \
		--header "Content-Type: text/plain" \
		--data-raw "$header" \
		]
  }
	set s [ exec echo "$s" | [file dirname [info script]]/bin/jsondump | sed "s/'/\"/g"]
	regsub -all {\n+} $s "\n" s
	regsub -all  {^\n} $s "" s
	regsub -all  {\n$} $s "" s
	return [encoding convertfrom utf-8 "$s"]
}
proc hue1Get {url } {
	global user ip
	set s [exec curl -s --location \
	   "http://$ip/api/$user/$url" \
	   ]

	set s [ exec echo "$s" | [file dirname [info script]]/bin/jsondump | sed "s/'/\"/g"]
	regsub -all {\n+} $s "\n" s
	regsub -all  {^\n} $s "" s
	regsub -all  {\n$} $s "" s
	return [encoding convertfrom utf-8 "$s"]
}


proc hue2Post {url header} {
	global id ip key
	catch {
	set s [exec curl -s --insecure --location --request POST \
		--resolve "$id:443:$ip" "https://$id/clip/v2/$url" \
		--header "hue-application-key: $key" \
		--header "Content-Type: text/plain" \
		--data-raw "$header" \
		]
  }
	set s [ exec echo "$s" | [file dirname [info script]]/bin/jsondump | sed "s/'/\"/g"]
	regsub -all {\n+} $s "\n" s
	regsub -all  {^\n} $s "" s
	regsub -all  {\n$} $s "" s
	return [encoding convertfrom utf-8 "$s"]
}

proc hueDelete {{url ""}} {
	global ip user
	set header {DELETE /api/$user/$url HTTP/1.1
HOST: $ip}
	set s [socket $ip 80]
	puts $s [subst $header]
	flush $s
	set ret [read $s]
	close $s
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

proc getV2Body {bodyarray} {
	set body ""
	if {[llength $bodyarray] > 0} {
		for {set i 0} {$i<[llength $bodyarray]} {incr i} {
		   set n [lindex $bodyarray $i]
		   incr i
		   set v [lindex $bodyarray $i]
		   if {$v != ""} {
		   		switch -glob $n {
		   			on {
		   				set body "$body,\"on\": {\"on\": $v}"
		   			}
		   			bri* {
		   				set body "$body,\"dimming\": {\"brightness\": $v}"
		   			}
		   			xy {
						  incr i
						  set y [lindex $bodyarray $i]
						  if { $y == "" } {
						  	puts "Error at xy, y is missing!"
						  	exit 1
						  }
		   				set body "$body,\"color\": {\"xy\": {\"x\": $v, \"y\": $y}}"
		   			}
		   			dyn* {
						  incr i
						  set d [lindex $bodyarray $i]
						  if { $y == "" } {
						  	puts "Error at dynamics, duration is missing!"
						  	exit 1
						  }
		   				set body "$body,\"dynamics\": {\"speed\": $v, \"duration\": $d}"
		   			}
		   			dur* {
						  incr i
		   				set body "$body,\"dynamics\": {\"speed\": 1, \"duration\": $v}"
		   			}
		   			mir* {
		   				set body "$body,\"color_temperature\": {\"mirek\": $v}"
		   			}
		   			name {
		   				set body "$body,\"metadata\": {\"name\":\"$v\"}"
		   			}
		   		}
		   } else {
		   		switch $n {
		   			on {
		   				set body "$body,\"on\": {\"on\": true}"
		   			}
		   			off {
		   				set body "$body,\"on\": {\"on\": false}"
		   			}
		   		}
		   }
		}

	}
	if { $body != "" } {
		set body [string range $body 1 end]
	}
	return "\{ $body \}"
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

proc getV1 {url {grep {}} {vgrep {}} {p 0} {arrayname {}} } {
	global places
  if { ! [info exists places]} { 	set places 2}
	global $url 
	set yaml [split [hue1Get "$url"] "\n"]
	if { $arrayname != "" } {
		set url $arrayname
	}
	eval [readYaml  "$yaml" "$url" $grep $vgrep 1]
	if { $p == 1} {
		parray $url
	}
}

proc getResources {res {grep {}} {vgrep {}} {p 0} {ar_name {}} {comma {}} } {
	global places
  if { ! [info exists places]} { 	set places 2}
	if { $res == "" } {
		set res resource
		set yaml [split [hue2Get "resource"] "\n"]
	} else {
		set yaml [split [hue2Get "resource/$res"] "\n"]
	}
	if { $ar_name != "" } { 
		set res $ar_name
	  global $res 
	  set s [readYaml  "$yaml" "$res" $grep $vgrep $comma]
	  set s [ exec echo $s | sed "s/\(data\)\(00\)//g" | sed "s/\(data,00,/\(/g"  ]
	} else {
			global $res 
			set s [readYaml  "$yaml" "$res" $grep $vgrep $comma]
	}
	eval $s
	if { $p == 1} {
		parray $res
	}
}

proc getLight {{id_name 0} {readLight {}} {grep {}} {vgrep {}} {p 0} {ar_name {}} {comma {}} } {
	global lightIDarray
	if { ! [info exists lightIDarray]} {
		getLights lightIDarray
	}
	if {$id_name == "0" } {
		return
	}
	if { [catch { set id $lightIDarray($id_name) }] }  {
		puts "Light '$id_name' is not available!"
		exit
	}
	if { $ar_name == "" } {
		set ar_name "light/$id"
	}
	global $ar_name
	if { $readLight > "" } {
		getResources "light/$id" $grep $vgrep $p $ar_name $comma
	}
	return $id
}

proc getLights { {ar_name {}} } {
	if { $ar_name == "" } {
		set ar_name lights
	}
	global places $ar_name ${ar_name}_name lightCount i  
	set yaml [split [hue2Get "resource/light"] "\n"]
  if { ! [info exists places]} { 	set places 2}
	eval [readYaml "$yaml" "ret" {metadata)(name (id) (id_v1)} "" ] ;#{(on)} ;##{ (id) (id_v1) metadata)(name)}
	#parray ret
	set j 0
	while { [info exists "ret\(data)\([format %0${places}d $j])\(id)" ]} {
		set id [ set ret\(data)\([format %0${places}d $j])\(id) ]
		set id_v1 [string map {"/lights/" {}} [ set ret\(data)\([format %0${places}d $j])\(id_v1) ]]
		set name [ set ret\(data)\([format %0${places}d $j])\(metadata)(name) ]
		set ${ar_name}($id) $id
		set ${ar_name}($id_v1) $id
		set ${ar_name}($name) $id
		if { $j == 0 } {
			set ${ar_name}(names) $name
		} else {
			set ${ar_name}(names) "[set ${ar_name}(names)], $name"
		}
		# puts "$name: $id_v1"
	  incr j
	}
  set ${ar_name}(lightCount) $j
}

proc getRoom {id_name} {
	global rooms
	if { ! [info exists Rooms]} {
		getRooms
	}
	if { [catch { set id $rooms($id_name) }] }  {
		puts "Room '$id_name' is not available!"
		exit
	}
	return $id
}

proc getRoomZones {} {
	getRooms
}
proc getRooms {} {
	global places rooms lightCount i
	set yaml [split [hue2Get "resource/room"] "\n"]
  if { ! [info exists places]} { 	set places 2}
	eval [readYaml "$yaml" "ret" {metadata)(name (id) (id_v1)}] ;#{(on)} ;##{ (id) (id_v1) metadata)(name)}
	set yaml [split [hue2Get "resource/zone"] "\n"]
	eval [readYaml "$yaml" "ret" {metadata)(name (id) (id_v1)}] ;#{(on)} ;##{ (id) (id_v1) metadata)(name)}
	#parray ret
	set j 0
	while { [info exists "ret\(data)\([format %0${places}d $j])\(id)" ]} {
		set id [ set ret\(data)\([format %0${places}d $j])\(id) ]
		set id_v1 [string map {"/groups/" {}} [ set ret\(data)\([format %0${places}d $j])\(id_v1) ]]
		set name [ set ret\(data)\([format %0${places}d $j])\(metadata)(name) ]
		set rooms($id) $id
		set rooms($id_v1) $id
		set rooms($name) $id
		# puts "$name: $id_v1"
	  incr j
	}
  set roomCount $j
}


# intern

proc !# {args} {
  global DEBUG
	  if {[info exists DEBUG]} {
  		catch {
	    	if { $DEBUG == 1  } {
	        set res [list]
	        foreach i $args {
	             if [uplevel info exists $i] {
	                 lappend res "$i=[uplevel set $i]"
	             } else {
	                 lappend res $i
	             }
	        }
 	        puts stderr $res
	      }
	    }
	} else {
		set DEBUG 0
	}
}

proc readYaml {yaml gLabel {grep {}} {vgrep {}} {comma {}} } {
  global places
  if { ! [info exists places]} {
  	set places 1
  }
	set yaml [exec echo $yaml | sed "s/\$ref/_ref/g"]
	namespace eval rev {
    variable yaml ""
		variable i 0
		variable text ""
		variable back 0
		variable firstLine 0
	}
  if { $yaml == "" } {
     return "set $gLabel\(data) empty"
  }
  set ::rev::yaml $yaml
	proc i_splitLine {line} {
		set level {}
		set label {}
		set value {}
		if {[string trim $line] == "" } {
			# empty line
			return -1  ;# empty line
		} elseif {[ regexp {(^\s*)-(\s*)(.*):} "$line" m level] } {
			# array object or list
			return [list [string length $level] {} {} "ao" ]
		} elseif {[ regexp {(^\s*)-\s*(.*)} "$line" m level value] } {
			# simple array
			return [list [string length $level] - [string trim $value] "a" ]
		} elseif {	[regexp {(^\s*)(\S.*?):\s*(\S.*)} "$line" m level label value ]} {
			# list
	 		return [list [string length $level] $label [string trim $value] "l"]
		} elseif {	[regexp {(^\s*)(\S.*?):\s*(.*)} "$line" m level label value ]} {
			# list opject or list null
	 		return [list [string length $level] $label [string trim $value] "lo"]
	 	} else {
			puts "shitty i_splitLine $line"
			exit
	 	}
	}

	proc i_rev {gLabel} {
		global places
	  # start 
		set c 0
		while {$::rev::i < [llength $::rev::yaml]} {
			set line [lindex $::rev::yaml $::rev::i]
			while { [regexp {^\s*$} $line] } { 
				incr ::rev::i
				if {$::rev::i < [llength $::rev::yaml]} {
					set line [lindex $::rev::yaml $::rev::i]
				} else {
					return
				}
			}
			# test if first line is array -> wrong indent "  - " instead of "-"
			if {$::rev::firstLine == 0 } {
				set ::rev::firstLine 1
				if {[ regexp {(^\s+)-(\s*)$} "$line" m level] }  {
					set jj 0
					while {$jj < [llength $::rev::yaml]} {
						set tmp_line [lindex $::rev::yaml $jj]
						if { $tmp_line == $line} {
							set ::rev::yaml [lreplace $::rev::yaml $jj $jj "-"]
						}
						incr jj
					}
					set line "-"
				}
			}
			# line not empty
			set j [expr $::rev::i + 1 ]
			set nextline [lindex $::rev::yaml $j]
			while { [regexp {^\s*$} $nextline] } { 
				incr j
				if {$j < [llength $::rev::yaml]} {
					set nextline [lindex $::rev::yaml $j]
				} else {
					break
				}
			}
			# nextline not empty or end
			# test same level
			set ret [i_splitLine $line]
			set nextRet [i_splitLine $nextline]
			set level [lindex  $ret 0]
			set label [lindex  $ret 1]
			set value [lindex  $ret 2]
			set kind [lindex  $ret 3]
	    # test if ao
	    if { $kind == "ao"  } {
	   	  # array object is shit
	    	regsub {(^\s*)(-)} $line {\1 } nextline
	    	regexp {(\s*-)} "$line" m line
	    	set ::rev::yaml [lreplace $::rev::yaml $::rev::i $::rev::i $line] 
	    	set ::rev::yaml [linsert $::rev::yaml [expr $::rev::i + 1] $nextline] 
	    }
		  set nextRet [i_splitLine $nextline]
			set nextLevel [lindex  $nextRet 0]
			set nextLabel [lindex  $nextRet 1]
			set nextValue [lindex  $nextRet 2]
			set nextKind [lindex  $nextRet 3]
	    if { $kind == "lo" && $nextLevel <= $level } {
	      # no value but no object
	      set value "{}"
	      set kind l
	    }
			#!# line level label value kind array_level nextLevel nextLabel nextValue nextKind 
	    if {[string index $kind 0] == "a"} {
	    	# is an array
	    	set label [format "%0${places}d" $c]
	    	incr c
	    }
	    ## set label
	    set label [string map {\" {} " " "_"} $label]
	    # label in places length
			if { [string is integer -strict $label ]} {
				set label [format "%0${places}d" $label]
			}
			set tLabel "$gLabel\($label)"
			if { $nextLevel > $level } {
				# object: ao or lo
				incr ::rev::i
				set nextLevel [i_rev "$tLabel"]
			} 
			if { $::rev::back == 0 } {
				set ::rev::text "${::rev::text}set $tLabel $value\n"
			}
			set ::rev::back 0
			if { $nextLevel < $level } {
				# puts "lower"
				#puts "Returnkind: $nextKind"
				set ::rev::back 1
				#
			  return $nextLevel
			}	elseif { $nextLevel == $level } {
				# puts " - equal"
			}
			incr ::rev::i
		}
	}

	# main
	i_rev $gLabel
	# grep
	if { [llength $grep] > 0} {
		# the last time
		set grepStr ""
		foreach g $grep {
			if { $grepStr == "" } {
				set grepStr "$grepStr$g"
			} else {
				set grepStr "$grepStr\\|$g"
			}
		}
	  if {[catch {set ::rev::text [exec echo "$::rev::text" | grep "$grepStr" ]} ]} {
	  	set ::rev::text "set $gLabel\(grep) \"not found\""
	  }
	}
	#
	# vgrep
	if { [llength $vgrep] > 0} {
		# the last time
		set grepStr ""
		foreach g $vgrep {
			if { $grepStr == "" } {
				set grepStr "$grepStr$g"
			} else {
				set grepStr "$grepStr\\|$g"
			}
		}
		if { $::rev::text > "" } {
	    if {[catch {set ::rev::text [exec echo "$::rev::text" | grep -v "$grepStr" ]} ]} {
		  	set ::rev::text "set $gLabel\(grep_v) \"not found\""
		  	} elseif { $::rev::text == "" } {
		  	set ::rev::text "set $gLabel\(grep_v) \"not found\""
		  }
		}
	}
	if { [llength $comma] > 0} {
		set ::rev::text [ exec echo "$::rev::text" | sed "s/\)\(/,/g" ]
	}
	return $::rev::text
}



####
if {$sourced == 0} {
	set yaml [split [hue2Get "resource/light"] "\n"]
	eval [readYaml "$yaml" "ret" {metadata)(name (id) (id_v1)}] ;#{(on)} ;##{ (id) (id_v1) metadata)(name)}
	parray ret
}
