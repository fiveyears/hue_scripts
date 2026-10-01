#!/usr/bin/env tclsh
if { "[info script]" == "$::argv0" } {
	puts "$::argv0 can't be started directly!"
	exit 1 
}

# proc curlerr {curl_err}
# proc curltest {curl url {addition {}} }
# proc jsonMapper { s}
# proc hueGet {{url ""}}
# proc hueDelete {{url ""}}
# proc huePut {url body}
# proc huePost {url body}
# proc getBody {bodyarray}
# proc wsplit {str sep}
# proc getSensorNumberByName { str }
# proc getGroupNumberByName { str }
# proc getScheduleNumberByName { str }
# proc getLightNumberByName { str }
# proc getNumberByName { what str }
# proc ajaxV1 {url}
# proc getV1 {url {grep {}} {vgrep {}} {p 0} {arrayname {}} }
# proc source_with_args {filename args}
# proc joinItems {arrName items}
# proc hue2Get {url {write 0}}
# proc hue2Put {url header}
# proc hue2Post {url header}
# proc getV2Body {bodyarray}
# proc getResources {{res ""} {grep {}} {vgrep {}} {p 0} {ar_name {}} {comma {}} {deleteZero {}}}
# proc getLight {{id_name 0} {readLight {}} {grep {}} {vgrep {}} {p 0} {ar_name {}} {comma {}} }
# proc getLights { {ar_name {}} }
# proc getRoom {id_name}
# proc getRoomZones {}
# proc getRooms {}
# proc !# {args}
# proc readYaml {yaml {label root} {grep {}} {vgrep {}} {comma 0} }
# proc grepArray {a {channel stdout} {pattern *} {keyValues {}}}
# proc pparray {a {channel stdout} {pattern *}}
# proc i_puts {args}
# proc readIt {what {pattern ""} {reset 0} {p 0} {arrayName ""}}
# proc lightIdsChanged {}
# proc testIt {what {write 0} {arrayName ""}}
# proc writeIt {what {arrayName ""}}
# proc allV1 {what {pattern ""}  {reset 0} {p 0}}
# proc addRGB {arrayName file}
# proc iRGB {rgb {bw 0}}
# -------------------------------------------
# for curl
# proc curlerr: test error
# proc curltest: test return

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
	global user
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
		puts "Please do > ./remote.sh refreshToken"
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

# -------------------------------------------
# v1

# proc jsonMapper:
# proc hueGet:
# proc hueDelete:
# proc huePut:
# proc huePost:
# proc getBody:
# proc wsplit:
# proc getSensorNumberByName:
# proc getGroupNumberByName:
# proc getScheduleNumberByName:
# proc getLightNumberByName:
# proc getNumberByName:

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
	# puts $body
	if { [catch {
		# puts $curl
		# puts $body
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
	return [getNumberByName groupsV1 $str]
}

proc getGroupNumberByName { str } {
	return [getNumberByName groupsV1 $str]
}

proc getScheduleNumberByName { str } {
	return [getNumberByName schedulesV1 $str]
}

proc getLightNumberByName { str } {
	return [getNumberByName lightsV1 $str]
}

proc getNumberByName { what str } {
	global script_path $what
	# read again
	if { [testIt $what] || $str == "-1" } {
		writeIt $what
	}
	if {[catch {set nr [format "%02d" $str]} err] } {
		# Resource name
		readIt $what "$what\(\[0-9\]*,name).*$str" 1 0 
		set key [grepArray $what return "" keys]
		if { $key == "$what\(grep)" }  {
			puts "$what: Resource '$str' is not available!"
			exit
		}
		return [scan [lindex [split $key ",("] 1] %d]
	}
	# do nothing
	if {$str <= "0" } { return}
	#Resource number
	readIt $what "$what\($nr," 1 0 
	set key [grepArray $what return "" keys]
	if { $key == "$what\(grep)" }  {
			puts "$what: Resource '$str' is not available!"
			exit
	} else {
		return [scan $nr %d]
	}
}

# -------------------------------------------
# v2

# proc ajaxV1:
# proc getV1:
# proc srcfile:
# proc joinItems:
# proc hue2Get:
# proc hue2Put:
# proc hue2Post:
# proc getV2Body:
# proc getResources:
# proc getLight:
# proc getLights:
# proc getRoom:
# proc getRoomZones:
# proc getRooms:
# proc !#:
# proc readYaml:
# proc grepArray:
# proc pparray:
# proc readIt:
# proc testIt:
# proc writeIt:

proc ajaxV1 {url} {
	global script_path ip user
	set headers "\"headers\": {\"Content-Type\": \"application/json\""
	if [string match api.meethue.com/route $ip] {
		# exec [file join $script_path remote.sh] refreshtoken
		set bearer [exec [file join $script_path remote.sh] token]
		set headers "\"crossDomain\": true, \"xhrFields\": {\"withCredentials\": true,},$headers,\"Authorization\": \"Bearer $bearer\", \"Access-Control-Allow-Origin\":\"Content-Type, Accept, X-Requested-With, Session\""
  }
  set headers "$headers},"
	return \
	"{\"url\": \"https://$ip/api/$user/\" + url, \"method\": method,$headers\"timeout\": 0};"	
}

proc getV1 {url {grep {}} {vgrep {}} {p 0} {arrayname {}} } {
	global places script_path resolveV1 tempFile
  if { ! [info exists places]} { 	set places 2} 
  set curl "$resolveV1/$url"
	if { [catch {
		# puts $curl
		exec curl -s -S -m 2.0 {*}$curl > $tempFile
	} curl_err]} {
		curlerr $curl_err
	}
	curltest "$tempFile" $curl $url
	exec cat "$tempFile" | "$script_path/bin/jsondump" 0 $places > "$tempFile.bak" 
	exec mv "$tempFile.bak" "$tempFile"
	# regsub -all  {^.*application/json\s*} $ret "" newret
	# return [encoding convertfrom utf-8 $newret]
	if { $arrayname != "" } {
		set url $arrayname
	}
	readYaml  "$tempFile" "$url" $grep $vgrep 1
	global $url
	source $tempFile
	if { $p > 0 } {
		if { $p == 1} {
			parray $url
		}
	}
}

proc source_with_args {filename args} {
    # Save previous global argv/argc (if set)
    global argv argc  ;# <-- REQUIRED   
    set hadArgv [info exists argv]
    set hadArgc [info exists argc]
    if {$hadArgv} { set oldArgv $argv }
    if {$hadArgc} { set oldArgc $argc }

    # Override with the desired arguments
    set argv $args
    set argc [llength $args]

    # Load and run the legacy script
    source $filename

    # Restore original argv/argc
    if {$hadArgv} {
        set argv $oldArgv
    } else {
        catch {unset argv}
    }
    if {$hadArgc} {
        set argc $oldArgc
    } else {
        catch {unset argc}
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
	eval "set \"${mm})\" \"[join $all " "]\""
	eval "set \"${m}count)\" $j"	
}

proc hue2Get {url {write 0}} {
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
	if { $write != 0 } {
		exec cat "$tempFile" 
	} else {
		exec cat "$tempFile" | "$script_path/bin/jsondump" 0 $pl > "$tempFile.bak" 
		exec mv "$tempFile.bak" "$tempFile"
	}
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


proc getResources {{res ""} {grep {}} {vgrep {}} {p 0} {ar_name {}} {comma {}} {deleteZero {}}} {
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
	  exec sed -i.bak "s/\(data\)//g"  $tempFile
	  if { $deleteZero > "" } {
	  	exec sed  -i.bak -e "s/\(0*\)//g"  $tempFile
	  }
	} else {
	  # exec sed -i.bak "s/\\//_/g" $tempFile
	  set res "[regsub "/" $res "_"]"
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
	global light
	if { [testIt light] || $id_name == "-1" } {
		writeIt light	}
	if {$id_name <= "0" } {
		return
	}
	readIt light "light(\[0-9\]*,id_v1.*/lights/$id_name\"" 1 0
	set key [grepArray light return "" keys]
	if { $key == "light(grep)" }  {
		readIt light "light(\[0-9\]*,metadata,name.*$id_name" 1 0
		set key [grepArray light return "" keys]
		if { $key == "light(grep)" }  {
			puts "Light '$id_name' is not available!"
			exit
		}
	}
	set index [lindex [split $key ",("] 1]
	readIt light "($index,id)" 1 0
	set id $light($index,id)
	unset light
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

proc grepArray {a {channel stdout} {pattern *} {keyValues {}}} {
    upvar 1 $a array
    if {![array exists array]} {
        return -code error "\"$a\" isn't an array"
    }
    set maxl 0
    set names [lsort [array names array ]]
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
        if { [regexp $pattern $line ] } {
	        if {$keyValues == "values"} {
	        	set line "$arrayName"
	        } elseif {$keyValues == "keys"} {
	        	set line "$nameString"
	        } elseif {$keyValues == "indices"} {
	        	set line "$name"
	        } 
	        if { $channel == "return" } {
	        	set r "$r$line\n"
	        } else {
	        	if { [regexp {\$} $line] } {
	        		regsub {\$} $line {\\$} line
	        	}
	        	puts $channel "$line"
	        }
	    }
    }
    return [string trim "$r"]
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

proc i_puts {args} {
	foreach var $args {
		upvar 1 $var varname
		puts -nonewline "$var "
		if { [info exists varname]} {
			puts -nonewline "$varname "
		}
	}
	puts ""
	exit
}

proc readIt {what {pattern ""} {reset 0} {p 0} {arrayName ""}} {
	global script_path $what
	if { $arrayName == "" } {
		set arrayName "[regsub "/" $what "_"]"
	}
 	if { [info exists $arrayName ] && $reset != 0} {
		unset $arrayName
	} 
	set file [file join $script_path .resources ".$arrayName"]
	if {$pattern == "" } {
		catch {eval [exec cat $file] }
	} else {
		if {[lindex $pattern 0] == "*" } {
			set pattern [lreplace $pattern 0 0 ]  
			if {[catch {eval [exec cat $file | grep {*}$pattern ] } err]} {
				set ${arrayName}(grep) "not found"
			}				
		} else {
			if {[catch {eval [exec cat $file | grep $pattern ] } err]} {
				set ${arrayName}(grep) "not found"
			}
		}
	}
	if { $p } {
		parray $arrayName
	}
}

# true if the v1 light ids in .lightsV1 and the id_v1 of .light differ
proc lightIdsChanged {} {
	global script_path
	set ids {}
	foreach what {lightsV1 light} {
		set file [file join $script_path .resources ".$what"]
		set l {}
		if { [file exists $file] } {
			set fh [open $file]
			set data [read $fh]
			close $fh
			if { $what == "lightsV1" } {
				set re {lightsV1\(0*(\d+),name\)}
			} else {
				set re {light\(\d+,id_v1\)" "/lights/(\d+)"}
			}
			foreach {- n} [regexp -all -inline $re $data] {
				lappend l $n
			}
		}
		# nothing cached yet: the timestamp check handles it
		if { [llength $l] == 0 } {
			return 0
		}
		lappend ids [lsort -integer -unique $l]
	}
	return [expr {[lindex $ids 0] ne [lindex $ids 1]}]
}

# returns 1 if the cache file of $what is missing or older than a day;
# with write != 0 a stale cache is refreshed (and 0 returned)
proc testIt {what {write 0} {arrayName ""}} {
	global script_path $what
	if { $arrayName == "" } {
		set arrayName "[regsub "/" $what "_"]"
	}
	set file [file join $script_path .resources ".$arrayName"]
	set stale 1
	if { $write == 2 } {
		set reason "Parameter 2" ;# debug
	} elseif { ! [ file exists $file]} {
		set reason "no file" ;# debug
	} elseif { [ file size $file] < 1000} {
		set reason "file too small" ;# debug
	} elseif { [clock seconds] - [file mtime $file] > 86400 } {
		set reason "file too old" ;# debug
	} elseif {[catch {eval [exec cat "$file" | grep "$arrayName\(timestamp\)" ] } err]} {
		set reason "timestamp is missing" ;# debug
	} elseif { [clock seconds] - [set ${arrayName}(timestamp)] > 86400 } {
		set reason "timestamp too old" ;# debug
	} elseif { $arrayName == "lightsV1" && [lightIdsChanged] } {
		# lights re-paired on the bridge get new v1 ids: refresh all light caches
		set reason "light ids changed" ;# debug
	} else {
		set stale 0
	}
	# if {$stale} {puts $reason}
	if { $write == 0 || ! $stale } {
		return $stale
	}
	if { $arrayName == "lightsV1" && [lightIdsChanged] } {
		writeIt light
		writeIt device
	}
	writeIt $what $arrayName
	if { [info exists $what ]} {
		unset $what
	} 
	return 0
}

proc writeIt {what {arrayName ""}} {
	global script_path $what places tempFile 
	set newWhat $what
	set V1 false
	if { $arrayName == "" } {
		set arrayName "[regsub "/" $what "_"]"
	}
	if {[regexp {^(.*?)V1$} $what -> newWhat]} {
		set V1 true
	}
	set destination "[file join $script_path .resources ".$arrayName"]"
	if { [info exists places ]} {
		set oldPlaces $places
	} 
	set places  2
	if { $V1 == true } {
		getV1 "$newWhat" "" "" "" $arrayName
		if { $newWhat == "lights" } {
			addRGB $arrayName $tempFile
		}
	}	elseif {$what == "resource"} {
		set places 3
		getResources "" "" "" "" "$arrayName"
	} else {
		getResources $what "" "" "" "$arrayName"
	}
	file copy -force "$tempFile" "$destination"
	exec rm -f "$tempFile"
	if { [info exists oldPlaces ]} {
		set places $oldPlaces
	} else {
		unset places
	}
}

proc allV1 {what {pattern ""}  {reset 0} {p 0}} {
	set w "${what}V1"
	global $w
	testIt $w 1
	readIt $w "$pattern" $reset $p
}

# append the rgb value of every V1 light to the given cache file
proc addRGB {arrayName file} {
	global script_path
	if { [info commands calcRGB] == "" } {
		load $script_path/bin/v2/libTools[info sharedlibextension]
	}
	source $file
	set out [open $file a]
	foreach li [lsort [array names $arrayName -regexp {^[0-9]+,name$}]] {
		regsub {,name$} $li "" m
		set rgb "not available"
		set keys {state,xy,00 state,xy,01}
		foreach c {00 01 02} {
			lappend keys capabilities,control,colorgamut,$c,00 capabilities,control,colorgamut,$c,01
		}
		set values {}
		foreach k $keys {
			if { ! [info exists ${arrayName}($m,$k)] } {
				set values {}
				break
			}
			lappend values [set ${arrayName}($m,$k)]
		}
		if { [llength $values] == 8 } {
			set rgb [calcRGB {*}$values]
		}
		puts $out "set \"${arrayName}($m,rgb)\" \"$rgb\""
	}
	close $out
}

proc iRGB {rgb {bw 0}} {
	regsub -all {#} $rgb "" rgb
	if {[string length $rgb] == 3} {
		set rgb "[string index $rgb 0][string index $rgb 0][string index $rgb 1][string index $rgb 1][string index $rgb 2][string index $rgb 2]"
	}
	if {[string length $rgb] != 6} {
		i_puts shit
	}
	scan [string range $rgb 0 1] %x r
	scan [string range $rgb 2 3] %x g
	scan [string range $rgb 4 5] %x b
    if {$bw} {
    	set bw [expr $r * 0.299 + $g * 0.587 + $b * 0.114]
    	if {$bw > 186} {
    		return "#000000"
    	} else {
    		return "#FFFFFF"
    	}
    }
	set r [expr 255 - $r]
	set g [expr 255 - $g]
	set b [expr 255 - $b]
	return "#[format %02X $r][format %02X $g][format %02X $b]"
}

