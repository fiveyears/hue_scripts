#!/bin/sh
# Created with /Users/ivo/Dropbox/Shell-Scripts/cmd/crea at 2022-05-01 08:23:57
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ "$HOME" = "/root" ]; then
	config="$dir/bin/.hue/0/config.hue.tcl"
	env="$dir/bin/.hue/0/hue_remote_env"
else
	config="$HOME/.hue/0/config.hue.tcl"
	env="$HOME/.hue/0/hue_remote_env"
fi
Host="https://api.meethue.com"
script="remote.sh"

encode() {
	echo $( php -r "echo urlencode(\"$1\");"; )
}

testToken () {
	if [ -f "$env" ]; then
	  export $(cat "$env" | sed 's/#.*//g' | xargs)
	else
	  echo "Please restart with '$script newToken', $env not found!"
	  exit 1
	fi
	if [ -z "$ClientId" ]; then 
		echo "ClientId not found!"
		err=1
	fi
	if [ -z "$ClientSecret" ]; then 
		echo "ClientSecret not found!"
		err=1
	fi
	if [ -z "$appid" ]; then 
		echo "appid not found!"
		err=1
	fi
	if [ -z "$code_verifier" ]; then 
		echo "code_verifier not found!"
		err=1
	fi
	if [ -z "$nonce" ]; then 
		echo "nonce not found!"
		err=1
	fi
	if [ -z "$realm" ]; then 
		echo "realm not found!"
		err=1
	fi
	if [ -z "$response" ]; then 
		echo "response not found!"
		err=1
	fi
	if [ -z "$access_token" ]; then 
		echo "access_token not found!"
		err=1
	fi
	if [ -z "$refresh_token" ]; then 
		echo "refresh_token not found!"
		err=1
	fi
	if [ -z "$expires_at" ]; then 
		echo "expires_at not found!"
		err=1
	fi
	if [ "$err" = "1" ]; then
		echo "Please start over!"
		exit 1
	fi
}
what=$(echo "$1"  | tr '[:upper:]' '[:lower:]')
if [ "$what" = "gettoken" ]; then
	devicename="$(hostname | cut -f 1 -d '.' )"
	if [ -n "$2" ]; then
		devicename="$@"
	fi
	deviceid=$(echo ${(L)devicename} | tr " " "_")
	response_type=code
	state=$(date -v-1H -u +fiveyears%Y%m%d%H | tr -d '\n' | md5)
	deviceid=$(encode $deviceid)
	devicename=$(encode $devicename)
	code_verifier=$(openssl rand -base64 66 | tr -d '\n' | sed 's/+/_/g' | sed 's/\//_/g' | sed 's/=//g')
	code_challenge=$(echo -n "$code_verifier" | openssl sha256 -binary | base64 | tr '/+' '_-' | tr -d '=')
	code_challenge_method=S256
	filename="hue_${state}.txt"
	uri="/v2/oauth2/authorize"
	rm -f "$HOME/Downloads/"hue_*.txt 2>/dev/null
	open "$Host$uri?client_id=$ClientId&response_type=$response_type&state=$state&appid=$appid&deviceid=$deviceid&devicename=$devicename&code_challenge_method=$code_challenge_method&code_challenge=$code_challenge"
	echo -n "Wait 10 seconds for '$filename' "
	i=0
	while [[ ! -e "$HOME/Downloads/$filename" ]] ; do
		((i++))
		if [[ $i -gt 10 ]]; then
			echo
			echo "'$filename' not found!"
			echo "Please start over!"
			exit 1
		fi
		echo -n .
	    sleep 1
	done
	echo -e "\033[2K"
	code=$(cat "$HOME/Downloads/$filename")
	rm -f "$HOME/Downloads/"hue_*.txt 2>/dev/null
	if [ -z "$code" -o -z "$code_verifier" ]; then
		echo "Please start authentication with $(basename $0) getCode."
		exit 1
	fi
	##### Access and refresh token
	uri="/v2/oauth2/token"
	ret=$(curl -v -s --request POST "$Host$uri" \
		-d "code=$code&grant_type=authorization_code&code_verifier=$code_verifier" \
		-H 'Content-Type: application/x-www-form-urlencoded' -H 'Content-Length: 0' 2>&1 )
	# echo $ret >| log.txt
	nonce=$(echo "$ret"  | grep "Digest realm=\"oauth2_client@api.meethue.com\"" | grep "nonce")
	realm=$(echo $nonce  | cut -f 2 -d "\""  ) 
	nonce=$(echo $nonce  | cut -f 4 -d "\""  ) 
	if [ -z "$nonce" -o -z "$realm" ]; then
		echo "Request failed!"
		echo "Please start over!"
		exit 1
	fi
	HASH1=$(echo -n "$ClientId:$realm:$ClientSecret" | md5)
	HASH2=$(echo -n "POST:$uri" | md5)
	response=$(echo -n "$HASH1:$nonce:$HASH2" | md5)
	ret=$(curl -s --request POST "$Host$uri" -d "grant_type=authorization_code&code=$code&code_verifier=$code_verifier" \
		-H "Authorization: Digest username=\"$ClientId\", realm=\"$realm\", nonce=\"$nonce\", uri=\"$uri\", response=\"$response\"" \
		-H 'Content-Type: application/x-www-form-urlencoded'  2>&1 )
	ret=$(echo "$ret" | cut -f 4,7,10 -d "\"" | tr -d ': ,')
	access_token=$(echo "$ret" | cut -f 1 -d "\"" )
	expires_in=$(echo "$ret" | cut -f 2 -d "\"" )
	refresh_token=$(echo "$ret" | cut -f 3 -d "\"" )
	echo "code_verifier=$code_verifier" >| "$env"
	echo "nonce=$nonce" >> "$env"
	echo "realm=$realm" >> "$env"
	echo "response=$response" >> "$env"
	echo "access_token=$access_token" >> "$env"
	echo "refresh_token=$refresh_token" >> "$env"
	expires_at=$(($expires_in + $(date +%s)))
	echo -n "expires_at=$expires_at" >> "$env"
	echo "   # ($(date -j -f "%s" $expires_at "+%Y-%m-%d %H:%M:%S"))" >> "$env"
elif [ "$what" = "user" ]; then
	user=$(cat $config | grep "set user" | grep -v default | tr -s ' ' | cut -d " " -f 3)
	if [ -z $user ]; then
		"$0" newuser
		user=$(cat $config | grep "set user" | grep -v default | tr -s ' ' | cut -d " " -f 3)
	fi
	echo $user
elif [ "$what" = "newuser" ]; then
	token=$("$0" token)
	uri=/route/api/0/config 
	curl -s -S --request PUT "$Host$uri" \
		 --header "Authorization: Bearer $token" \
		 --header 'Content-Type: application/json' \
		 --data-raw '{ "linkbutton":true }' 1>/dev/null
	uri=/route/api 
	user=$(curl -s -S --request POST "$Host$uri" \
		 --header "Authorization: Bearer $token" \
		 --header 'Content-Type: application/json' \
		 --data-raw "{ \"devicetype\": \"$appid#$(hostname | cut -f 1 -d '.' )\"}")
	user=$(echo $user | cut -f 6 -d '"')
	line1=$(cat $config | grep "default")
	line2=$(echo "set user $user")
	line3=$(cat $config | grep -v "set user")
	echo $line1 >| $config 
	echo $line2 >> $config
	echo $line3 >> $config
elif [ "$what" = "deleteuser" ]; then
	token=$("$0" token)
	user=$(cat $config | grep "set user" | grep -v default | tr -s ' ' | cut -d " " -f 3)
	uri=/route/api/0/config/whitelist/$user 
	curl -s -S --request DELETE "$Host$uri" \
		 --header "Authorization: Bearer $token"
	line1=$(cat $config | grep "default")
	line3=$(cat $config | grep -v "set user")
	echo $line1 >| $config 
	echo $line3 >> $config
elif [ "$what" = "newtoken" ]; then
	testToken
	"$0" refreshToken 1
	exit 0
elif [ "$what" = "token" ]; then
	testToken
	if [ $(($expires_at - $(date +%s) ))  -lt 60 ]; then
		"$0" refreshToken 1
		exit 0
	fi
	echo $access_token
elif [ "$what" = "checktoken" ]; then
	testToken
	echo "Access_token : $access_token"
	echo "  expires at : $(date -j -f "%s" $expires_at "+%Y-%m-%d %H:%M:%S")"
	echo "Refresh_token: $refresh_token"
	if [ $(($expires_at - $(date +%s) ))  -lt 60 ]; then
		echo "Access_token is expired!"
		echo "Please $0 refresh"
	fi
	echo "code_verifier: $code_verifier"
	echo "nonce        : $nonce"
	echo "realm        : $realm"
	echo "response     : $response"
elif [ "$what" = "refreshtoken" ]; then
	# $1 = 1 -> Aufruf durch token
	if [ -z "$2" ]; then
		testToken
	fi
	uri="/v2/oauth2/token"
	ret=$(curl -s --request POST "$Host$uri" -d "grant_type=refresh_token&refresh_token=$refresh_token&code_verifier=$code_verifier" \
		-H "Authorization: Digest username=\"$ClientId\", realm=\"$realm\", nonce=\"$nonce\", uri=\"$uri\", response=\"$response\"" \
		-H 'Content-Type: application/x-www-form-urlencoded'  2>&1 )
	ret=$(echo "$ret" | cut -f 4,7,10 -d "\"" | tr -d ': ,')
	access_token=$(echo "$ret" | cut -f 1 -d "\"" )
	expires_in=$(echo "$ret" | cut -f 2 -d "\"" )
	refresh_token=$(echo "$ret" | cut -f 3 -d "\"" )
	echo "code_verifier=$code_verifier" >| "$env"
	echo "nonce=$nonce" >> "$env"
	echo "realm=$realm" >> "$env"
	echo "response=$response" >> "$env"
	echo "access_token=$access_token" >> "$env"
	echo "refresh_token=$refresh_token" >> "$env"
	expires_at=$(($expires_in + $(date +%s)))
	echo -n "expires_at=$expires_at" >> "$env"
	echo "   # ($(date -j -f "%s" $expires_at "+%Y-%m-%d %H:%M:%S"))" >> "$env"
	if [ -n "$2" ]; then
		echo $access_token
	fi
else
	echo "Token commands"
	echo "   $(basename $0) token | newToken | getToken | refreshToken | checkToken"
	echo "User commands"
	echo "   $(basename $0) user | newUser | deleteUser"
	exit 
fi	


