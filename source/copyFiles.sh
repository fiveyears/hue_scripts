#!/bin/zsh
dir=$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)
cd "$dir/.."
ssh="${1:-ub}"
if [ "$ssh" = "ub" ]; then
	path=Documents/develop/hue
elif [ "$ssh" = "ccu" ]; then
	path=/usr/local/scripts/hue
else
	echo "Wrong ssh '$ssh'!"
	exit 1
fi
/usr/bin/scp \
    test.tcl \
	ccu_helper.tcl \
	ccu_read_hue.tcl \
	changeSensorConfig.tcl \
	colorloop.sh \
	createGroup.tcl \
	createSchedule.tcl \
	deleteGroup.tcl \
	deleteScene.tcl \
	deleteSchedule.tcl \
	getAll.tcl \
	getAllConfig.tcl \
	getAllGroups.tcl \
	getAllLights.tcl \
	getAllScenes.tcl \
	getAllSchedules.tcl \
	getAllSensors.tcl \
	getCapabilities.tcl \
	getGroupAttributes.tcl \
	getHue.tcl \
	getLightAttributesAndState.tcl \
	getNewLights.tcl \
	getScene.tcl \
	getScheduleAttributes.tcl \
	getSensor.tcl \
	hue.inc.tcl \
	hue2.inc.tcl \
	LightOnOff.tcl \
	LightStateDelete.tcl \
	LightStateDeleteCCU.sh \
	LightStateRead.tcl \
	LightStateReadCCU.sh \
	LightStateSave.tcl \
	LightStateSaveCCU.sh \
	README.md \
	searchForNewLights.tcl \
	setGroupAttributes.tcl \
	setGroupState.tcl \
	setLightAttributes.tcl \
	setLightRgb.tcl \
	setLightState.tcl \
	${ssh}:$path
