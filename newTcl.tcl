#!/usr/bin/env tclsh
set script_path [file normalize [file dirname $argv0]]
source [file join $script_path "preferences.tcl"]
source [file join $script_path "hue.inc.tcl"]
# load $script_path/bin/libTools[info sharedlibextension]
source hue.inc.core.tcl
# source hue.inc.users.tcl
if { false } {
	::hue::config 
	source hue.inc.users.tcl
	# ::hue::users::delete CpEWUlhPBAEUc4TscZ6vD2MiAzTg5fDmyAGe8Syq
	# ::hue::users::help
	# ::hue::users::deleteByDevice "homebridge-hue#homebridge" -all
	# ::hue::users::printUsers -force -local -clientkey -created -sort 2
	# puts [::hue::users::listV2]
	# puts [::hue::users::_remoteListAll]
	# puts [::hue::users::listUsers 1]
}

if { false } {
	source hue.inc.sensors.tcl
	source hue.inc.foh.tcl
	source hue.inc.foh.diff.tcl

	proc check {} {
		::hue::config set -mode remote   ;# or local (if your local endpoint works)
		::hue::sensors::clearCache
		set ::hue::sensors::cacheTTL 0
		set ::hue::foh::pollMs 80   ;# try 80, or even 50
		::hue::foh::setLongThresholdMs 700
		::hue::foh::watch {24 33}
	}
	::hue::config ;#set -mode remote
	# set rules33 [::hue::foh::dumpRulesForSensor 33]
	# puts $rules33
	puts [::hue::config get -key]
	puts [::hue::config get -raw]
	# puts [::hue::foh::_getV1Json "/rules/5"]
}
# ::hue::foh::dumpAll "/Users/ivo/Desktop/hue_before.json"
# ::hue::foh::dumpAll "/Users/ivo/Desktop/hue_after.json"
# ::hue::sensors::printSensors 
# after you program in iConnectHue:
# set rules24 [::hue::foh::dumpRulesForSensor 24]
# set rules33 [::hue::foh::dumpRulesForSensor 33]
# puts $rules24
# puts $rules33
# puts [::hue::foh::dumpSchedules]
# puts [::hue::foh::dumpResourcelinks]
# puts [::hue::foh::dumpRulesForSensor 33]
# exit
# set after [::hue::foh::dumpAll -tag after -file /Users/ivo/Desktop/hue_after.tcl]
if { true } {
	::hue::config
	# puts [::hue::httpGet "/clip/v2/resource/scene"]

	# Scenes:
	set Santorini "2ca77cf7-85ee-46a0-96df-76f3c513b188"
	set Energize "fdee5bc2-76a6-43d5-92c4-16c0dbbfcfe2"
	set Relax "05fa9729-0a6f-4817-a877-c94e8f0a8724"
	set Read "e0736cad-8cb4-40d2-a2d3-9f71388dac34"

	set scene $Santorini
	set groupV2 "3ba17a05-1ffd-4d47-8bbc-42b6bbf852db"

	# "lights":["37","38","39","40","41","42","43","44","45","46","47","48","49","50","51"],

	::hue::httpPutJson "/clip/v2/resource/grouped_light/$groupV2" "{\"on\":{\"on\": true}}"
	::hue::httpPutJson "/clip/v2/resource/scene/$scene" "{\"recall\":{\"action\": \"active\"}}"
	# ::hue::httpPutJson "/clip/v2/resource/grouped_light/$groupV2" "{\"on\":{\"on\": false}}"

# 	https://192.168.2.50/clip/v2/resource/grouped_light/3ba17a05-1ffd-4d47-8bbc-42b6bbf852db \
# -H "hue-application-key: aFP5jbliw4WE8aWfO-Vlbk6unO8E2r2h5LiwiaHr" \
# -H "Content-Type: application/json" \
# -d '{"on":{"on":false}}'

}