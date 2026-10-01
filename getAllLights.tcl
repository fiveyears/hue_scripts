#!/usr/bin/env tclsh
global resolveV1 lightsV1 PRODUCT
if { "[info script]" == "$::argv0" } {
	set script_path [file normalize [file dirname $argv0]]
	source [file join $script_path "preferences.tcl"]
	source [file join $script_path "hue.inc.tcl"]
	load $script_path/bin/v2/libTools[info sharedlibextension]
	set places 2
	if { "$reset" == 1 } {
		writeIt light
		writeIt device
		writeIt lightsV1
		set bridges [i_getBridgeList]
	} elseif  { "$all" == 1 } {
		testIt light 1
		testIt device 1
		testIt lightsV1 1	
		set bridges [i_getBridgeList]
	} else {
		testIt light 1 "" $bridge 
		testIt device 1 "" $bridge
		testIt lightsV1 1 "" $bridge	
		set bridges $bridge
	}
} else {
	global all bridge places bridges reset light device script_path
	if { "$reset" == 1 } {
		writeIt lightsV1
		set bridges [i_getBridgeList]
	} elseif  { "$all" == 1 } {
		testIt lightsV1 1	
		set bridges [i_getBridgeList]
	} else {
		testIt lightsV1 1 "" $bridge	
	}
}
#test only local bridge
readIt lightsV1 "" 1 0 "" $bridges
set a "s"
if {$argc > 0} { 
	set a [lindex $argv 0]
}
foreach br $bridges {
	foreach li [lsort [array names lightsV1  -regexp "$br,\[0-9\]*,name"]] {
		set i [scan [lindex [split $li , ] 1] %d]
		readIt light "($br,.*lights/$i\"$" 1
		set nr [lindex [split [pparray light return] ,] 1]
		# nr index in light array
		regsub {,name} $li "" m
		set m "lightsV1($m"
		if { $nr != "" } {
			readIt light "($br,$nr,id)" 1 0
			set deviceId $light($br,$nr,id)
			if { $deviceId == "" } {
				exit
			}
			# deviceId from array light
			set "$m,lightId)" $deviceId
			readIt device "$deviceId" 1 0
			# devNr index in array device
			set devNr [split [array names device] ,]
			set rid "device([lindex $devNr 0],[lindex $devNr 1],id)"
			set name "device([lindex $devNr 0],[lindex $devNr 1],metadata,name)"
			if { $m == "" || $rid == "" } {
				exit
			}
			readIt device "$name" 1	 0
			set name [set $name]
			readIt device "$rid" 1	 0
			set rid [set $rid]
			set "$m,metadata,name)" $name
			set "$m,deviceId)" $rid

			
		}
	}
}

if {"$a" == "h"} {
	if { "$PRODUCT" == "raspmatic_rpi3" } {
		set filename "/usr/local/etc/config/addons/www/hue/Lights.html"
	} else {
		set filename "Lights.html"
	}
	set fileId [open $filename "w"]
	puts $fileId  "<html><meta charset=\"utf-8\" />"
	puts $fileId "<head>
	<link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/bootstrap@4.1.3/dist/css/bootstrap.min.css\" integrity=\"sha384-MCw98/SFnGE8fJT3GXwEOngsV7Zt27NXFoaoApmYm81iuXoPkFOJwJ8ERdknLPMO\" crossorigin=\"anonymous\">"
	set tr_bridge "<tr class='table-info'>"
	set out {}
	set functionLights {}
	set varSetter {}
	foreach j $lightsV1(bridgeList) {
		set strBridge $lightsV1($j,bridgeName)
		lappend out "$tr_bridge<td class='text-center'>$j</td><td colspan=\"12\">Bridge $strBridge</td></tr>"
		foreach li [lsort [array names lightsV1  -regexp "$j,\[0-9\]*,name"]] {
			set i [scan [lindex [split $li , ] 1] %d]
			set sc [format "%0${places}d" $i]
			set bri ""
			catch { set bri "$lightsV1($j,$sc,state,bri)"	}
			set effect ""
			catch { set effect "$lightsV1($j,$sc,state,effect)"	}
			set xy ""
			catch { set xy "xy  $lightsV1($j,$sc,state,xy)"	}
			set alert ""
			catch { set alert "$lightsV1($j,$sc,state,alert)"	}
			set sat ""
			catch { set sat "$lightsV1($j,$sc,state,sat)"	}
			set reachable ""
			catch { set reachable "$lightsV1($j,$sc,state,reachable)"	}
			if { $reachable == "false" } {
				set ttr "<tr id='tr${j}_$i' class='table-warning'>"
				set buttontext x
				set buttonprop disabled
				set opacity 0.5
			} elseif {$lightsV1($j,$sc,state,on) == "true" } {
				set buttontext on
				set ttr "<tr id='tr${j}_$i' class='table-light'>"
				set buttonprop ""
				set opacity 1
			} else {
				set ttr "<tr id='tr${j}_$i' class='table-active'>"
				set buttonprop ""
				set buttontext off
				set opacity 0.5
			}
			set ct ""
			if { [info exists lightsV1($j,$sc,state,ct) ] } {
				set ct $lightsV1($j,$sc,state,ct)
			}
			set other ""
			catch { set other "$lightsV1($j,$sc,state,colormode)"	}
			set hue ""
			catch { set hue "$lightsV1($j,$sc,state,hue)"	}
			if { $lightsV1($j,$sc,rgb) != "not available"} {
				set rgb "<button $buttonprop id='b${j}_$i' onClick='toggle(this.id)' class=' btn-sm' role='button' style='width: 35px; border: 1px solid black;background-color:#$lightsV1($j,$sc,rgb);opacity:$opacity'>$buttontext</button>"
				set rgbText $lightsV1($j,$sc,rgb)
			} else {
				set rgb "<button $buttonprop id='b${j}_$i' onClick='toggle(this.id)' class=' btn-sm' role='button' style='width: 35px; border: 1px solid black;background-color:white;opacity:$opacity'>$buttontext</button>"
				set rgbText ""
			}
			lappend out "$ttr<td class='text-center'>$sc</td><td>$lightsV1($j,$sc,name)</td><td>$lightsV1($j,$sc,modelid)</td><td>$rgb</td><td id='rgb${j}_$i' >$rgbText</td><td id='ct${j}_$i' >$ct</td></td><td id='hue${j}_$i'>$hue</td><td id='colormode${j}_$i' >$other</td><td id='bri${j}_$i' >$bri</td><td id='sat${j}_$i' >$sat</td><td id='effect${j}_$i' >$effect</td><td id='reachable${j}_$i' >$reachable</td><td id='alert${j}_$i' >$alert</td></tr>"
		}
		set varSetter "$varSetter\nfunction b$j (method, url){
			return [ajaxV1 lights $j]
		}
		function lights_b$j \(\) {
		var settings = b$j ('GET', 'lights');
		\$.ajax(settings).done(function (response) {
			ret = response;
			let j = $j;
			for (const property in ret) {
				let i = parseInt(property);
				let state = ret\[property\].state;
				var rgb = '';
				var s;
				if (typeof ret\[property\].capabilities.control.colorgamut != \"undefined\") {
					let p2 = ret\[property\].capabilities.control.colorgamut\[0\]\[0\];
					let p3 = ret\[property\].capabilities.control.colorgamut\[0\]\[1\];
					let p4 = ret\[property\].capabilities.control.colorgamut\[1\]\[0\];
					let p5 = ret\[property\].capabilities.control.colorgamut\[1\]\[1\];
					let p6 = ret\[property\].capabilities.control.colorgamut\[2\]\[0\];
					let p7 = ret\[property\].capabilities.control.colorgamut\[2\]\[1\];
					let p0 = state.xy\[0\];
					let p1 = state.xy\[1\];
					rgb = calcRGB(p0,p1,p2,p3,p4,p5,p6,p7);
					iRgb = invertColor(rgb,1);
					s = `bri \${state.bri} effect \${state.effect} alert \${state.alert}`
					s = `\${s} sat \${state.sat} RGB: \${rgb}`
					s = `\${s} ct \${state.ct} hue \${state.hue} colormode \${state.colormode}`
				} else {
					s = `alert \${state.alert}`
				}
				let id = `\${j}_\${i}`;
				let button_id = `#b\${id}`;
				let tr_id = `#tr\${id}`;
				if ( rgb !== '' ) {
					\$(button_id).css(\"background-color\", `#\${rgb}`);
					\$(button_id).css(\"color\", `#\${iRgb}`);
					\$(button_id).css(\"border\", '1px solid black');
					\$(`#rgb\${id}`).html(rgb);
					\$(`#hue\${id}`).html(state.hue);
					\$(`#ct\${id}`).html(state.ct);
					\$(`#colormode\${id}`).html(state.colormode);
					\$(`#bri\${id}`).html(state.bri);
					\$(`#sat\${id}`).html(state.sat);
					\$(`#effect\${id}`).html(state.effect);
					if (state.ct == undefined) {
						state.ct = '';
					}
					\$(`#ct\${id}`).html(state.ct);
				}
				\$(`#reachable\${id}`).html(state.reachable);
				if (state.reachable == false ) {
					\$(button_id).html('x');
					\$(button_id).prop( \"disabled\", true );
					\$(tr_id).removeClass('table-light');
					\$(tr_id).removeClass('table-active');
					\$(tr_id).addClass('table-warning');
					\$(button_id).css(\"opacity\", '1.0');
				} else if (state.on ) {
					\$(button_id).prop( \"disabled\", false );
					\$(button_id).html('on');
					\$(tr_id).removeClass('table-active');
					\$(tr_id).removeClass('table-warning');
					\$(tr_id).addClass('table-light');
					\$(button_id).css(\"opacity\", '1.0');
				} else {
					\$(button_id).prop( \"disabled\", false );
					\$(button_id).css(\"opacity\", '0.5');
					\$(button_id).html('off');
					\$(tr_id).removeClass('table-warning');
					\$(tr_id).addClass('table-active');
					\$(tr_id).removeClass('table-light');
				}
				//console.log(id, state);

			}
		});
	}"
		set functionLights "$functionLights\n	
	lights_b$j\(\);
	// passing argument to setInterval
	setInterval(lights_b$j, 5000);  
"
	}
	puts $fileId "<script src='color.js'></script>
<script src='https://ajax.googleapis.com/ajax/libs/jquery/3.6.0/jquery.min.js'></script>
<script src='https://cdn.jsdelivr.net/npm/popper.js@1.14.3/dist/umd/popper.min.js' integrity='sha384-ZMP7rVo3mIykV+2+9J3UJ46jBk0WLaUAdn689aCwoqbBJiSnjAK/l8WvCWPIPm49' crossorigin='anonymous'></script>
<script src='https://cdn.jsdelivr.net/npm/bootstrap@4.1.3/dist/js/bootstrap.min.js' integrity='sha384-ChfqqxuZUCnJSK3+MXmPNIyE6ZbWh2IMqE241rYiqJxyMiZ6OW/JmZQ5stwEULTy' crossorigin='anonymous'></script>
<script>  var ret;$varSetter
  function doIt() {
  	$functionLights
	}
	function toggle(t) {
		var on = \$('#' + t).text();
		if (on == 'on') {
			on = 'false';
		} else {
			on = 'true';
		}
		const myArray = t.split(\"_\");
		const light = myArray\[1\];
		const bridge = myArray\[0\];
		var settings = this\[bridge\]('PUT', 'lights/' + light + '/state');
		settings.data = \"{\\\"on\\\": \" + on + \" }\";
		// console.log(settings);
		\$.ajax(settings).done(function (response) {window\['lights_' + bridge\]();	});
	}
	function padZero(str, len) {
	    len = len || 2;
	    var zeros = new Array(len).join('0');
	    return (zeros + str).slice(-len);
	}
	function invertColor(hex, bw) {
	    if (hex.indexOf('#') === 0) {
	        hex = hex.slice(1);
	    }
	    // convert 3-digit hex to 6-digits.
	    if (hex.length === 3) {
	        hex = hex\[0\] + hex\[0\] + hex\[1\] + hex\[1\] + hex\[2\] + hex\[2\];
	    }
	    if (hex.length !== 6) {
	        throw new Error('Invalid HEX color.');
	    }
	    var r = parseInt(hex.slice(0, 2), 16),
	        g = parseInt(hex.slice(2, 4), 16),
	        b = parseInt(hex.slice(4, 6), 16);
	    if (bw) {
	        // https://stackoverflow.com/a/3943023/112731
	        return (r * 0.299 + g * 0.587 + b * 0.114) > 186
	            ? '000000'
	            : 'FFFFFF';
	    }
	    // invert color components
	    r = (255 - r).toString(16);
	    g = (255 - g).toString(16);
	    b = (255 - b).toString(16);
	    // pad each with zeros and return
	    return padZero(r) + padZero(g) + padZero(b);
	}
</script>
"
	puts $fileId "</head><body onload=\"doIt();\">"
	puts $fileId "<table  class='table'>"
	puts $fileId "<thead class='thead-dark'><tr><th class='text-left'>ID</th><th class='text-left'>Name</th><th class='text-left'>Model ID</th><th style=\"width: 33px\">Switch</th><th class='text-left'>RGB</th><th class='text-left'>CT</th><th class='text-left'>Hue</th><th class='text-left'>Colormode</th><th class='text-left'>Brilliance</th><th class='text-left'>Saturation</th><th class='text-left'>Effect</th><th class='text-left'>reachable</th><th class='text-left'>Alert</th></tr></thead><tbody>"
	puts $fileId [join  $out "\n"]
	puts $fileId "</tbody></table></body></html>"
	close $fileId
	if {[catch {exec sed -i "" "s/,/, /g" $filename}]} {
		exec sed -i "s/,/, /g" $filename
	}
	if { "$PRODUCT" == "raspmatic_rpi3" } {
		puts "https://192.168.2.30/addons/hue/Lights.html"
	} else {
		exec open $filename
	}
} elseif {"$a" == "l"} { ;# Aufruf nicht durch ccu_read_hue.tcl
	parray lightsV1
}

