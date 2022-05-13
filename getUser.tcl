#!/usr/bin/env tclsh
set script_path [file normalize [file dirname $argv0]]
source [file join $script_path "preferences.tcl"]
source [file join $script_path "hue.inc.tcl"]
load $script_path/bin/libTools[info sharedlibextension]
set resolveV1 "--header \"Authorization: Bearer [exec $script_path/remote.sh token]\" https://api.meethue.com/route/api/0"
set s [jsonparser users [hueGet "config"]]
set ss [exec echo $s | grep "(bridgeid)" | sed "s/users(bridgeid)/id/g"]
eval [ jsonMapper  $ss ]
puts "BridgeID: $id"
catch {set ss [exec echo $s | grep whitelist | grep name  | sed "s/whitelist,//g" | sed "s/,name//g" ]
eval [ jsonMapper  $ss ]}
			foreach {key value} [array get users] {
				eval "set \"$value\"" $key
				puts  "   $value: $key"
			}
puts "Current user: [exec ./remote.sh user]"