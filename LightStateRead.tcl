#!/usr/bin/env tclsh
global ip user light ;# gesetzt für den Aufruf durch ccu_read_hue.tcl
set script_path [file dirname [info script]]
source [file join $script_path "config.tcl"]
source [file join $script_path "hue.inc.tcl"]
source [file join $script_path "ccu_helper.tcl"]

proc readFile {strFile} {
	global script_path
	set f [file join $script_path $strFile]
	if { [file exists $f ]  } {
		set fp [open $f r]
		set file_data [read $fp]
		close $fp
	} else {
			puts "File '$strFile' not readable! Exit."
			exit 1
	}
	return $file_data
}

proc setLight {l light} {
	set body [getBody $l];# Paare von Bodyarguments in beliebiger Reihenfolge
	if { $body != ""} {
		set body [string range $body 1 end]
		set url "lights/$light/state"
		puts [huePut $url "{$body}"]
	}
}

if {$argc > 0 } {
	set nr [lindex $argv 0]
	set nr [exec $script_path/getLightNumberByName.tcl $nr]
	if { [string first Exit $nr] > 0} { 
		puts $nr
		exit 1	
	}
	set light(number) $nr

#	json light [hueGet "lights/$nr"]
	load $script_path/json/libTools[info sharedlibextension]
	eval [jsonparser light [hueGet "lights/$nr"]]
	if {$light(state,reachable) == "false" } {
		puts "Lamp '$nr' not reachable! Exit."
		exit 1
	}
    set oldL "$nr alert $light(state,alert) bri $light(state,bri) effect $light(state,effect) on $light(state,on) sat $light(state,sat) xy $light(state,xy) "
    if { [testRega] } {
        set l [readFile ".state${nr}_($light(name)).txt"]
    } else {
		array set info [infoVariable "state${nr}"]
		if { [info exists info(err_text)] } {
			puts "state${nr}: $info(err_text), Exit!"
			exit 1
		}
		set l $info(Variable)
    }
    if { [join $oldL] == [join $l] } {
    	exit 0
    }
    array set info [lrange $l 1 end]
    array set oldInfo [lrange $oldL 1 end]
    set oldon $oldInfo(on)
    set on $info(on)
    unset oldInfo(on)
    unset info(on)
    set l "$nr [array get info]"
    #if the light to set or the stored settings are on then don't care
    if { $oldon == "true" || $on == "true"  } {
    	if { $oldon == "false"  } {
    		setLight " $nr on true " $nr
    	}
    	setLight $l $nr
    	# switch the light off if the settings are off
    	if { $on == "false"  } {
    		setLight " $nr on false " $nr
    	}
    	exit
    }
    #both lamps are off
    set newL "$nr"
    foreach {key value} [array get info] {
	    if { $value != $oldInfo($key) } {
	    	set newL "$newL $key $value"
	    }
	}
	if { [join $newL] == "$nr"} {
		exit 0
		# donothing
	}
    setLight "$nr on true " $nr
    setLight $newL $nr
    setLight "$nr on false " $nr

} {
	puts "Usage: [info script] Lightnumber|Name"
}

