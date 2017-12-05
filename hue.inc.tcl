package require http

proc hueGet {{url ""}} {
	global ip user
	set url "http://$ip/api/$user/$url"
	set r [http::geturl $url]
	set ret [http::data $r]
	::http::cleanup $r
	regsub -all  {^.*application/json\s*} $ret "" newret
	return $newret
}

proc hueDelete {{url ""}} {
	global ip user
	set header {DELETE /api/$user/$url HTTP/1.1
HOST: $ip}
	set s [socket $ip 80]
	puts $s [subst $header]
	flush $s
	set ret [read $s]
	close $s
	regsub -all  {^.*application/json\s*} $ret "" newret
	return $newret
}

proc huePut {url body} {
	global ip user
	set body [subst $body]
	set header {PUT /api/$user/$url HTTP/1.1
HOST: $ip
Content-Length: [string length $body]
Content-Type: text/plain; charset=UTF-8
Connection: keep-alive

$body
}
	set s [socket $ip 80]
	puts $s [subst $header]
	flush $s
	set ret [read $s]
	close $s
	regsub -all  {^.*application/json\s*} $ret "" newret
	return $newret

}

proc huePost {url body} {
	global ip user
	set body [subst $body]
	if {$url == ""} {
		set api "/api"  ;# Create Config
	} else {
		set api "/api/$user/$url"
	}
	set header {POST $api HTTP/1.1
HOST: $ip
Content-Length: [string length $body]
Content-Type: application/json; charset=UTF-8
Connection: keep-alive

$body
}
	set s [socket $ip 80]
	puts $s [subst $header]
	flush $s
	set ret [read $s]
	close $s
	regsub -all  {^.*application/json\s*} $ret "" newret
	return $newret

}

proc getBody {bodyarray} {
	set body ""
	if {[llength $bodyarray] > 1} {
		for {set i 1} {$i<[llength $bodyarray]} {incr i} {
		   set n [lindex $bodyarray $i]
		   incr i
		   set v [lindex $bodyarray $i]
		   if {$v != ""} {
		   		switch $n {
		   			on {
		   				set body "$body,\"on\":$v"
		   			}
		   			bri {
		   				set body "$body,\"bri\":$v"
		   			}
		   			bri_inc {
		   				set body "$body,\"bri_inc\":$v"
		   			}
		   			hue {
		   				set body "$body,\"hue\":$v"
		   			}
		   			hue_inc {
		   				set body "$body,\"hue_inc\":$v"
		   			}
		   			sat {
		   				set body "$body,\"sat\":$v"
		   			}
		   			sat_inc {
		   				set body "$body,\"sat_inc\":$v"
		   			}
		   			transitiontime {
		   				set body "$body,\"transitiontime\":$v"
		   			}
		   			effect {
		   				set body "$body,\"effect\":\"$v\""
		   			}
		   			alert {
		   				set body "$body,\"alert\":\"$v\""
		   			}
		   			scene {
		   				set body "$body,\"scene\":\"$v\""
		   			}
		   			ct {
		   				set body "$body,\"ct\":$v"
		   			}
		   			ct_inc {
		   				set body "$body,\"ct_inc\":$v"
		   			}
		   			xy {
		   				set body "$body,\"xy\":\\\[$v\\\]"
		   			}
		   			xy_inc {
		   				set body "$body,\"xy_inc\":\\\[$v\\\]"
		   			}
		   		}
		   } else {
		   		switch $n {
		   			on {
		   				set body "$body,\"on\":true"
		   			}
		   			off {
		   				set body "$body,\"on\":false"
		   			}
		   		}
		   }
		}

	}
	return $body
}

proc wsplit {str sep} {
  split [string map [list $sep \0] $str] \0
}

