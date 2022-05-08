#!/usr/bin/env tclsh

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
# proc readYaml {yaml label {grep {}} {vgrep {}} {comma 0}}


proc hue2Get {url } {
	global resolveV2 places script_path
	if { [info exists places ]} {
		set pl $places
	} else {
		set pl ""
	}
	set curl "$resolveV2/$url"
	if { [catch {
		set ret [exec curl -s -S -m 2.0 {*}$curl]
	} curl_err]} {
		curlerr $curl_err
	}
	curltest $ret $curl $url
	set s [ exec echo "$ret" | "$script_path/bin/jsondump" 0 $pl]
	return [encoding convertfrom utf-8 "$s"]
}

proc hue2Put {url header} {
	global id ip user places script_path
	if { [info exists places ]} {
		set pl $places
	} else {
		set pl ""
	}
	if { [catch {
	set s [exec curl -s  -S -m 2.0 --location --request PUT \
		--resolve "$id:443:$ip" "https://$id/clip/v2/$url" \
		--header "hue-application-key: $user" \
		--header "Content-Type: text/plain" \
		--data-raw "$header" \
		]
	} curl_err]} {
		curlerr $curl_err
	}
	curltest $s $url $header
	set s [ exec echo "$s" | "$script_path/bin/jsondump" 0 $pl ]
	return [encoding convertfrom utf-8 "$s"]
}

proc hue2Post {url header} {
	global id ip user places script_path
	if { [info exists places ]} {
		set pl $places
	} else {
		set pl ""
	}
	if { [catch {
	set s [exec curl -s  -S -m 2.0 --location --request POST \
		--resolve "$id:443:$ip" "https://$id/clip/v2/$url" \
		--header "hue-application-key: $user" \
		--header "Content-Type: text/plain" \
		--data-raw "$header" \
		]
	} curl_err]} {
		curlerr $curl_err
	}
	curltest $s $url $header
	set s [ exec echo "$s" | "$script_path/bin/jsondump" 0 $pl ]
	return [encoding convertfrom utf-8 "$s"]
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
	global places script_path places
  if { ! [info exists places]} { 	set places 2}
	global $url 
	set yaml [hueGet "$url"]
	set yaml [ exec echo "$yaml" | "$script_path/bin/jsondump" 0 $places]
	if { $arrayname != "" } {
		set url $arrayname
	}
	eval [readYaml  "$yaml" "$url" $grep $vgrep 1]
	if { $p == 1} {
		parray $url
	}
}

proc getResources {{res ""} {grep {}} {vgrep {}} {p 0} {ar_name {}} {comma {}} {deleteZero {}} } {
	if { $res == "" } {
		set res resource
		set yaml [hue2Get "resource"] 
	} else {
		set yaml [hue2Get "resource/$res"] 
	}
	if { $ar_name != "" } { 
		set res $ar_name
	  global $res 
	  set s [ exec echo $yaml | sed "s/\(data\)//g"  ]
	  if { $deleteZero > "" } {
	  	set s [ exec echo $s | sed "s/\(0*\)//g"  ]
	  }
	  set s [readYaml  "$s" "$res" $grep $vgrep $comma]
	} else {
		set res [exec echo $res | sed "s/\\//_/g" ]
			global $res 
			set s [readYaml  "$yaml" "$res" $grep $vgrep $comma]
	}
	eval $s
	if { $p == 1} {
		parray $res
	}
}

proc getLight {{id_name 0} {readLight {}} {grep {}} {vgrep {}} {p 0} {ar_name {}} {comma {}} } {
	global lightIDarray env
	if { ! [info exists lightIDarray] || $id_name == "-1" } {
		if {$id_name >= "0"} {
				if { "$env(HOME)" == "/root" } {
					set config [file join $script_path  "bin/.config.hue.tcl"]
				} else {
					set config [file join $env(HOME) ".config.hue.tcl"]
				}
			catch {
				set s [ exec cat $config  | grep -v "lightIDarray"]
			}
			set fileId [open $config "w"]
			puts $fileId $s
		}
		getLights lightIDarray
		if {$id_name >= "0"} {
			foreach {key value} [array get lightIDarray] {
				puts $fileId "set \"lightIDarray($key)\" \"$value\""
			}
			close $fileId
		}
	}
	if {$id_name <= "0" } {
		return
	}
	if { [catch { set id $lightIDarray($id_name) }] }  {
		puts "Light '$id_name' is not available!"
		exit
	}
	if { $ar_name == "" } {
		set ar_name "light"
	}
	global $ar_name
	if { $readLight > "" } {
		getResources "light/$id" $grep $vgrep $p $ar_name $comma 1
	}
	return $id
}

proc getLights { {ar_name {}} } {
	if { $ar_name == "" } {
		set ar_name lights
	}
	global $ar_name ${ar_name}_name lightCount i  
	set yaml [hue2Get "resource/light"] 
	eval [readYaml "$yaml" "ret" {metadata)(name (id) (id_v1) places} "" ] ;#{(on)} ;##{ (id) (id_v1) metadata)(name)}
	if { ! [info exists ret(places)]} {
		puts "Error here with places!"
		exit 1
	} else {
		set p $ret(places)
	}
	set j 0
	while { [info exists "ret\([format %0${p}d $j])\(id)" ]} {
		set id [ set ret\([format %0${p}d $j])\(id) ]
		set id_v1 [string map {"/lights/" {}} [ set ret\([format %0${p}d $j])\(id_v1) ]]
		set name [ set ret\([format %0${p}d $j])\(metadata)(name) ]
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
	set yaml [hue2Get "resource/room"] 
	eval [readYaml "$yaml" "ret" {metadata)(name (id) (id_v1) places}] ;#{(on)} ;##{ (id) (id_v1) metadata)(name)}
	if { ! [info exists ret(places)]} {
		puts "Error here with places!"
		exit 1
	} else {
		set p $ret(places)
	}
	set j 0
	while { [info exists "ret\([format %0${p}d $j])\(id)" ]} {
		set id [ set ret\([format %0${p}d $j])\(id) ]
		set id_v1 [string map {"/groups/" {}} [ set ret\([format %0${p}d $j])\(id_v1) ]]
		set name [ set ret\([format %0${p}d $j])\(metadata)(name) ]
		set rooms($id) $id
		set rooms($id_v1) $id
		set rooms($name) $id
		# puts "$name: $id_v1"
	  incr j
	}
	set yaml [hue2Get "resource/zone"] 
	eval [readYaml "$yaml" "ret" {metadata)(name (id) (id_v1) places}] ;#{(on)} ;##{ (id) (id_v1) metadata)(name)}
  if { ! [info exists ret(places)]} {
		puts "Error here with places!"
		exit 1
	} else {
		set p $ret(places)
	}
	set k 0
	while { [info exists "ret\([format %0${p}d $k])\(id)" ]} {
		set id [ set ret\([format %0${p}d $k])\(id) ]
		set id_v1 [string map {"/groups/" {}} [ set ret\([format %0${p}d $k])\(id_v1) ]]
		set name [ set ret\([format %0${p}d $k])\(metadata)(name) ]
		set rooms($id) $id
		set rooms($id_v1) $id
		set rooms($name) $id
		# puts "$name: $id_v1"
	  incr k
	}
  set rooms(roomCount) [expr $j + $k]
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

proc readYaml {yaml {label root} {grep {}} {vgrep {}} {comma 0} } {
	regsub -all {\/} $label "\\/" newlabel
	set yaml [exec echo $yaml | sed "s/\$ref/_ref/g"]
  if { $yaml == "" } {
     return "set $label\(data) empty"
  }
  set yaml [exec echo "$yaml" | sed "s/^set /set \"/g" | sed "s/\) /)\" /g"]
  if {$label != "root" } {
  		set yaml [exec echo "$yaml" | sed "s/root\(data\)/$newlabel/g" ]
  		set yaml [exec echo "$yaml" | sed "s/root/$newlabel/g" ]
  }
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
	  if {[catch {set yaml [exec echo "$yaml" | grep "$grepStr" ]} ]} {
	  	set yaml "set $label\(grep) \"not found\""
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
		if { $yaml > "" } {
	    if {[catch {set yaml [exec echo "$yaml" | grep -v "$grepStr" ]} ]} {
		  	set yaml "set $label\(grep_v) \"not found\""
		  	} elseif { $yaml == "" } {
		  	set yaml "set $label\(grep_v) \"not found\""
		  }
		}
	}
	if { $comma != 0 } {
		set yaml [ exec echo "$yaml" | sed "s/\)\(/,/g" ]
	}
	return $yaml
}



####
if {$sourced == 0} {
	set yaml [hue2Get "resource/light"] 
	eval [readYaml "$yaml" "ret" {metadata)(name (id) (id_v1)}] ;#{(on)} ;##{ (id) (id_v1) metadata)(name)}
	parray ret
}
