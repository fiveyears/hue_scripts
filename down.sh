#!/bin/sh
dir=$(dirname "$0")
$dir/setLightState.tcl 4 on false
sleep 2
$dir/setLightState.tcl 7 on false
sleep 2
$dir/setLightState.tcl 8 on false
sleep 2
$dir/setLightState.tcl 5 on false
sleep 2
$dir/setLightState.tcl 1 on false
sleep 2
$dir/setLightState.tcl 10 on false
sleep 2
$dir/setLightState.tcl 6 on false
sleep 2
$dir/setLightState.tcl 9 on false
sleep 2
$dir/setLightState.tcl 2 on false
sleep 2
$dir/setLightState.tcl 3 on false
