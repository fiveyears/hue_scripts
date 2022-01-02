#!/bin/zsh
# Created with /Users/ivo/Dropbox/Shell-Scripts/cmd/crea at 2021-11-04 10:34:59
#if [ -z "$1" ]; then
#	echo "No scriptname is given!"
#	echo "Usage $0 scriptname"
#	exit 0
#fi
option=$(testkey)
#  512 = shift
# 4096 = control
# 2048 = option
#	if [ $(( $option  & 512 )) -gt 0 ]; then
#		echo shift
#	fi
#	if [ $(( $option  & 4096 )) -gt 0 ]; then
#		echo control
#	fi
#	if [ $(( $option  & 2048 )) -gt 0 ]; then
#		echo option
#	fi
#	if [ $(( $option  & 256 )) -gt 0 ]; then
#		echo command
#	fi
#fi

dir=$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)
ip=$(cat ~/.ssh/config | grep -A 2 ccu | grep -i Hostname | cut -d "H" -f 2 | cut -d " " -f 2)
# cat ~/.ssh/config | grep -A 2 ccu | grep -i Hostname | tr -d " " | cut -d "e" -f 2
url="http://$ip:8181/Test.exe"
runProg () {
	script="var o = dom.GetObject('$1');o.ProgramExecute();"
	curl -s --location --request POST $url --header 'Content-Type: text/plain' --data-raw "$script"
}

runScript () {
	curl -s --location --request POST $url --header 'Content-Type: text/plain' --data-raw "$1" | sed -e 's/<exec>.*<\/exec>//g' -e 's/<sessionId>.*<\/sessionId>//g' \
	-e 's/<httpUserAgent>.*<\/httpUserAgent>//g' -e 's/<xml><\/xml>//g'
}

#$dir/setLightRgb.tcl D2 green &>/dev/null
#$dir/LightOnOff.tcl D2 0 &>/dev/null
#$dir/LightStateSaveCCU.sh "D2"
#$dir/LightStateReadCCU.sh -e "D2"
# runProg "Door open"
# $dir/LightStateReadCCU.sh -e "D2"
#runProg "Door long open"
#$dir/LightStateReadCCU.sh -e "D2"
#runProg "Door closed"
#$dir/LightStateReadCCU.sh -e "D2"

runScript 'WriteLine("Hallo");var i = 1;'

