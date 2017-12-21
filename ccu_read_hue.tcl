#!/usr/bin/env tclsh
set lightNr 0
set pre "hue"
set lampcount 12
if {$::argc > 0} {set lightNr [lindex $argv 0]};# erstes Argument ist die LightNr ( 1, 2, ...)
if {$::argc > 1} {set pre [lindex $argv 1]};# zweites Argument ist Vorsilbe wie "pre"

source [file join [file dirname [info script]] "ccu_helper.tcl"]
set script [file join [file dirname [info script]] "getLightAttributesAndState.tcl"]
if {$lightNr == "0"} {
    if { [testRega] } {
        puts "Rega not loaded! This may not be a ccu or raspimatic."
        exit
    }
    for {set i 1 } { $i <= $lampcount} { incr i} {
    	deleteVariablen "${pre}$i"
    }
	exit
}
proc srcfile { filename args } {
    global argv
    global argc
    set argc [llength $args]
    set argv $args
    source $filename
  }
srcfile $script $lightNr 1
if { [testRega] } {
    puts "Rega not loaded! This may not be a ccu or raspimatic."
    parray light
    exit
}

setVariable "$pre${lightNr}_alert" "Alarm der Hue-Lampe $pre${lightNr}" "str" 0 0 ""    "" "" "" false "" "" $light(state,alert)
setVariable "$pre${lightNr}_colormode" "Letzter Colormode der Hue-Lampe $pre${lightNr}" "str" 0 0 ""    "" "" "" false "" "" $light(state,colormode)
setVariable "$pre${lightNr}_effect" "Effekt der Hue-Lampe $pre${lightNr}" "str" 0 0 ""    "" "" "" false "" "" $light(state,effect)
setVariable "$pre${lightNr}_modelid" "ModelID der Hue-Lampe $pre${lightNr}" "str" 0 0 ""    "" "" "" false "" "" $light(modelid)
setVariable "$pre${lightNr}_name" "Name der Hue-Lampe $pre${lightNr}" "str" 0 0 ""    "" "" "" false "" "" $light(name)
setVariable "$pre${lightNr}_type" "Type der Hue-Lampe $pre${lightNr}" "str" 0 0 ""    "" "" "" false "" "" $light(type)
setVariable "$pre${lightNr}_uniqueid" "UniqueID der Hue-Lampe $pre${lightNr}" "str" 0 0 ""    "" "" "" false "" "" $light(uniqueid)
setVariable "$pre${lightNr}_xy" "XY-Farbwert der Hue-Lampe $pre${lightNr}" "str" 0 0 ""    "" "" "" false "" "" "$light(state,xy)"
setVariable "$pre${lightNr}_swversion" "Softwareversion der Hue-Lampe $pre${lightNr}" "str" 0 0 ""    "" "" "" false "" "" $light(swversion)
setVariable "$pre${lightNr}_bri" "Helligkeit der Hue-Lampe $pre${lightNr}" "int" 0 255 ""    "" "" "" false "" "" $light(state,bri)
setVariable "$pre${lightNr}_sat" "Farbsaettigung der Hue-Lampe $pre${lightNr}" "int" 0 255 ""    "" "" "" false "" "" $light(state,sat)
setVariable "$pre${lightNr}_hue" "Farbwert (hue) der Hue-Lampe $pre${lightNr}" "int" 0 65535 ""    "" "" "" false "" "" $light(state,hue)
if {[info exists light(state,ct)]} {
    setVariable "$pre${lightNr}_ct" "Mired Color Temperature (ct) der Hue-Lampe $pre${lightNr}" "int" 153 500 ""    "" "" "" false "" "" $light(state,ct)
}
setVariable "$pre${lightNr}_on" "Hue-Lampe $pre${lightNr} ist an" "lo" 0 0 ""    "" "Lampe aus" "Lampe an" false "" "" $light(state,on)
setVariable "$pre${lightNr}_reachable" "Hue-Lampe $pre${lightNr} ist erreichbar" "lo" 0 0 ""    "" "Lampe nicht erreichbar" "Lampe erreichbar" false "" "" $light(state,reachable)
