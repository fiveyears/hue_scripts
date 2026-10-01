#!/bin/sh
# entertainment id
# APPKEY=aFP5jbliw4WE8aWfO-Vlbk6unO8E2r2h5LiwiaHr
# 
# username = appkey
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
HUE_DIR="$DIR/env"
# set HUE_DIR PRODUCT DEVICENAME BUSYBOX BRIDGE APPID APP_ENV CLIENTID CLIENTSECRET CLIENTBASE64 CONFIG ENVIRONMENT HOST
source "$HUE_DIR/setenv.sh"
# TOKEN=$($DIR/remote.sh token)
# $DIR/remote.sh bluebutton; sleep 2
# curl -s -X POST https://api.meethue.com/route/api \
#   -H "Authorization: Bearer $TOKEN" \
#   -H "Content-Type: application/json" \
#   -d '{"devicetype": "guestbath#hue", "generateclientkey": true}'

CLIENTKEY="8FF5BC23AA57441B555C594F0FFDDB86"
# curl  -k -s -X GET "https://192.168.2.50/clip/v2/resource/entertainment_configuration" \
#     -H "hue-application-key: $APPKEY" \
#       | jq .
# exit
APPKEY="9488bi-Yz78HLg9HuEWOoQjTAqM8iWmG90VixLpk"

# for RID in \
#   7198eeef-0c04-4232-942a-902c67183b53 \
#   4b19ef2f-6935-45be-b79c-836f23b548e2 \
#   83bcf837-6422-4417-8751-250e5b5f7842 \
#   28ad7b0a-5ed6-40da-928a-357fd3240221 \
#   cf6b19b5-44d0-475c-b769-1d9a37c32b78 \
#   d55fd8e6-94b5-427e-952f-df14946e14e4 \
#   959974e8-fbc6-4555-91ce-3af37e555855
# do
#   echo "Disabling dynamics on light $RID..."
#   curl -k -s -X PUT "https://192.168.2.50/clip/v2/resource/light/$RID" \
#     -H "hue-application-key: $APPKEY" \
#     -H "Content-Type: application/json" \
#     -d '{"dynamics":{"status":"none"}}'
#   echo ""
# done
# exit
# curl -k -s https://192.168.2.50/clip/v2/resource/light/7198eeef-0c04-4232-942a-902c67183b53 \
#   -H "hue-application-key: 9488bi-Yz78HLg9HuEWOoQjTAqM8iWmG90VixLpk" | jq .
# curl -k -s https://192.168.2.50/clip/v2/resource/light/4b19ef2f-6935-45be-b79c-836f23b548e2 \
#   -H "hue-application-key: 9488bi-Yz78HLg9HuEWOoQjTAqM8iWmG90VixLpk" | jq .
# curl -k -s https://192.168.2.50/clip/v2/resource/light/83bcf837-6422-4417-8751-250e5b5f7842 \
#   -H "hue-application-key: 9488bi-Yz78HLg9HuEWOoQjTAqM8iWmG90VixLpk" | jq .
# curl -k -s https://192.168.2.50/clip/v2/resource/light/28ad7b0a-5ed6-40da-928a-357fd3240221 \
#   -H "hue-application-key: 9488bi-Yz78HLg9HuEWOoQjTAqM8iWmG90VixLpk" | jq .
# curl -k -s https://192.168.2.50/clip/v2/resource/light/cf6b19b5-44d0-475c-b769-1d9a37c32b78 \
#   -H "hue-application-key: 9488bi-Yz78HLg9HuEWOoQjTAqM8iWmG90VixLpk" | jq .
# curl -k -s https://192.168.2.50/clip/v2/resource/light/d55fd8e6-94b5-427e-952f-df14946e14e4 \
#   -H "hue-application-key: 9488bi-Yz78HLg9HuEWOoQjTAqM8iWmG90VixLpk" | jq .
# curl -k -s https://192.168.2.50/clip/v2/resource/light/959974e8-fbc6-4555-91ce-3af37e555855 \
#   -H "hue-application-key: 9488bi-Yz78HLg9HuEWOoQjTAqM8iWmG90VixLpk" | jq .
# exit
NAME="Guestbath"
ID="221e964f-06ac-4364-8c0d-81ea0ffe35e9"
# curl -X POST https://api.meethue.com/route/api \
#   -H "Authorization: Bearer <access_token>" \
#   -H "Content-Type: application/json" \
#   -d '{"devicetype": "my-app#pc"}'

# curl -k -s -X PUT \
#   "https://192.168.2.50/clip/v2/resource/entertainment_configuration/$ID" \
#   -H "hue-application-key: $APPKEY" \
#   -H "Content-Type: application/json" \
#   -d '{"action":"stop"}'
# curl -k -s \
#   "https://192.168.2.50/clip/v2/resource/entertainment_configuration" \
#   -H "hue-application-key: $APPKEY" | jq .
curl -k -s -X PUT \
  "https://192.168.2.50/clip/v2/resource/entertainment_configuration/$ID" \
  -H "hue-application-key: $APPKEY" \
  -H "Content-Type: application/json" \
  -d '{"action":"start"}'
# curl -k -s \
#   "https://192.168.2.50/clip/v2/resource/entertainment_configuration" \
#   -H "hue-application-key: $APPKEY" | jq .  >| $HOME/Desktop/t.txt
openssl s_client -dtls1_2 \
    -psk "$CLIENTKEY" \
    -psk_identity "HueStream" \
    -connect 192.168.2.50:2100 \
    -quiet
exit

if [ -z "$ID" ]; then
	ID=$(curl  -k -s -X GET "https://192.168.2.50/clip/v2/resource/entertainment_configuration" \
	  -H "hue-application-key: $APPKEY" \
	  	| jq '.data[] | .id + " " +  .name' | grep -i "$NAME" | cut -d " " -f1 | tr -d "\"")
	echo $ID
fi
curl -k -s -X PUT \
  "https://192.168.2.50/clip/v2/resource/entertainment_configuration/$ID" \
  -H "hue-application-key: $APPKEY" \
  -H "Content-Type: application/json" \
  -d '{"action":"stop"}'
curl -k -s "https://192.168.2.50/clip/v2/resource/entertainment_configuration" \
  -H "hue-application-key: $APPKEY" | jq . >| $HOME/Desktop/t.txt
# exit
curl  -k -s -X PUT "https://192.168.2.50/clip/v2/resource/entertainment_configuration/$ID" \
  -H "hue-application-key: $APPKEY" \
  -H "Content-Type: application/json" \
  -d '{"action":"start"}'
# curl -k -s "https://192.168.2.50/clip/v2/resource/entertainment_configuration/$ID" \
#   -H "hue-application-key: $APPKEY" | jq .
openssl s_client -dtls1_2 -connect 192.168.2.50:2100 -quiet



