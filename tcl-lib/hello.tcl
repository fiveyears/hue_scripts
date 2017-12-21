#!/usr/bin/env tclsh
set script_path [file dirname [info script]]
load $script_path/libTools[info sharedlibextension]
set s "$script_path/json.txt"
eval [jsonparser light $s]
# puts [listColors "b" ] 
#puts "LLC001: [realXY "LLC001" "0.1,0.8"] [calcRGB "LLC001" "0.1,0.8"] [gamutForModel "LLC001" ]"
#puts "LCT001: [realXY "LCT001" "0.1,0.8"] [calcRGB "LCT001" "0.1,0.8"] [gamutForModel "LCT001" ]"
#puts "LLC020: [realXY "LLC020" "0.1,0.8"] [calcRGB "LLC020" "0.1,0.8"] [gamutForModel "LLC020" ]"
#puts "dummy:  [realXY "dummy"  "0.1,0.8" ] [calcRGB "dummy" "0.1,0.8" ] [gamutForModel "dummy"  ]"
#puts "LLC001: [calcXY "LLC001" "green"] [calcRGB "LLC001" [calcXY "LLC001" "green"]] "
#puts "LCT001: [calcXY "LCT001" "green"] [calcRGB "LCT001" [calcXY "LCT001" "green"]] "
#puts "LLC020: [calcXY "LLC020" "green"] [calcRGB "LLC020" [calcXY "LLC020" "green"]] "
#puts "dummy:  [calcXY "dummy"  "green"] [calcRGB "dummy"  [calcXY "dummy"  "green"]] "
puts [realRGB FF0000]
# parray light
