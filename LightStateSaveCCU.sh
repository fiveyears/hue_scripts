#!/bin/zsh
# Created with /Users/ivo/Dropbox/Shell-Scripts/cmd/crea at 2021-10-30 11:26:23
if [ -z "$1" ]; then
	echo "No Light is given!"
	echo "Usage $0 Lightname|LightNr"
	exit 0
fi
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
ssh ccu "/usr/local/scripts/hue/LightStateSave.tcl \"$1\" \"$2\""