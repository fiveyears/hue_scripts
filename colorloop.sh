#!/bin/sh
dir=$(dirname "$0")
$dir/setLightState.tcl 4 effect colorloop on true
sleep 2
$dir/setLightState.tcl 7 effect colorloop on true
sleep 2
$dir/setLightState.tcl 8 effect colorloop on true
