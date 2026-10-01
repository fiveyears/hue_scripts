# hue.inc.sensors.tcl (Tcl 8.5)
#
# Hue "sensors" (v1) module.
#
# LOCAL (bridge v1):
#   GET https://<bridge>/api/<username>/sensors
#   GET https://<bridge>/api/<username>/sensors/<id>
#
# REMOTE (Hue cloud proxy "route/api/0"):
#   GET https://api.meethue.com/route/api/0/sensors
#   GET https://api.meethue.com/route/api/0/sensors/<id>
#
# Notes:
# - Remote listing can behave differently depending on account/bridge/permissions.
# - This module caches ONE list PER MODE (local vs remote) to avoid repeated calls.

package require json

namespace eval ::hue::sensors {
    variable cacheTTL 300          ;# seconds (default 5 min)
    variable rows {}               ;# cached rows from listSensors (normalized)
    variable loaded 0
    variable lastLoad 0
    variable cachedMode ""         ;# "local" or "remote" at time of cache fill
}

# -----------------------------
# small helpers
# -----------------------------
proc ::hue::sensors::_mode {} {
    set m [::hue::config get -mode]
    set m [string tolower [string trim $m]]
    if {$m eq ""} { set m "local" }
    return $m
}

proc ::hue::sensors::_redact {s {keep 10}} {
    set s [string trim $s]
    if {$s eq ""} { return "" }
    if {[string length $s] <= $keep} { return "***" }
    return "[string range $s 0 [expr {$keep-1}]]…"
}

proc ::hue::sensors::_norm {s} {
    return [string tolower [string trim $s]]
}

# Case-insensitive glob match
proc ::hue::sensors::_globMatchCI {pattern value} {
    set p [::hue::sensors::_norm $pattern]
    set v [::hue::sensors::_norm $value]
    return [string match $p $v]
}

# -----------------------------
# cache file
# -----------------------------
proc ::hue::sensors::cacheFile {} {
    ::hue::ensureCacheDirExists
    return [file join [::hue::cacheDir] "hue_sensors_cache.tcl"]
}

proc ::hue::sensors::clearCache {} {
    set ::hue::sensors::rows {}
    set ::hue::sensors::loaded 0
    set ::hue::sensors::lastLoad 0
    set ::hue::sensors::cachedMode ""
    set f [::hue::sensors::cacheFile]
    catch { if {[file exists $f]} { file delete -force $f } }
}

proc ::hue::sensors::saveCache {} {
    set f [::hue::sensors::cacheFile]
    set ch [open $f w]
    fconfigure $ch -translation lf
    puts $ch "namespace eval ::hue::sensors {"
    puts $ch "  set loaded 1"
    puts $ch "  set lastLoad [list $::hue::sensors::lastLoad]"
    puts $ch "  set cachedMode [list $::hue::sensors::cachedMode]"
    puts $ch "  set rows [list $::hue::sensors::rows]"
    puts $ch "}"
    close $ch
}

proc ::hue::sensors::loadCache {} {
    set f [::hue::sensors::cacheFile]
    if {![file exists $f]} { return 0 }
    if {[catch {source $f}]} { return 0 }
    if {![info exists ::hue::sensors::rows]} { set ::hue::sensors::rows {} }
    if {![info exists ::hue::sensors::loaded]} { set ::hue::sensors::loaded 0 }
    if {![info exists ::hue::sensors::lastLoad]} { set ::hue::sensors::lastLoad 0 }
    if {![info exists ::hue::sensors::cachedMode]} { set ::hue::sensors::cachedMode "" }
    return [expr {$::hue::sensors::loaded ? 1 : 0}]
}

# -----------------------------
# LOCAL v1 URL builder (explicit)
# This is the critical fix: local sensors MUST be /api/<key>/sensors
# -----------------------------
proc ::hue::sensors::_needLocalBridgeKey {} {
    set bridge [::hue::config get -bridge]
    set key    [::hue::config get -key]
    if {$bridge eq ""} { ::hue::softError "Missing local -bridge (config.hue.tcl)" }
    if {$key eq ""}    { ::hue::softError "Missing local -key (config.hue.tcl)" }
    return [list $bridge $key]
}

proc ::hue::sensors::_localV1Url {path} {
    lassign [::hue::sensors::_needLocalBridgeKey] bridge key
    set p [string trimleft $path "/"]
    return "https://$bridge/api/$key/$p"
}

proc ::hue::sensors::_httpGetLocalV1 {path} {
    set url [::hue::sensors::_localV1Url $path]
    return [exec curl -sS -k $url]
}

# -----------------------------
# HTTP fetch (mode-dispatch)
# -----------------------------
# always accept "/sensors" or "sensors"
proc ::hue::sensors::_normPath {path} {
    set p [string trim $path]
    set p [string trimleft $p "/"]
    return "/$p"
}
proc ::hue::sensors::_httpGetV1 {path} {
    set path [::hue::sensors::_normPath $path]

    if {[::hue::sensors::_mode] eq "remote"} {
        return [::hue::httpGetRemoteV1 $path]
    } else {
        # IMPORTANT: your core httpGetLocal probably expects "/sensors" (or "sensors") consistently.
        # If your core expects WITHOUT "/api/<key>", it must add it. If it already does, this is correct.
        return [::hue::httpGetLocal $path]
    }
}

# -----------------------------
# safe dict helpers
# -----------------------------
proc ::hue::sensors::_dictGetOr {d key default} {
    if {[catch {dict exists $d $key} ok]} { return $default }
    if {!$ok} { return $default }
    if {[catch {dict get $d $key} v]} { return $default }
    return $v
}

proc ::hue::sensors::_dictGetOrPath {d pathList default} {
    if {[catch {dict exists $d {*}$pathList} ok]} { return $default }
    if {!$ok} { return $default }
    if {[catch {dict get $d {*}$pathList} v]} { return $default }
    return $v
}

# -----------------------------
# row builder
# Normalized row:
#   {id name type modelid uniqueid lastupdated reachable battery}
# -----------------------------
proc ::hue::sensors::_sensorRow {id sd} {
    set name     [::hue::sensors::_dictGetOr $sd name ""]
    set type     [::hue::sensors::_dictGetOr $sd type ""]
    set modelid  [::hue::sensors::_dictGetOr $sd modelid ""]
    set uniqueid [::hue::sensors::_dictGetOr $sd uniqueid ""]

    set lastupdated [::hue::sensors::_dictGetOrPath $sd {state lastupdated} ""]
    set reachable   [::hue::sensors::_dictGetOrPath $sd {config reachable} ""]
    set battery     [::hue::sensors::_dictGetOrPath $sd {config battery} ""]

    return [list $id $name $type $modelid $uniqueid $lastupdated $reachable $battery]
}

# -----------------------------
# listSensors
# - caches per-mode (local vs remote)
# - returns normalized rows
# -----------------------------
proc ::hue::sensors::listSensors {{force 0}} {
    if {![info exists ::hue::sensors::loaded]} { set ::hue::sensors::loaded 0 }
    if {![info exists ::hue::sensors::lastLoad]} { set ::hue::sensors::lastLoad 0 }
    if {![info exists ::hue::sensors::cacheTTL]} { set ::hue::sensors::cacheTTL 300 }
    if {![info exists ::hue::sensors::cachedMode]} { set ::hue::sensors::cachedMode "" }
    if {![info exists ::hue::sensors::rows]} { set ::hue::sensors::rows {} }

    set mode [::hue::sensors::_mode]

    # load cache if needed
    if {!$force && !$::hue::sensors::loaded} {
        catch { ::hue::sensors::loadCache }
    }

    # use cache if fresh AND same mode
    if {!$force && $::hue::sensors::loaded && $::hue::sensors::cachedMode eq $mode} {
        set age [expr {[clock seconds] - $::hue::sensors::lastLoad}]
        if {$age < $::hue::sensors::cacheTTL} {
            return $::hue::sensors::rows
        }
    }

    # fetch sensors (v1)
    set body [::hue::sensors::_httpGetV1 "/sensors"]

    if {[catch {json::json2dict $body} data]} {
        ::hue::softError "Sensors list invalid JSON (mode=$mode): $body"
    }

    # v1 sensors response is a dict keyed by sensor id: { "1": {...}, "2": {...}, ... }
    set rows {}
    foreach id [lsort -dictionary [dict keys $data]] {
        set sd [dict get $data $id]
        lappend rows [::hue::sensors::_sensorRow $id $sd]
    }

    set ::hue::sensors::rows $rows
    set ::hue::sensors::loaded 1
    set ::hue::sensors::cachedMode $mode
    set ::hue::sensors::lastLoad [clock seconds]
    catch { ::hue::sensors::saveCache }

    return $rows
}

# -----------------------------
# get helper
# get <pattern> ?which? ?force?
# - prefix match against: id OR name OR uniqueid (case-insensitive)
# - returns:
#   default: id
#   which:
#     all/a*/0 -> full row {id name type modelid uniqueid lastupdated reachable battery}
#     id/i*/1  -> id
#     name/n*/2 -> name
#     type/t*/3 -> type
#     unique/u*/4 -> uniqueid
# -----------------------------
proc ::hue::sensors::get {pattern {which ""} {force 0}} {
    set pat [::hue::sensors::_norm $pattern]
    if {$pat eq ""} { return "" }

    set w [::hue::sensors::_norm $which]
    set wantAll 0
    set wantId 0
    set wantName 0
    set wantType 0
    set wantUnique 0

    if {$w ne ""} {
        if {$w eq "0" || [string match "a*" $w]} {
            set wantAll 1
        } elseif {$w eq "1" || [string match "i*" $w]} {
            set wantId 1
        } elseif {$w eq "2" || [string match "n*" $w]} {
            set wantName 1
        } elseif {$w eq "3" || [string match "t*" $w]} {
            set wantType 1
        } elseif {$w eq "4" || [string match "u*" $w]} {
            set wantUnique 1
        }
    }

    set rows [::hue::sensors::listSensors $force]
    foreach r $rows {
        set id   [lindex $r 0]
        set name [lindex $r 1]
        set uniq [lindex $r 4]

        if {[string match "${pat}*" [::hue::sensors::_norm $id]] ||
            [string match "${pat}*" [::hue::sensors::_norm $name]] ||
            [string match "${pat}*" [::hue::sensors::_norm $uniq]]} {

            if {$wantAll}    { return $r }
            if {$wantId}     { return $id }
            if {$wantName}   { return $name }
            if {$wantType}   { return [lindex $r 2] }
            if {$wantUnique} { return $uniq }
            return $id
        }
    }
    return ""
}

# -----------------------------
# printSensors
# Options:
#   -force
#   -csv <delim>
#   -redact <colspec>   (comma cols, 1-based, e.g. "5" to redact uniqueid)
#   -filtername <glob>  (case-insensitive glob against name)
#   -filtertype <glob>  (case-insensitive glob against type)
#   -hasbattery         (only sensors with battery field non-empty)
#   -reachable <0|1|true|false> (filter reachable)
#
# Output columns (fixed):
#   id name type modelid uniqueid lastupdated reachable battery
# -----------------------------
proc ::hue::sensors::printSensors {args} {
    set force 0
    set delimiter ""
    set redactSpec ""
    set nameGlob ""
    set typeGlob ""
    set hasBattery 0
    set wantReachable ""   ;# "" means no filter, else "0"/"1"/"true"/"false"

    set i 0
    while {$i < [llength $args]} {
        set a [lindex $args $i]
        switch -exact -- $a {
            -force { set force 1 }
            -csv   { incr i; set delimiter [lindex $args $i] }
            -redact { incr i; set redactSpec [lindex $args $i] }
            -filtername { incr i; set nameGlob [lindex $args $i] }
            -filtertype { incr i; set typeGlob [lindex $args $i] }
            -hasbattery { set hasBattery 1 }
            -reachable  { incr i; set wantReachable [lindex $args $i] }
            default {
                ::hue::softError "printSensors: unknown arg '$a'"
            }
        }
        incr i
    }

    set rows [::hue::sensors::listSensors $force]

    # normalize reachable filter
    set wantReachable [::hue::sensors::_norm $wantReachable]
    if {$wantReachable eq "1"} { set wantReachable "true" }
    if {$wantReachable eq "0"} { set wantReachable "false" }

    # filters
    set filtered {}
    foreach r $rows {
        set name      [lindex $r 1]
        set type      [lindex $r 2]
        set reachable [::hue::sensors::_norm [lindex $r 6]]
        set battery   [lindex $r 7]

        if {$nameGlob ne ""} {
            if {![::hue::sensors::_globMatchCI $nameGlob $name]} { continue }
        }
        if {$typeGlob ne ""} {
            if {![::hue::sensors::_globMatchCI $typeGlob $type]} { continue }
        }
        if {$hasBattery} {
            if {[string trim $battery] eq ""} { continue }
        }
        if {$wantReachable ne ""} {
            # Hue sometimes returns true/false (remote), sometimes 1/0 (some firmwares)
            if {$reachable eq "1"} { set reachable "true" }
            if {$reachable eq "0"} { set reachable "false" }
            if {$reachable ne $wantReachable} { continue }
        }

        lappend filtered $r
    }
    set rows $filtered

    set headers [list id name type modelid uniqueid lastupdated reachable battery]
    set cols [llength $headers]

    # redact columns (1-based)
    array set redactCol {}
    if {$redactSpec ne ""} {
        foreach tok [split $redactSpec ","] {
            set tok [string trim $tok]
            if {$tok eq ""} continue
            if {![regexp {^[1-8]$} $tok]} {
                ::hue::softError "printSensors: -redact expects columns 1..8, got '$tok'"
            }
            set redactCol([expr {$tok-1}]) 1
        }
    }

    proc ::hue::sensors::_pp {idx val} {
        if {[info exists ::hue::sensors::redactCol($idx)] && $::hue::sensors::redactCol($idx)} {
            return [::hue::sensors::_redact $val]
        }
        return $val
    }
    catch {unset ::hue::sensors::redactCol}
    array set ::hue::sensors::redactCol [array get redactCol]

    # CSV mode
    if {$delimiter ne ""} {
        puts [join $headers $delimiter]
        foreach r $rows {
            set out {}
            for {set j 0} {$j < $cols} {incr j} {
                lappend out [::hue::sensors::_pp $j [lindex $r $j]]
            }
            puts [join $out $delimiter]
        }
        catch {unset ::hue::sensors::redactCol}
        return
    }

    # formatted mode (dynamic widths)
    set widths {}
    for {set j 0} {$j < $cols} {incr j} {
        lappend widths [string length [lindex $headers $j]]
    }
    foreach r $rows {
        for {set j 0} {$j < $cols} {incr j} {
            set v [::hue::sensors::_pp $j [lindex $r $j]]
            set L [string length $v]
            if {$L > [lindex $widths $j]} { lset widths $j $L }
        }
    }

    set fmt ""
    for {set j 0} {$j < $cols} {incr j} {
        append fmt "%-[lindex $widths $j]s"
        if {$j < ($cols-1)} { append fmt " " }
    }

    set sepLen [expr {$cols - 1}]
    foreach w $widths { incr sepLen $w }

    puts [format $fmt {*}$headers]
    puts [string repeat "-" $sepLen]

    foreach r $rows {
        set out {}
        for {set j 0} {$j < $cols} {incr j} {
            lappend out [::hue::sensors::_pp $j [lindex $r $j]]
        }
        puts [format $fmt {*}$out]
    }

    catch {unset ::hue::sensors::redactCol}
}

namespace eval ::hue::buttons {}

proc ::hue::buttons::handle24 {event} {
    switch -- $event {
        16 { ::hue::log "B1 press" }
        20 { ::hue::log "B1 release" }

        17 { ::hue::log "B2 press" }
        21 { ::hue::log "B2 release" }

        18 { ::hue::log "B3 press" }
        22 { ::hue::log "B3 release" }

        19 { ::hue::log "B4 press" }
        23 { ::hue::log "B4 release" }

        default { ::hue::log "Unhandled event=$event" }
    }
}

proc ::hue::buttons::watch {sensorId {intervalMs 200}} {
    set last ""
    while {1} {
        set body [::hue::sensors::_httpGetV1 "/sensors/$sensorId"]
        if {[catch {json::json2dict $body} sd]} { after $intervalMs; continue }

        # safe nested dict get (you can implement _dictGetOrPath like below)
        set ev [::hue::sensors::_dictGetOrPath $sd {state buttonevent} ""]
        set ts [::hue::sensors::_dictGetOrPath $sd {state lastupdated} ""]
        if {$ev ne "" && "$ev|$ts" ne $last} {
            set last "$ev|$ts"
            ::hue::buttons::handle24 $ev
        }
        after $intervalMs
    }
}
proc ::hue::sensors::watchButton {id {intervalMs 150}} {
    puts "Watching sensor $id (CTRL-C to stop)..."
    set lastUpd ""

    while {1} {
        # fetch single sensor
        set body [::hue::httpGetRemoteV1 "/sensors/$id"]
        set sd   [json::json2dict $body]

        set upd ""
        set ev  ""

        if {[dict exists $sd state lastupdated]} {
            set upd [dict get $sd state lastupdated]
        }
        if {[dict exists $sd state buttonevent]} {
            set ev [dict get $sd state buttonevent]
        }

        # Only print on change
        if {$upd ne "" && $upd ne $lastUpd} {
            puts "buttonevent=$ev  lastupdated=$upd"
            set lastUpd $upd
        }

        after $intervalMs
    }
}
proc ::hue::sensors::watchButtonRaw {id {intervalMs 80}} {
    puts "Watching sensor $id (CTRL-C to stop)..."
    set lastEv ""
    set lastUpd ""

    while {1} {
        set body [::hue::httpGetRemoteV1 "/sensors/$id"]
        set sd   [json::json2dict $body]

        set ev  ""
        set upd ""
        if {[dict exists $sd state buttonevent]}   { set ev  [dict get $sd state buttonevent] }
        if {[dict exists $sd state lastupdated]}   { set upd [dict get $sd state lastupdated] }

        # print if either changed
        if {$ev ne $lastEv || $upd ne $lastUpd} {
            puts "buttonevent=$ev  lastupdated=$upd"
            set lastEv $ev
            set lastUpd $upd
        }

        after $intervalMs
    }
}

# -----------------------------
# help
# -----------------------------
proc ::hue::sensors::help {} {
    puts "Hue Sensors (v1) - ::hue::sensors::*"
    puts ""
    puts "List (cached per mode):"
    puts "  ::hue::sensors::listSensors ?force?"
    puts "    force: 0/1 (1 rebuilds now; ignores cache)"
    puts ""
    puts "Print:"
    puts "  ::hue::sensors::printSensors ?options...?"
    puts ""
    puts "Options:"
    puts "  -force"
    puts "  -csv <delim>           Delimited output"
    puts "  -redact <cols>         Comma-separated 1..8 (e.g. \"5\" to redact uniqueid)"
    puts "  -filtername <glob>     Case-insensitive glob match on name (e.g. \"hue*\")"
    puts "  -filtertype <glob>     Case-insensitive glob match on type (e.g. \"ZLL*\")"
    puts "  -hasbattery            Only sensors with battery field"
    puts "  -reachable <0|1|true|false>  Only those with reachable matching"
    puts ""
    puts "Get (prefix match, first hit, returns \"\" on no match):"
    puts "  ::hue::sensors::get <pattern> ?which? ?force?"
    puts "    default: returns id"
    puts "    which:"
    puts "      all / a* / 0    -> full row"
    puts "      id  / i* / 1    -> id"
    puts "      name/ n* / 2    -> name"
    puts "      type/ t* / 3    -> type"
    puts "      unique/u* / 4   -> uniqueid"
    puts ""
    puts "Cache:"
    puts "  ::hue::sensors::clearCache"
}