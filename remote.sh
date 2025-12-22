#!/bin/sh
# Created with /Users/ivo/Dropbox/Shell-Scripts/cmd/crea at 2022-05-01 08:23:57
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
HUE_DIR="$DIR/env"
# set HUE_DIR PRODUCT DEVICENAME BUSYBOX BRIDGE APPID APP_ENV CLIENTID CLIENTSECRET CLIENTBASE64 CONFIG ENVIRONMENT HOST
source "$HUE_DIR/setenv.sh"
# 
# 
# functions
# 
encode() {
	# printf "%s" "$1" | curl -Gso /dev/null -w %{url_effective} --data-urlencode @- "t.com" | cut -c 15-
	jq -rn --arg x "$1" '$x|@uri'
}
# 

testToken () {
	if [ -f "$ENVIRONMENT" ]; then
	  export $(cat "$ENVIRONMENT" | sed 's/#.*//g' | xargs)
	else
	  echo "Please restart with 'remote.sh newToken', $ENVIRONMENT not found!"
		echo "ACCESS_TOKEN=" >| "$ENVIRONMENT"
		echo "REFRESH_TOKEN=" >> "$ENVIRONMENT"
		echo "EXPIRES_AT=" >> "$ENVIRONMENT"
	  exit 1
	fi
	if [ -z "$REFRESH_TOKEN" ]; then 
		echo "REFRESH_TOKEN not found!"
		err=1
	elif [ -z "$ACCESS_TOKEN" ]; then 
		echo "ACCESS_TOKEN not found!"
		err=2
	elif [ -z "$EXPIRES_AT" ]; then 
		echo "EXPIRES_AT not found!"
		err=2
	fi
	if [ "$err" = "1" ]; then
		echo "Please start authentication with $(basename $0) gettoken."
		exit 1
	elif [ "$err" = "2" ]; then
		echo "Please restart with $(basename $0) refreshtoken."
		exit 1
	fi
}
# 

### gettoken

what=$(echo "$1"  | tr '[:upper:]' '[:lower:]')
if [ "$what" = "-s" ]; then

	echo
	echo "Dir:          $DIR"
	iHueDir="$(echo "$HUE_DIR" | sed "s#$DIR#.#g")"
	echo "Hue_Dir:      $iHueDir"
	echo "Product:      $PRODUCT"
	echo "Devicename:   $DEVICENAME"
	echo "Busybox:      ${BUSYBOX:-not set}"
	echo "Bridge:       $BRIDGE (written into $iHueDir/.bridge)"
	echo "Appid:        $APPID (written into $iHueDir/.addid)"
	echo "App_Env:      $APP_ENV" | sed "s#$DIR#.#g"
	echo "Clientid:     $CLIENTID"
	echo "Clientsecret: $CLIENTSECRET"
	echo "Clientbase64: ${CLIENTBASE64:0:30}..."
	echo "Config:       $CONFIG" | sed "s#$DIR#.#g"
	echo "Environment:  $ENVIRONMENT" | sed "s#$DIR#.#g"
	echo "Host:         $HOST"
	echo
elif [ "$what" = "-o" ]; then
	open "$HUE_DIR"
elif [ "$what" = "gettoken" ]; then
	DEVICEID=$(echo $DEVICENAME | tr '[:upper:]' '[:lower:]')
	RESPONSE_TYPE=code
	if [ -n "$BUSYBOX" ]; then 
		STATE=$(($(date -u +%s) - 3660))  
		STATE=$(date -d $STATE -u -D %s +fiveyears%Y%m%d%H   | tr -d '\n' | openssl md5 )
		STATE=$(echo ${STATE/* })
	else
		STATE=$(date -v-1H -u +fiveyears%Y%m%d%H | tr -d '\n' | md5)
	fi
	DEVICEID=$(encode $DEVICEID)
	DEVICENAME=$(encode $DEVICENAME)
	CODE_VERIFIER=$(openssl rand -base64 66 | tr -d '\n' | sed 's/+/_/g' | sed 's/\//_/g' | sed 's/=//g')
	CODE_CHALLENGE=$(printf "%s" "$CODE_VERIFIER" | openssl sha256 -binary | base64 | tr '/+' '_-' | tr -d '=')
	CODE_CHALLENGE_METHOD=S256
	STATE_FILE="hue_${STATE}.txt"
	URI="/v2/oauth2/authorize"
	if [ -n "$BUSYBOX" ]; then 
		echo "Copy url in Browser:"
	    echo "$HOST$URI?client_id=$CLIENTID&response_type=$RESPONSE_TYPE&state=$STATE&appid=$APPID&deviceid=$DEVICEID&devicename=$DEVICENAME&code_challenge_method=$CODE_CHALLENGE_METHOD&code_challenge=$CODE_CHALLENGE"
	    echo
	    echo "Open downloaded file \"hue_${STATE}.txt\" and copy code!"
	    echo
	    read -p "Put in code: " CODE
	else
		DOWNLOADS1="/Users/ivo/Library/Mobile Documents/com~apple~CloudDocs/Downloads"
		DOWNLOADS="/Users/ivo/Downloads"
		rm -f "$DOWNLOADS1/"hue_*.txt 2>/dev/null
		rm -f "$DOWNLOADS/"hue_*.txt 2>/dev/null
		open "$HOST$URI?client_id=$CLIENTID&response_type=$RESPONSE_TYPE&state=$STATE&appid=$APPID&deviceid=$DEVICEID&devicename=$DEVICENAME&code_challenge_method=$CODE_CHALLENGE_METHOD&code_challenge=$CODE_CHALLENGE"
		printf "%s" "Wait 20 seconds for '$STATE_FILE' "
		i=0
		while [[ ! -e "$DOWNLOADS/$STATE_FILE" ]] ; do
			if [[ -e "$DOWNLOADS1/$STATE_FILE" ]] ; then
				mv "$DOWNLOADS1/$STATE_FILE" "$DOWNLOADS/$STATE_FILE"
			fi
			i=$((i+1))
			if [[ $i -gt 20 ]]; then
				echo
				echo "'$STATE_FILE' not found!"
				echo "Please start over!"
				exit 1
			fi
			printf "%s" ". $i "
		    sleep 1
		done
		# terminal hack, clear the line
		echo -e "\033[2K"
		CODE=$(cat "$DOWNLOADS/$STATE_FILE")
		rm -f "$DOWNLOADS/"hue_*.txt 2>/dev/null
	fi
	if [ -z "$CODE" -o -z "$CODE_VERIFIER" ]; then
		echo "Please start authentication with $(basename $0) getToken."
		exit 1
	fi
	##### Access and refresh token
	URI="/v2/oauth2/token"
	CURL_RET=$(curl -s --request POST "$HOST$URI" \
		-d "code=$CODE&grant_type=authorization_code&code_verifier=$CODE_VERIFIER" \
		-H 'Content-Type: application/x-www-form-urlencoded'  \
	    -H "Authorization: Basic $CLIENTBASE64" 2>&1)
	echo $CURL_RET >| log.txt
	CURL_RET=$(echo "$CURL_RET" | cut -f 4,7,10 -d "\"" | tr -d ': ,')
	ACCESS_TOKEN=$(echo "$CURL_RET" | cut -f 1 -d "\"" )
	EXPIRES_IN=$(echo "$CURL_RET" | cut -f 2 -d "\"" )
	REFRESH_TOKEN=$(echo "$CURL_RET" | cut -f 3 -d "\"" )
	echo "ACCESS_TOKEN=$ACCESS_TOKEN" >| "$ENVIRONMENT"
	echo "REFRESH_TOKEN=$REFRESH_TOKEN" >> "$ENVIRONMENT"
	EXPIRES_AT=$(($EXPIRES_IN + $(date +%s)))
	printf "%s" "EXPIRES_AT=$EXPIRES_AT" >> "$ENVIRONMENT"
	if [ -n "$BUSYBOX" ]; then 
		echo "   # ($(date  -d $EXPIRES_AT -D %s "+%Y-%m-%d %H:%M:%S"))" >> "$ENVIRONMENT"
	else
		echo "   # ($(date -j -f "%s" $EXPIRES_AT "+%Y-%m-%d %H:%M:%S"))" >> "$ENVIRONMENT"
	fi

### user

elif [ "$what" = "user" ]; then
	user=$(cat $CONFIG | grep "set user" | grep -v default | tr -s ' ' | cut -d " " -f 3)
	if [ -z $user ]; then
		"$0" newuser
		user=$(cat $CONFIG | grep "set user" | grep -v default | tr -s ' ' | cut -d " " -f 3)
	fi
	echo $user

### bluebutton

elif [ "$what" = "bluebutton" ]; then
	token=$("$0" token)
	URI=/route/api/0/config 
	curl -s -S --request PUT "$HOST$URI" \
		 --header "Authorization: Bearer $token" \
		 --header 'Content-Type: application/json' \
		 --data-raw '{ "linkbutton":true }' 
	echo

### newuser

elif [ "$what" = "newuser" ]; then
	token=$("$0" token)
	URI=/route/api/0/config 
	# curl -s -S --request PUT "$HOST$URI" \
	# 	 --header "Authorization: Bearer $token" \
	# 	 --header 'Content-Type: application/json' \
	# 	 --data-raw '{ "linkbutton":true }' 1>/dev/null
	echo "curl -s -S --request PUT \"$HOST$URI\" \
		 --header \"Authorization: Bearer $token\" \
		 --header 'Content-Type: application/json' \
		 --data-raw '{ \"linkbutton\":true }'"
	URI=/route/api 
	# user=$(curl -s -S --request POST "$HOST$URI" \
	# 	 --header "Authorization: Bearer $token" \
	# 	 --header 'Content-Type: application/json' \
	# 	 --data-raw "{ \"devicetype\": \"$APPID#$(hostname | cut -f 1 -d '.' )\"}")
	echo "curl -s -S --request POST \"$HOST$URI\" \
		 --header \"Authorization: Bearer $token\" \
		 --header 'Content-Type: application/json' \
		 --data-raw \"{ \\\"devicetype\\\": \\\"$APPID#$(hostname | cut -f 1 -d '.' )\\\"}\""
	exit
	user=$(echo $user | cut -f 6 -d '"')
	line1=$(cat $CONFIG | grep "default")
	line2=$(echo "set user $user")
	line3=$(cat $CONFIG | grep -v "set user")
	echo $line1 >| $CONFIG 
	echo $line2 >> $CONFIG
	echo $line3 >> $CONFIG

### deleteuser

elif [ "$what" = "deleteuser" ]; then
# user                                      last used           (created)
# 7bf0a5f0-e288-4791-97cf-7dd1d38a6296:     2025-11-16T15:59:42 (2022-05-06T07:22:48) plug-switcher#MacBookPro
# 5c96d4f0-bbf2-4a06-8742-0553dd52c20e:     2025-11-20T07:34:36 (2022-05-06T14:31:09) plug-switcher#Ivos-iMac-Pro
# 9543b3e1-8120-4d55-b4e1-5039b93e6f27:     2023-11-12T19:34:53 (2021-12-06T20:22:47) Hue#Fiveyears
# 2ba25bb5-0cfb-485f-866e-239b9787edff:     2022-06-10T08:46:13 (2022-05-08T07:00:44) plug-switcher#raspimatic
# 55b085cf-dd29-49e9-8e10-c29c7ea2ed94:     2022-12-19T07:52:39 (2022-12-19T07:44:22) homebridge-hue#raspberrypi
# 0f903302-7d7f-41fe-8e39-36509150417a:     2022-12-19T08:02:11 (2022-12-19T07:54:39) homebridge-hue#raspberrypi
# 7ebbdea7-a8cd-4d12-8e95-75f9dacf002d:     2025-11-16T16:04:14 (2024-11-11T19:04:22) Hue#iPhone
# f3f6df95-2ca8-437e-ac79-91f024dc4b87:     2025-01-03T09:16:54 (2025-01-03T09:16:08) Hue#iPhone
# 66b0ac38-ca4b-4569-94e2-4b8a5067177e:     2025-11-04T09:11:12 (2025-10-09T20:22:52) Philips hue
# 501db390-3668-47b6-9a0f-ef00de3e7636:     2020-11-15T14:44:46 (2018-11-23T16:28:03) Hue 3#Hello poppets
# 6cd4f4c2-19ae-43fc-a106-bca78fea5a3b:     2025-11-20T07:43:55 (2019-11-04T14:01:02) EclipseSmartHome

# "aFP5jbliw4WE8aWfO-Vlbk6unO8E2r2h5LiwiaHr 2025-11-16T15:59:42 (2022-05-06T07:22:48) plug-switcher#MacBookPro"
# "4SbrDhtZykvpsOxfQB5En3riq0WPdWWbSr7qafAp 2025-11-20T08:10:38 (2022-05-06T14:31:09) plug-switcher#Ivos-iMac-Pro"
# "k7f4aLzif9hkyOpyNCQoFZdqlwnCZ9IqzreoxpKF 2023-11-12T19:34:53 (2021-12-06T20:22:47) Hue#Fiveyears"
# "f8VqV-U7j7MSqu247j10h3nwlfhglI7EJ1tfIt1c 2022-06-10T08:46:13 (2022-05-08T07:00:44) plug-switcher#raspimatic"
# "-6zSSG25PCAy1DSDPCLP4zmUZtunaw-Ow88F6qGd 2022-12-19T07:52:39 (2022-12-19T07:44:22) homebridge-hue#raspberrypi"
# "hJNyOtvMlBc1BqVRun7I8wFcfjM77A5FQrLTW0eb 2022-12-19T08:02:11 (2022-12-19T07:54:39) homebridge-hue#raspberrypi"
# "dT78X893rEvqvArk6BDUeEdL2ikBtJj7BiZb4r6w 2025-11-16T16:04:14 (2024-11-11T19:04:22) Hue#iPhone"
# "emUXt1v8CQzUzXdvgiFaJTA0TCs6JuYzmxL2URWi 2025-01-03T09:16:54 (2025-01-03T09:16:08) Hue#iPhone"
# "GVj803X8rN5x0Khh4UuX0Zx9uOxmTE-qW6RRvGNB 2025-11-04T09:11:12 (2025-10-09T20:22:52) Philips hue"
# "7OrkuLAnZBf2uhKM1VpQ5U1Y8N-nA4HIWy2IOTlj 2025-11-20T08:05:46 (2025-11-16T16:08:49) my-entertainment-app#mac"
# "aOP3q2h3icGNQwMQ5Q3Tn0IAEdzKYXLaXvA1cvva 2020-11-15T14:44:46 (2018-11-23T16:28:03) Hue 3#Hello poppets"
# "9DVpRZTFaseWtmyAudvqVWdXegNjJeiYe9OxlFxM 2025-11-20T08:19:07 (2019-11-04T14:01:02) EclipseSmartHome"





	token=$("$0" token)
	user=$(cat $CONFIG | grep "set user" | grep -v default | tr -s ' ' | cut -d " " -f 3)
	user=55b085cf-dd29-49e9-8e10-c29c7ea2ed94
	URI=/route/api/0/config/whitelist/$user 
	# curl -s -S --request DELETE "$HOST$URI" \
	# 	 --header "Authorization: Bearer $token"
	echo "curl -s -S --request DELETE \"$HOST$URI\" --header \"Authorization: Bearer $token\""
	exit
	line1=$(cat $CONFIG | grep "default")
	line3=$(cat $CONFIG | grep -v "set user")
	echo $line1 >| $CONFIG 
	echo $line3 >> $CONFIG

### newtoken

elif [ "$what" = "newtoken" ]; then
	testToken
	"$0" refreshToken 1
	exit 0

### token

elif [ "$what" = "token" ]; then
	testToken
	if [ $(($EXPIRES_AT - $(date +%s) ))  -lt 3660 ]; then
		"$0" refreshToken 1
		exit 0
	fi
	echo $ACCESS_TOKEN

### checktoken

elif [ "$what" = "checktoken" ]; then
	testToken
	echo "ACCESS_TOKEN : $ACCESS_TOKEN"
	printf "%s" "  expires at : "
	if [ -n "$BUSYBOX" ]; then 
		echo "$(date  -d $EXPIRES_AT -D %s "+%Y-%m-%d %H:%M:%S")" 
	else
		echo "$(date -j -f "%s" $EXPIRES_AT "+%Y-%m-%d %H:%M:%S")" 
	fi
	echo "REFRESH_TOKEN: $REFRESH_TOKEN"
	if [ $(($EXPIRES_AT - $(date +%s) ))  -lt 3660 ]; then
		echo "ACCESS_TOKEN is almost expired!"
		echo "Please $0 refreshToken"
	fi

### refreshtoken

elif [ "$what" = "refreshtoken" ]; then
	# $1 = 1 -> Aufruf durch token
	if [ -z "$2" ]; then
		testToken
	fi
	URI="/v2/oauth2/token"
	CURL_RET=$(curl -s -S --request POST "$HOST$URI" -d "grant_type=refresh_token&refresh_token=$REFRESH_TOKEN" \
		-H 'Content-Type: application/x-www-form-urlencoded'  \
	    -H "Authorization: Basic $CLIENTBASE64"		2>&1 )
	# echo $CURL_RET
	CURL_RET=$(echo "$CURL_RET" | cut -f 4,7,10 -d "\"" | tr -d ': ,')
	ACCESS_TOKEN=$(echo "$CURL_RET" | cut -f 1 -d "\"" )
	REFRESH_TOKEN=$(echo "$CURL_RET" | cut -f 3 -d "\"" )
	EXPIRES_IN=$(echo "$CURL_RET" | cut -f 2 -d "\"" )
	echo "ACCESS_TOKEN=$ACCESS_TOKEN" >| "$ENVIRONMENT"
	echo "REFRESH_TOKEN=$REFRESH_TOKEN" >> "$ENVIRONMENT"
	EXPIRES_AT=$(($EXPIRES_IN + $(date +%s)))
	printf "%s" "EXPIRES_AT=$EXPIRES_AT" >> "$ENVIRONMENT"
	if [ -n "$BUSYBOX" ]; then 
		echo "   # ($(date  -d $EXPIRES_AT -D %s "+%Y-%m-%d %H:%M:%S"))"  >> "$ENVIRONMENT"
	else
		echo "   # ($(date -j -f "%s" $EXPIRES_AT "+%Y-%m-%d %H:%M:%S"))"  >> "$ENVIRONMENT"
	fi
	if [ -n "$2" ]; then
		echo $ACCESS_TOKEN
	fi

### help

else
	echo "Token commands"
	echo "   $(basename $0) token | newToken | getToken | refreshToken | checkToken"
	echo "User commands"
	echo "   $(basename $0) user | newUser | deleteUser"
	echo "Config commands"
	echo "   $(basename $0) bluebutton"
	echo "   $(basename $0) -s ... Show environment"
	echo "   $(basename $0) -o ... Open environment directory"
	exit 
fi	


