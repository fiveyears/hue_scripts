set user 0; set ip "0.0.0.0"; set id 0 ;# default values
set user aFP5jbliw4WE8aWfO-Vlbk6unO8E2r2h5LiwiaHr
set ip "192.168.2.50"
set id "c42996fffec70cdc"
set resolveV1 "--insecure --resolve c42996fffec70cdc:443:192.168.2.50 https://c42996fffec70cdc/api/$user"
set resolveV2 "--insecure --header \"hue-application-key: $user\" --resolve c42996fffec70cdc:443:192.168.2.50 https://c42996fffec70cdc/clip/v2"
