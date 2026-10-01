package require json

namespace eval ::hue::foh {
    variable pollMs 80
    variable longThresholdMs 700

    # press timestamp per (sensorId, logicalButton)
    variable pressTs
    array set pressTs {}

    # de-dupe + startup baseline per sensorId
    variable lastSeenLu
    variable lastSeenBe
    variable primed
    array set lastSeenLu {}
    array set lastSeenBe {}
    array set primed {}
}

proc ::hue::foh::setPollMs {ms} {
    set ::hue::foh::pollMs [expr {int($ms)}]
}

proc ::hue::foh::setLongThresholdMs {ms} {
    set ::hue::foh::longThresholdMs [expr {int($ms)}]
}

# mode-dispatching GET /sensors/<id>
proc ::hue::foh::_httpGetSensor {id} {
    set mode [string tolower [string trim [::hue::config get -mode]]]
    if {$mode eq ""} { set mode "local" }

    if {$mode eq "remote"} {
        if {[info command ::hue::httpGetRemoteV1] eq ""} {
            ::hue::softError "Missing ::hue::httpGetRemoteV1 in core."
        }
        return [::hue::httpGetRemoteV1 "/sensors/$id"]
    } else {
        if {[info command ::hue::httpGetLocal] eq ""} {
            ::hue::softError "Missing ::hue::httpGetLocal in core."
        }
        return [::hue::httpGetLocal "/sensors/$id"]
    }
}

# Map single-button buttonevent codes -> logical button + phase
proc ::hue::foh::_decodeSingle {be} {
    switch -exact -- $be {
        16 { return [list topleft     press] }
        17 { return [list bottomleft  press] }
        18 { return [list bottomright press] }
        19 { return [list topright    press] }
        20 { return [list topleft     release] }
        21 { return [list bottomleft  release] }
        22 { return [list bottomright release] }
        23 { return [list topright    release] }
        default { return {} }
    }
}

# Pair events:
# - bottom pair: 98 press, 99 release
# - top pair:    100 press, 101 release
proc ::hue::foh::_decodePair {be} {
    switch -exact -- $be {
        98  { return [list bottom_pair press] }
        99  { return [list bottom_pair release] }
        100 { return [list top_pair    press] }
        101 { return [list top_pair    release] }
        default { return {} }
    }
}

proc ::hue::foh::watch {sensorIds} {
    if {[llength $sensorIds] == 0} {
        ::hue::softError "Usage: ::hue::foh::watch {24 33 ...}"
    }

    puts "Watching FoH sensors: [join $sensorIds {, }]"
    puts "Polling every $::hue::foh::pollMs ms; longThreshold=$::hue::foh::longThresholdMs ms (CTRL-C to stop)"
    flush stdout

    while {1} {
        foreach sid $sensorIds {
            # Fetch sensor JSON
            set body [::hue::foh::_httpGetSensor $sid]
            if {[catch {json::json2dict $body} sd]} {
                # don’t die on transient junk; just skip
                ::hue::log "foh: sensor $sid invalid JSON: [string range $body 0 120]..."
                continue
            }

            # Extract buttonevent + lastupdated (safe-ish)
            set be ""
            set lu ""
            if {[dict exists $sd state buttonevent]}  { set be [dict get $sd state buttonevent] }
            if {[dict exists $sd state lastupdated]}  { set lu [dict get $sd state lastupdated] }

            if {$be eq "" || $lu eq ""} {
                continue
            }

            # Startup priming: ignore the first seen event per sensor,
            # because bridges often report the last stored buttonevent immediately.
            if {![info exists ::hue::foh::primed($sid)] || !$::hue::foh::primed($sid)} {
                set ::hue::foh::primed($sid) 1
                set ::hue::foh::lastSeenLu($sid) $lu
                set ::hue::foh::lastSeenBe($sid) $be
                continue
            }

            # De-dupe: ignore exact repeats (same lastupdated + buttonevent)
            if {[info exists ::hue::foh::lastSeenLu($sid)] &&
                [info exists ::hue::foh::lastSeenBe($sid)] &&
                $::hue::foh::lastSeenLu($sid) eq $lu &&
                $::hue::foh::lastSeenBe($sid) eq $be} {
                continue
            }
            set ::hue::foh::lastSeenLu($sid) $lu
            set ::hue::foh::lastSeenBe($sid) $be

            # Decode as single or pair
            set single [::hue::foh::_decodeSingle $be]
            set pair   [::hue::foh::_decodePair $be]

            set now [clock milliseconds]

            if {[llength $single] == 2} {
                lassign $single btn phase
                set key "$sid,$btn"

                if {$phase eq "press"} {
                    set ::hue::foh::pressTs($key) $now
                    puts "FoH $sid $btn PRESS be=$be lu=$lu"
                    flush stdout
                    continue
                }

                # RELEASE handling (includes your “press missed” fallback)
                if {![info exists ::hue::foh::pressTs($key)]} {
                    puts "FoH $sid $btn SHORT (press missed) be=$be lu=$lu"
                    flush stdout
                    continue
                }

                set start $::hue::foh::pressTs($key)
                unset ::hue::foh::pressTs($key)
                set dur [expr {$now - $start}]

                if {$dur >= $::hue::foh::longThresholdMs} {
                    puts "FoH $sid $btn LONG ${dur}ms be=$be lu=$lu"
                } else {
                    puts "FoH $sid $btn SHORT ${dur}ms be=$be lu=$lu"
                }
                flush stdout
                continue
            }

            if {[llength $pair] == 2} {
                lassign $pair btn phase
                set key "$sid,$btn"

                if {$phase eq "press"} {
                    set ::hue::foh::pressTs($key) $now
                    puts "FoH $sid $btn PRESS be=$be lu=$lu"
                    flush stdout
                    continue
                }

                # Pair RELEASE handling + “press missed” fallback
                if {![info exists ::hue::foh::pressTs($key)]} {
                    puts "FoH $sid $btn SHORT (press missed) be=$be lu=$lu"
                    flush stdout
                    continue
                }

                set start $::hue::foh::pressTs($key)
                unset ::hue::foh::pressTs($key)
                set dur [expr {$now - $start}]

                if {$dur >= $::hue::foh::longThresholdMs} {
                    puts "FoH $sid $btn LONG ${dur}ms be=$be lu=$lu"
                } else {
                    puts "FoH $sid $btn SHORT ${dur}ms be=$be lu=$lu"
                }
                flush stdout
                continue
            }

            # Unknown/other event codes (e.g. 104)
            puts "FoH $sid OTHER be=$be lu=$lu"
            flush stdout
        }

        after $::hue::foh::pollMs
    }
}
proc ::hue::foh::_looksLikeHtml {s} {
    set t [string tolower [string trim $s]]
    expr {[string first "<!doctype" $t] == 0 || [string first "<html" $t] == 0 || [string first "-//w3c//dtd html" $t] == 0}
}

proc ::hue::foh::_getLocalV1Raw {path} {
    set bridge [::hue::config get -bridge]
    set key    [::hue::config get -key]
    if {$bridge eq ""} { ::hue::softError "local v1: missing -bridge" }
    if {$key eq ""}    { ::hue::softError "local v1: missing -key (username)" }

    if {[string index $path 0] ne "/"} { set path "/$path" }
    set url "https://$bridge/api/$key$path"
    set body [exec curl -sS -k $url]

    if {[::hue::foh::_looksLikeHtml $body]} {
        ::hue::softError "local v1: got HTML instead of JSON. URL=$url (check -bridge/-key)."
    }
    return $body
}

proc ::hue::foh::_getV1Raw {path} {
    set mode [string tolower [string trim [::hue::config get -mode]]]
    if {$mode eq ""} { set mode "local" }

    if {$mode eq "remote"} {
        if {[info command ::hue::httpGetRemoteV1] eq ""} {
            ::hue::softError "Missing ::hue::httpGetRemoteV1 in core."
        }
        set body [::hue::httpGetRemoteV1 $path]
        if {[::hue::foh::_looksLikeHtml $body]} {
            ::hue::softError "remote v1: got HTML instead of JSON (unexpected)."
        }
        return $body
    }

    return [::hue::foh::_getLocalV1Raw $path]
}

proc ::hue::foh::_getV1Json {path} {
    set body [::hue::foh::_getV1Raw $path]
    # empty response -> json::json2dict throws "END"
    if {[string trim $body] eq ""} {
        ::hue::softError "v1 GET $path returned empty body (mode=[::hue::config get -mode])."
    }

    if {[catch {json::json2dict $body} d]} {
        ::hue::softError "v1 JSON parse failed for $path. First bytes: [string range $body 0 120]"
    }
    return $d
}

proc ::hue::foh::dumpRulesForSensor {sid} {
    set sid [string trim $sid]
    if {$sid eq ""} { return {} }

    set rules [::hue::foh::_getV1Json "/rules"]

    # /rules is dict: ruleId -> ruleDict
    set out {}
    foreach rid [lsort -dictionary [dict keys $rules]] {
        set r [dict get $rules $rid]
        if {![catch {dict exists $r conditions} ok] && $ok} {
            set conds [dict get $r conditions]
        } else {
            set conds {}
        }

        set hit 0
        foreach c $conds {
            # condition is dict with "address" usually like "/sensors/24/state/..."
            if {[catch {dict get $c address} addr]} { continue }
            if {[string match "*/sensors/$sid/*" $addr] || [string match "/sensors/$sid/*" $addr]} {
                set hit 1
                break
            }
        }

        if {$hit} {
            lappend out [list $rid $r]
        }
    }
    return $out
}

proc ::hue::foh::dumpSchedules {} {
    return [::hue::foh::_getV1Json "/schedules"]
}

proc ::hue::foh::dumpResourcelinks {} {
    return [::hue::foh::_getV1Json "/resourcelinks"]
}

proc ::hue::foh::dumpRules {} {
    return [::hue::foh::_getV1Json "/rules"]
}

namespace eval ::hue::foh {}

# --- internal: pick local vs remote v1 GET ---
proc ::hue::foh::_looksLikeHtml {s} {
    set t [string tolower [string trim $s]]
    return [expr {[string first "<!doctype" $t] == 0 || [string first "<html" $t] == 0}]
}

proc ::hue::foh::_getLocalV1Raw {path} {
    set bridge [::hue::config get -bridge]
    set key    [::hue::config get -key]
    if {$bridge eq ""} { ::hue::softError "dumpAll(local): missing -bridge" }
    if {$key eq ""}    { ::hue::softError "dumpAll(local): missing -key (username)" }

    # path must start with /
    if {[string index $path 0] ne "/"} { set path "/$path" }

    set url "https://$bridge/api/$key$path"
    set body [exec curl -sS -k $url]

    if {[::hue::foh::_looksLikeHtml $body]} {
        ::hue::softError "dumpAll(local): got HTML instead of JSON. URL was $url (check -bridge/-key)."
    }
    return $body
}

proc ::hue::foh::_getV1 {path} {
    set mode [string tolower [string trim [::hue::config get -mode]]]
    if {$mode eq ""} { set mode "local" }

    if {$mode eq "remote"} {
        if {[info command ::hue::httpGetRemoteV1] eq ""} {
            ::hue::softError "Missing ::hue::httpGetRemoteV1 in core."
        }
        set body [::hue::httpGetRemoteV1 $path]
        if {[::hue::foh::_looksLikeHtml $body]} {
            ::hue::softError "dumpAll(remote): got HTML instead of JSON (unexpected). Raw begins with: [string range $body 0 80]"
        }
        return $body
    }

    # Local: bypass core, use v1 direct
    return [::hue::foh::_getLocalV1Raw $path]
}
# --- internal: JSON -> dict with helpful error ---
proc ::hue::foh::_json2dict {label body} {
    if {[catch {json::json2dict $body} d]} {
        ::hue::softError "$label: invalid JSON. Raw:\n$body"
    }
    return $d
}

# --- internal: stable “id ordering” for v1 dict-of-dicts endpoints ---
# Returns a list of {id dict} pairs, sorted by id dictionary-wise.
proc ::hue::foh::_sortedPairs {d} {
    set out {}
    foreach id [lsort -dictionary [dict keys $d]] {
        lappend out [list $id [dict get $d $id]]
    }
    return $out
}

# --- main: dump everything we need for diff ---
# Usage:
#   set snap [::hue::foh::dumpAll]
#   ::hue::foh::dumpAll -file /tmp/before.tcl
#
# Options:
#   -file <path>   write snapshot to disk (Tcl sourceable)
#   -tag  <name>   label inside snapshot (e.g. "before", "after")
proc ::hue::foh::dumpAll {args} {
    set file ""
    set tag ""

    set i 0
    while {$i < [llength $args]} {
        set a [lindex $args $i]
        switch -exact -- $a {
            -file { incr i; set file [lindex $args $i] }
            -tag  { incr i; set tag  [lindex $args $i] }
            default { ::hue::softError "dumpAll: unknown arg '$a' (use -file, -tag)" }
        }
        incr i
    }

    set mode [string tolower [string trim [::hue::config get -mode]]]
    if {$mode eq ""} { set mode "local" }

    # Fetch raw JSON
    set cfgJ   [::hue::foh::_getV1 "/config"]
    set sensJ  [::hue::foh::_getV1 "/sensors"]
    set rulesJ [::hue::foh::_getV1 "/rules"]
    set schJ   [::hue::foh::_getV1 "/schedules"]
    set rlJ    [::hue::foh::_getV1 "/resourcelinks"]
    set scenesJ    [::hue::foh::_getV1 "/scenes"]
    set grpJ   [::hue::foh::_getV1 "/groups"]

    # Parse
    set cfg   [::hue::foh::_json2dict "config" $cfgJ]
    set sens  [::hue::foh::_json2dict "sensors" $sensJ]
    set rules [::hue::foh::_json2dict "rules" $rulesJ]
    set sch   [::hue::foh::_json2dict "schedules" $schJ]
    set rl    [::hue::foh::_json2dict "resourcelinks" $rlJ]
    set scenes    [::hue::foh::_json2dict "scenes" $scenesJ]
    set grp   [::hue::foh::_json2dict "groups" $grpJ]

    # Normalize to stable, diff-friendly ordering for big endpoints
    set snap [dict create \
        meta [dict create \
            tag $tag \
            mode $mode \
            time_iso [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S}] \
        ] \
        config $cfg \
        sensors [::hue::foh::_sortedPairs $sens] \
        rules   [::hue::foh::_sortedPairs $rules] \
        schedules [::hue::foh::_sortedPairs $sch] \
        resourcelinks [::hue::foh::_sortedPairs $rl] \
        scenes [::hue::foh::_sortedPairs $scenes] \
        groups [::hue::foh::_sortedPairs $grp] \
    ]

    if {$file ne ""} {
        set ch [open $file w]
        fconfigure $ch -translation lf
        puts $ch "# Hue snapshot created by ::hue::foh::dumpAll"
        puts $ch "return [list $snap]"
        close $ch
    }

    return $snap
}

