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


proc getV1 {url {grep {}} {vgrep {}} {p 0} {arrayname {}} } {
	global places script_path resolveV1 tempFile bridgeNr
  if { ! [info exists places]} { 	set places 2} 
  set curl "$resolveV1/$url"
	if { [catch {
		exec curl -s -S -m 2.0 {*}$curl > $tempFile
	} curl_err]} {
		curlerr $curl_err
	}
	curltest "$tempFile" $curl $url
	exec cat "$tempFile" | "$script_path/bin/jsondump" 0 $places > "$tempFile.bak" 
	exec mv "$tempFile.bak" "$tempFile"
	exec sed -i.bak -e "s/root/root($bridgeNr)/g" -e "s/\(errors\)/\($bridgeNr\)\(errors\)/g"  $tempFile
	# regsub -all  {^.*application/json\s*} $ret "" newret
	# return [encoding convertfrom utf-8 $newret]
	if { $arrayname != "" } {
		set url $arrayname
	}
	readYaml  "$tempFile" "$url" $grep $vgrep 1
	if { $p > 0 } {
	  global $url
		source $tempFile
		if { $p == 1} {
			parray $url
		}
	}
}

proc joinItems {arrName items} {
	global $arrName places
	set m "$arrName$items"
	set j 0
	set all {}
	while { [info exists "$m[format "%0${places}d" $j])" ] } {
		set single [set "$m[format "%0${places}d" $j])"]
		lappend all $single
		incr j
	}
	regsub {,$} $m "" mm
	eval "set \"${mm})\" \"[join $all ","]\""
	eval "set \"${m}count)\" $j"	
}

proc put2Get {url } {
	global resolveV2  
	puts "$resolveV2/$url"
}

proc hue2Get {url } {
	global resolveV2 places script_path tempFile
	if { [info exists places ]} {
		set pl $places
	} else {
		set pl ""
	}
	set curl "$resolveV2/$url"
	if { [catch {
		exec curl -s -S -m 2.0 {*}$curl > $tempFile
	} curl_err]} {
		curlerr $curl_err
	}
	curltest "$tempFile" $curl $url
	exec cat "$tempFile" | "$script_path/bin/jsondump" 0 $pl > "$tempFile.bak" 
	exec mv "$tempFile.bak" "$tempFile"
	# return [encoding convertfrom utf-8 "$s"]
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
		   				set body "$body,\"color_tempFileerature\": {\"mirek\": $v}"
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

proc getResources {{res ""} {grep {}} {vgrep {}} {p 0} {ar_name {}} {comma {}} {deleteZero {}} {bridge {}}} {
	global tempFile
	if { $res == "" } {
		set res resource
		hue2Get "resource"
	} else {
		hue2Get "resource/$res"
	}
	if { "$ar_name" != "" } { 
		set res "$ar_name"
	  global $res 
	  if { $bridge != "" } {
	  	exec sed -i.bak -e "s/\(data\)/\($bridge\)/g" -e "s/\(errors\)/($bridge)(errors)/g"  $tempFile
	  } else {
	  	exec sed -i.bak "s/\(data\)//g"  $tempFile
	  }
	  if { $deleteZero > "" } {
	  	exec sed  -i.bak -e "s/\(0*\)//g"  $tempFile
	  }
	} else {
	  if { $bridge != "" } {
	  	 exec  sed -i.bak -e "s/\(data\)/(data)($bridge)/g"   -e "s/\(errors\)/($bridge)(errors)/g" $tempFile
	  } 
		# exec sed -i.bak "s/\\//_/g" $tempFile
		global $res 
	}
	readYaml  $tempFile "$res" $grep $vgrep $comma
	if { $p > 0} {
		if { [file exists $tempFile ]  } {
			source $tempFile
		}
		if { $p == 1} {
			parray $res
		}
	}
}

proc getLight {{id_name 0} {readLight {}} {grep {}} {vgrep {}} {p 0} {ar_name {}} {comma {}} } {
	global lightIDarray env bridge
	if { ! [info exists lightIDarray] || $id_name == "-1" } {
		if {$id_name >= "0"} {
				if { "$env(HOME)" == "/root" } {
					set config [file join $script_path  "bin/.hue/0/config.hue.tcl"]
				} else {
					set config [file join $env(HOME) ".hue/0/config.hue.tcl"]
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
	global tempFile
	if { $ar_name == "" } {
		set ar_name lights
	}
	global $ar_name ${ar_name}_name lightCount i  
	hue2Get "resource/light"
	readYaml "$tempFile" "ret" {metadata)(name (id) (id_v1) places} "";#{(on)} ;##{ (id) (id_v1) metadata)(name)}
	source $tempFile
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
	source [readYaml "$yaml" "ret" {metadata)(name (id) (id_v1) places}] ;#{(on)} ;##{ (id) (id_v1) metadata)(name)}
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
	source [readYaml "$yaml" "ret" {metadata)(name (id) (id_v1) places}] ;#{(on)} ;##{ (id) (id_v1) metadata)(name)}
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
	global tempFile
	regsub -all {\/} $label "\\/" newlabel
	if { ! [file exists "$yaml" ]  } {
	  set out [open "$tempFile" w]
		puts $out $yaml
		close $out	
	}
  if { [ file size $tempFile] < 5}  {
  	 puts $tempFile "set $label\(data) empty"
     return "set $label\(data) empty"
  }
	if {$label != "root" } {
  		exec sed -i.bak "s/root\(data\)/$newlabel/g" "$tempFile"
  		exec sed -i.bak "s/root/$newlabel/g" "$tempFile"
  }
  exec sed -i.bak -e "s/^set /set \"/g" -e "s/\) /)\" /g" -e "s/\$lights/\\\\\$lights/g" -e "s/\$ref/\\\\\$ref/g" "$tempFile"
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
		regsub -all {,} $grepStr "(" grepStr
	  if {[catch {exec grep "$grepStr" "$tempFile" > "$tempFile.bak"} ]} {
	  	exec echo "set $label\(grep) \"not found\""  > "$tempFile.bak"
	  }
	  exec mv "$tempFile.bak" "$tempFile"
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
	    if {[catch {exec grep -v "$grepStr" "$tempFile" > "$tempFile.bak"} ]} {
		  	set yaml "set $label\(grep_v) \"not found\""
		  	} elseif { $yaml == "" } {
		  	exec echo "set $label\(grep) \"not found\"" > "$tempFile.bak"
		  }
		}
	  exec mv "$tempFile.bak" "$tempFile"
	}
	if { $comma != 0 } {
		exec sed -i.bak "s/\)\(/,/g" "$tempFile"
	}
	exec rm -f "$tempFile.bak"
	return "$tempFile"
}

proc pparray {a {channel stdout} {pattern *}} {
    upvar 1 $a array
    if {![array exists array]} {
        return -code error "\"$a\" isn't an array"
    }
    set maxl 0
    set names [lsort [array names array $pattern]]
    foreach name $names {
        if {[string length $name] > $maxl} {
            set maxl [string length $name]
        }
    }
    set maxl [expr {$maxl + [string length $a] + 4}]
    set r ""
    foreach name $names {
        set nameString [format %s(%s) $a $name]
        if { [string first " " $nameString] >= 0 } {
        	set nameString "\"$nameString\""
        }
        set arrayName "$array($name)"
        if { [string first " " $array($name)] >= 0 } {
        	set arrayName "\"$array($name)\"" 
        } elseif {[string length $array($name)] == 0} {
        	set arrayName "\"\"" 
        }
        set line "set [format "%-*s %s" $maxl $nameString $arrayName]"
        if { $channel == "return" } {
        	set r "$r$line\n"
        } else {
        	if { [regexp {\$} $line] } {
        		regsub {\$} $line {\\$} line
        	}
        	puts $channel "$line"
        }
    }
    return [string trim "$r"]
}
proc readIt {what {pattern *} {reset 0} {p 0} {bridge -1} } {
	global script_path $what bridgeList$what bridgeListN$what configPath
	set bridgeList$what {}
  set bridgeListN$what {}
	if { [info exists $what ] && $reset != 0} {
		unset $what
	} 
	if {$pattern == "*" || $pattern == "" } {
		source "[file join $script_path ".$what"]"
	} else {
			if {[catch {eval [exec cat "[file join $script_path ".$what"]" | grep {*}$pattern ] } err]} {
				# puts $err
				set ${what}(grep) "not found"
			}
	}
	if { $bridge == -1 } {
		set i 0 
		while {$i < 10} { ;# all bridges
			if { [llength [array names $what "$i,places"]] > 0 } {
				lappend bridgeList$what $i
				lappend bridgeListN$what [exec cat [file join $configPath "$i/info.txt"]   | head -n 1 ]
			}
			incr i
		}
	} else { ; # special bridge
			if { [llength [array names $what "$bridge,places"]] > 0 } {
				lappend bridgeList$what $bridge
				lappend bridgeListN$what [exec cat [file join $configPath "$bridge/info.txt"]   | head -n 1 ]
			}

	}
	if { $p } {
		parray $what
	}
}

proc testIt {what {write 0}} {
	global script_path $what
	set ret 1
	set file [file join $script_path ".$what"]
	if { $write == 2 } {
		set ret 0
	} elseif { ! [ file exists $file]} {
		set ret 0
	} elseif { [ file size $file] < 1000} {
		set ret 0
	} else {
		set t [file mtime $file]
		set t [expr ([clock seconds]-$t)]
		if { $t > 86400 } {
			set ret 0
		}
	}
	if { $write == 0 || $ret == 1} {
		return $ret
	}
	writeIt $what
	if { [info exists $what ]} {
		unset $what
	} 
	return 1
}

proc writeIt {what {bri -1}} {
	global script_path $what configPath bridge resolveV2 resolveV1 bridgeNr places tempFile 
	set destination "[file join $script_path ".$what"]"
	if { [info exists places ]} {
		set oldPlaces $places
	} 
	set i 0
	if {$bri >= 0} {
		set i $bri
		exec grep -v "($bri," .lightsV1 > "$destination.bak"
		exec mv "$destination.bak" "$destination"
	} else {
		exec rm -f "$destination"
	}
	while { [file exists [file join $configPath "$i/config.hue.tcl"]]} {
		source [file join $configPath "$i/config.hue.tcl"]
		set places  2
		if { [regexp {^(.*?)V1$} $what -> newWhat]} {
			getV1 "$newWhat" "" "" "" $what
		}	elseif {$what == "resource"} {
			set places 3
			getResources "" "" "" "" "" "" "" $i
		} else {
			getResources $what "" "" "" "" "" "" $i
		}
		incr i
		exec cat "$tempFile" >> "$destination"
		if {$bri >= 0} {
			break
		}
	}
	exec rm -f "$tempFile"
	if { [info exists oldPlaces ]} {
		set places $oldPlaces
	} else {
		unset places
	}
	# reset config
	source [file join $configPath "$bridge/config.hue.tcl"]
}

