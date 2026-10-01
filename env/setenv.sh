#!/bin/sh
if [ -z "$HUE_DIR" ]; then
	HUE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
fi

# test raspimatic
[ -f /VERSION ] && PRODUCT=$(cat /VERSION | grep PRODUCT | cut -f 2 -d =) || PRODUCT=""
# newer RaspberryMatic versions write e.g. "rpi3" instead of "raspmatic_rpi3"
case "$PRODUCT" in ""|raspmatic_*) ;; *) PRODUCT="raspmatic_$PRODUCT" ;; esac
if [ "$PRODUCT" = "raspmatic_rpi3" ]; then
	DEVICENAME=Raspberry
else
	PRODUCT="macos $(sw_vers -productVersion)"
	DEVICENAME=Mac
fi

# test if busybox
BUSYBOX="$(readlink /bin/ls)"
# which app

APPID=$( [[ -n "$1" ]] && ls -d "$HUE_DIR"/*/ | grep "/$1/")
if [ -n "$APPID" ]; then
	APPID="$1"
	shift
elif [[ -f "$HUE_DIR/.appid" ]]; then
	APPID="$(cat "$HUE_DIR/.appid")"
else
	APPID=guestbathstreamer
	# APPID=plug-switcher
fi
echo $APPID >| "$HUE_DIR/.appid"
# 
APP_ENV="$HUE_DIR/$APPID/app_env"
if [ -f "$APP_ENV" ]; then
  source "$APP_ENV" 
  if [ -z "$CLIENTID" -o -z  "$CLIENTSECRET" ]; then
	echo "Please fill in file '$APP_ENV'!"
	exit 1
  fi
  CLIENTBASE64="$(printf "%s" "$CLIENTID:$CLIENTSECRET" | base64 -w 0)"
else
  echo "Please fill in file '$APP_ENV'!"
  printf "%s\n%s\n" "CLIENTID=" "CLIENTSECRET=" >| "$APP_ENV"
  mkdir -p "$HUE_DIR/$APPID"
  exit 1
fi
CONFIG="$HUE_DIR/$APPID/config.hue.tcl"
ENVIRONMENT="$HUE_DIR/$APPID/hue_remote_env"
if [ ! -f "$CONFIG" ]; then
	echo "'$CONFIG' is not available!"
	exit 1
fi
# 
# 
HOST="https://api.meethue.com"
