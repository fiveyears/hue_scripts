#!/usr/bin/env tclsh
proc wsplit {str sep} {
  split [string map [list $sep \0] $str] \0
}
proc regexp_all {needle haystack } {
	global tcl_version
	if { [  expr $tcl_version >= 8.5] } { 
		set l [regexp -all -inline -indices  $needle $haystack ]
	} else {
		set l {}
		set tmppos 0
		while {[regexp -indices  "$needle" [string range $haystack $tmppos end] var1]} {
			set left [expr [lindex $var1 0] + $tmppos]
			set right [expr [lindex $var1 1] + $tmppos]
			lappend l "$left $right"
			set tmppos [expr $tmppos + [expr [lindex $var1 1] + 1]]
		}
	}
	return $l
}
proc regexp_start {start needle haystack } {
	global tcl_version
	set l {}
	if { [  expr $tcl_version >= 8.5] } { 
		set l [regexp -start $start -inline -indices -- $needle $haystack ]
	} else {
		set tmpstr [string range $haystack $start end]
		if {[regexp -indices $needle $tmpstr var1]} {
			set left [expr [lindex $var1 0] + $start]
			set right [expr [lindex $var1 1] + $start]
		}
		lappend l "$left $right"
	}
	return $l
}
proc set_places {a {places 2}} {
    upvar 1 $a ar
    set f "%0${places}d"
	set n [array names ar  ] 
	foreach name $n {
		set pos [string first "," $name]
		set i [ string range $name 0 [expr $pos -1]]
		set newI [format $f $i]
		if { [string length $newI] != [string length $i] } {
			set newName [string replace $name 0 [expr $pos -1] $newI]
			set ar($newName) $ar($name)
			unset ar($name)
		}
	}
}
proc parray_file {path a {pattern *}} {
    upvar 1 $a array
	set fp [open $path w]
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
    set maxl [expr {$maxl + [string length $a] + 2}]
    foreach name $names {
        set nameString [format %s(%s) $a $name]
        puts $fp [format "%-*s = %s" $maxl $nameString $array($name)]
    }
	close $fp
}
proc myLset {aListname index newVal} {
	upvar 1 $aListname li
	global tcl_version
	if { [  expr $tcl_version >= 8.5] } { 
		lset li $index $newVal
	} {
		set l {}
		if { $index > 0 } {
			set l [ lrange $li 0 [expr $index - 1] ]
		}
		lappend l $newVal
		set l [concat $l  [ lrange  $li [expr $index + 1] end ] ]
		set li $l
	}
}

proc initjson__Bracketlist {} {
	global json__str_raw json__bracketlist
	set json__bracketlist {}
	set b [regexp_all \{ $json__str_raw]
	set e [regexp_all \} $json__str_raw]
	set n [split [string repeat 0 [string length $json__str_raw]] {}]
	foreach x $b { myLset n [lindex $x 0] +1 }
	foreach x $e { myLset n [lindex $x 0] -1 }
	set l 0
	foreach x $n { append json__bracketlist [incr l $x] }
}

proc bracket {startpos} {
	global json__bracketlist
	set level [string index $json__bracketlist $startpos]
	set pos [string first [expr $level - 1] $json__bracketlist $startpos]
	return "[expr $startpos + 1]  $pos "
}

proc getJsonString {name} {
	global json__stringlist
	return [lindex $json__stringlist [string trim $name \" ] ]
}
proc json_run {varname {startpos 0} {strindex ""}} {
	global json__stringlist json__str_raw
	upvar #0 $varname ar
	foreach {b e} [bracket $startpos] {}
	# b begin e end of substring
	# start loop
	set comma ","
	while {$comma == "," } {
		set pos1 [string first ":" $json__str_raw $b]
		set name [string range $json__str_raw $b [expr $pos1 - 1]]
		set name [getJsonString $name]
		set newStartpos [expr $pos1 + 1 ]
	    set char [string index $json__str_raw $newStartpos] 
		if { $strindex == "" } {
			set newStrindex $name
		} else {
			set newStrindex "$strindex,$name"
		}
	    switch "$char" {
	    	\{  { 
	    			set newEnd [json_run $varname $newStartpos $newStrindex]
	    			incr newEnd
	    			set comma [string index $json__str_raw $newEnd]	
	    			set b [expr $newEnd + 1]
	    		}
	    		
	    	\[ {
	    			set newEnd [regexp_start $newStartpos {\]} $json__str_raw ]
	    			set newEnd [lindex [lindex $newEnd 0] 0]
	    			set newEnd [regexp_start $newEnd {[,|\}]} $json__str_raw ]
	    			if {$newEnd == ""} {
	    				puts shit
	    				exit
	    			} {
	    				set newEnd [lindex [lindex $newEnd 0] 0] 
	    			}
	    			set content [string range $json__str_raw $newStartpos [expr $newEnd - 1 ]]
	    			set pos [string first {"} $content  ] ;# " 
	    			if { $pos > -1 } {
	    				set newContent ""
	    				while { $pos > -1 } {
		    				set pos1 [string first {"} $content  [expr $pos + 1] ] ;# "
		    				if { $newContent == "" } {
		    					set newContent "\[\"[getJsonString [string range $content $pos $pos1 ]]\""
		    				} {
			    				set newContent "$newContent,\"[getJsonString [string range $content $pos $pos1 ]]\""
		    				}
		    				set pos [string first {"} $content  [expr $pos1 + 1]] ;# " 
			    		}
			    		set content "$newContent\]"
		    		}
	    			set ar($newStrindex) $content
	    			set comma [string index $json__str_raw $newEnd]
	    			set b [expr $newEnd + 1]
	    		}
	    	default {
	    			set newEnd [regexp_start $newStartpos {[,|\}]} $json__str_raw ]
	    			if {$newEnd == ""} {
	    				puts shit
	    				exit
	    			} {
	    				set newEnd [lindex [lindex $newEnd 0] 0] 
	    			}
	    			set content [string range $json__str_raw $newStartpos [expr $newEnd - 1 ]]
	    			if { $char == {"} } { ;# "
	    				if { $content != {""} } {
	    					set content [getJsonString $content]
	    				}
	    			}
	    			set ar($newStrindex) $content
	    			set comma [string index $json__str_raw $newEnd]
	    			set b [expr $newEnd + 1]
	    		}
	    }
	}
    return $e
}

proc json {varname strraw} {
	# hide backslashed quotation marks and get all other quotation marks
	global json__str_raw json__stringlist json__bracketlist
	set json__stringlist {}
	if { [string first "\[" $strraw ] == 0 } {
		set strraw [string range $strraw 1 end-1] 
	}
	set json__str_raw $strraw
	set qmarks [regexp_all \" [string map {"\\\"" "\\\\"} $json__str_raw] ]
	#create string list
	set j 0
	for {set i [expr [llength $qmarks]-1]} {$i > 0 } {incr i -1}  {
		set pos2 [lindex [lindex $qmarks $i] 0]
		incr i -1
		set pos1 [lindex [lindex $qmarks $i] 0]
		incr pos1
		incr pos2 -1
		lappend json__stringlist [string range $json__str_raw $pos1 $pos2]
		set json__str_raw [string replace $json__str_raw $pos1 $pos2 $j]
		incr j
	}
	# init bracket list
	initjson__Bracketlist
	# $json__str_raw contains structure without strings
	json_run $varname
	unset json__str_raw json__stringlist json__bracketlist
}

