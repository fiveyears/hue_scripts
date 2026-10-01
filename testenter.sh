#!/bin/bash
BRIDGE="192.168.2.50"
USER=aFP5jbliw4WE8aWfO-Vlbk6unO8E2r2h5LiwiaHr

# curl -X PUT "http://$BRIDGE/api/$USER/groups/2" \
#   -H "Content-Type: application/json" \
#   -d '{
#     "name": "spots",
#     "lights": ["27","20","22","28","21","26","25"]
# }'
# Create
# GROUP_ID=$(curl -s -X POST \
#   "http://$BRIDGE/api/$USER/groups" \
#   -H "Content-Type: application/json" \
#   -d '{
#         "name": "newstrips",
#         "type": "LightGroup",
#         "lights": ["23","24"]
#       }' | jq -r '.[0].success.id' | cut -d'/' -f3)

# echo "Group created: $GROUP_ID"


# curl "http://$BRIDGE/api/$USER/groups" | jq .
l="0.1844,0.5921"
# l="0.5469,0.4395"
curl -s -X PUT \
  "http://$BRIDGE/api/$USER/groups/4/action" \
  -d "{\"on\":true,\"xy\":[$l]}"

  