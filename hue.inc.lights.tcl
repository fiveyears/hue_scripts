# hue.inc.lights.tcl  (Tcl 8.5)
#
# Hue v2 lights under ::hue::lights
# - caches name/index/id mappings in .resources next to hue.inc.core.tcl
# - TTL 30 days
# - fuzzy + case-insensitive lookups with interactive disambiguation
#
# Requires:
#   - hue.inc.core.tcl (for ::hue::config, ::hue::softError, ::hue::chooseOne, ::hue::log,
#                      ::hue::httpGet, ::hue::httpPutJson, ::hue::apiUrl/curlAuthArgs)
#   - package json

package require json

namespace eval ::hue::lights {
    variable nameByIndex;  array set nameByIndex  {}
    variable idByIndex;    array set idByIndex    {}
    variable indexById;    array set indexById    {}
    variable nameById;     array set nameById     {}
    variable idByName;     array set idByName     {}
    variable indexByName;  array set indexByName  {}

    variable loaded 0
    variable lastLoad 0
    variable cacheTTL 2592000
}

# ----------------------------------------------------------------------
# Cache
# ----------------------------------------------------------------------
proc ::hue::lights::cacheFile {} {
    ::hue::ensureCacheDirExists
    return [file join [::hue::cacheDir] "hue_lights_cache.tcl"]
}

proc ::hue::lights::clear {} {
    foreach a {nameByIndex idByIndex indexById nameById idByName indexByName} {
        catch {unset ::hue::lights::$a}
        array set ::hue::lights::$a {}
    }
    set ::hue::lights::loaded 0
    set ::hue::lights::lastLoad 0
}

proc ::hue::lights::saveCache {} {
    set f [::hue::lights::cacheFile]
    set ch [open $f w]
    fconfigure $ch -translation lf
    puts $ch "namespace eval ::hue::lights {"
    puts $ch "  set loaded 1"
    puts $ch "  set lastLoad [::list $::hue::lights::lastLoad]"
    foreach a {nameByIndex idByIndex indexById nameById idByName indexByName} {
        puts $ch "  catch {unset $a}; array set $a [::list [array get ::hue::lights::$a]]"
    }
    puts $ch "}"
    close $ch
}

proc ::hue::lights::loadCache {} {
    set f [::hue::lights::cacheFile]
    if {![file exists $f]} { return 0 }
    if {[catch {source $f}]} { return 0 }

    foreach a {nameByIndex idByIndex indexById nameById idByName indexByName} {
        if {![info exists ::hue::lights::$a]} { array set ::hue::lights::$a {} }
    }
    return [expr {$::hue::lights::loaded ? 1 : 0}]
}

# helper
proc ::hue::lights::_nullToEmpty {v} {
    if {[string tolower [string trim $v]] eq "null"} {
        return ""
    }
    return $v
}

# Local-only guard for v1 endpoints
proc ::hue::lights::_requireLocalForV1 {} {
    set m [::hue::config get -mode]
    if {$m eq ""} { set m "local" }
    if {$m ne "local"} {
        ::hue::softError "Hue v1 endpoints are local-bridge only; not available in remote mode."
    }
}

# ----------------------------------------------------------------------
# Fetch all lights (v2)
# Works in BOTH modes because it uses ::hue::httpGet
# ----------------------------------------------------------------------
proc ::hue::lights::loadAll {} {
    ::hue::lights::clear

    set body [::hue::httpGet "/clip/v2/resource/light"]
    set resp [json::json2dict $body]

    if {![dict exists $resp data]} {
        ::hue::softError "Invalid Hue v2 response (no data)"
    }
    foreach l [dict get $resp data] {
        if {[catch {dict exists $l id} ok] || !$ok} { continue }
        set id [dict get $l id]

        set name ""
        if {![catch {dict exists $l metadata name} ok] && $ok} {
            set name [dict get $l metadata name]
        }

        # best-effort v1 index
        set idx ""
        if {![catch {dict exists $l id_v1} ok] && $ok} {
            set id_v1 [dict get $l id_v1]
            if {[string match "*/lights/*" $id_v1] || [string match "/lights/*" $id_v1]} {
                set idx [lindex [split $id_v1 "/"] end]
            }
        }

        # Always fill ID->name
        set ::hue::lights::nameById($id) $name
        # Name->ID (store list; handle duplicates)
        if {$name ne ""} {
            if {[info exists ::hue::lights::idByName($name)]} {
                if {[lsearch -exact $::hue::lights::idByName($name) $id] < 0} {
                    lappend ::hue::lights::idByName($name) $id
                }
            } else {
                set ::hue::lights::idByName($name) [::list $id]
            }
        }

        # Index maps only when idx known
        if {$idx ne ""} {
            set ::hue::lights::nameByIndex($idx) $name
            set ::hue::lights::idByIndex($idx)   $id
            set ::hue::lights::indexById($id)    $idx

            # Name->Index (store list; handle duplicates)
            if {$name ne ""} {
                if {[info exists ::hue::lights::indexByName($name)]} {
                    if {[lsearch -exact $::hue::lights::indexByName($name) $idx] < 0} {
                        lappend ::hue::lights::indexByName($name) $idx
                    }
                } else {
                    set ::hue::lights::indexByName($name) [::list $idx]
                }
            }
        }
    }

    set ::hue::lights::loaded 1
    set ::hue::lights::lastLoad [clock seconds]
    ::hue::lights::saveCache
}

# ----------------------------------------------------------------------
# ensureLoaded(force)
# ----------------------------------------------------------------------
proc ::hue::lights::ensureLoaded {{force 0}} {
    if {!$::hue::lights::loaded} {
        ::hue::lights::loadCache
    }
    if {$force} {
        ::hue::log "lights: reset -> refreshing from bridge"
        ::hue::lights::loadAll
        return
    }

    if {$::hue::lights::loaded} {
        set age [expr {[clock seconds] - $::hue::lights::lastLoad}]
        if {$age < $::hue::lights::cacheTTL} {
            ::hue::log "lights: using cache (age=${age}s)"
            return
        }
        ::hue::log "lights: cache expired (age=${age}s) -> refreshing"
    } else {
        ::hue::log "lights: no cache -> refreshing"
    }

    ::hue::lights::loadAll
}

# ----------------------------------------------------------------------
# Fuzzy resolver (case-insensitive), prefix-first then substring.
# Uses ::hue::chooseOne if multiple matches.
# ----------------------------------------------------------------------
proc ::hue::lights::_resolveKeyFuzzy {arrName wanted label} {
    ::hue::lights::ensureLoaded 0

    # exact case-sensitive
    if {[info exists ::hue::lights::${arrName}($wanted)]} {
        return $wanted
    }

    set w [string tolower [string trim $wanted]]

    # exact case-insensitive
    foreach k [array names ::hue::lights::$arrName] {
        if {[string tolower [string trim $k]] eq $w} {
            return $k
        }
    }

    # prefix match (case-insensitive)
    set prefixMatches {}
    foreach k [array names ::hue::lights::$arrName] {
        set kk [string tolower [string trim $k]]
        if {[string first $w $kk] == 0} {
            lappend prefixMatches $k
        }
    }
    if {[llength $prefixMatches] == 1} {
        return [lindex $prefixMatches 0]
    }
    if {[llength $prefixMatches] > 1} {
        set prefixMatches [lsort $prefixMatches]
        return [::hue::chooseOne "Multiple matches for $label '$wanted' (prefix):" $prefixMatches]
    }

    # substring match (case-insensitive)
    set matches {}
    foreach k [array names ::hue::lights::$arrName] {
        set kk [string tolower [string trim $k]]
        if {[string first $w $kk] >= 0} {
            lappend matches $k
        }
    }

    if {[llength $matches] == 0} {
        ::hue::softError "Unknown $label: $wanted"
    }
    if {[llength $matches] == 1} {
        return [lindex $matches 0]
    }

    set matches [lsort $matches]
    return [::hue::chooseOne "Multiple matches for $label '$wanted':" $matches]
}

# ----------------------------------------------------------------------
# Listing
# ----------------------------------------------------------------------
proc ::hue::lights::list {{what all}} {
    ::hue::lights::ensureLoaded 0

    set out {}
    switch -- $what {
        names {
            return [lsort [array names ::hue::lights::idByName]]
        }
        indices {
            return [lsort -integer [array names ::hue::lights::nameByIndex]]
        }
        ids {
            return [lsort [array names ::hue::lights::nameById]]
        }
        all {
            foreach idx [lsort -integer [array names ::hue::lights::nameByIndex]] {
                lappend out [::list \
                    $idx \
                    $::hue::lights::nameByIndex($idx) \
                    $::hue::lights::idByIndex($idx)]
            }
            return $out
        }
        default {
            ::hue::softError "Usage: ::hue::lights::list ?names|indices|ids|all?"
        }
    }
}

# ----------------------------------------------------------------------
# Getters (fuzzy + case-insensitive for name/id lookups)
# ----------------------------------------------------------------------
proc ::hue::lights::getIndexByName {name} {
    ::hue::lights::ensureLoaded 0

    # If we don't have indexByName at all (remote mode often), fail clearly
    if {[array size ::hue::lights::indexByName] == 0} {
        set m [::hue::config get -mode]
        if {$m eq ""} { set m "local" }
        ::hue::softError "Light v1 indices are not available (mode=$m, no id_v1 mappings). Use v2 ids/names instead."
    }

    set k [::hue::lights::_resolveKeyFuzzy indexByName $name "light name"]
    set idxs $::hue::lights::indexByName($k)

    if {[llength $idxs] == 1} { return [lindex $idxs 0] }

    set opts {}
    foreach idx [lsort -integer $idxs] {
        set id ""
        if {[info exists ::hue::lights::idByIndex($idx)]} { set id $::hue::lights::idByIndex($idx) }
        lappend opts [format "%s (index=%s, id=%s)" $k $idx $id]
    }
    set chosen [::hue::chooseOne "Multiple lights named '$k' (v1 index):" $opts]
    regexp {index=([0-9]+)} $chosen -> chosenIdx
    return $chosenIdx
}

proc ::hue::lights::getIDByName {name} {
    ::hue::lights::ensureLoaded 0

    # fuzzy over the *keys* (names)
    set k [::hue::lights::_resolveKeyFuzzy idByName $name "light name"]
    set ids $::hue::lights::idByName($k)

    if {[llength $ids] == 1} { return [lindex $ids 0] }

    # build menu labels: "Name (id=...)"
    set opts {}
    foreach id [lsort $ids] {
        lappend opts [format "%s (id=%s)" $k $id]
    }
    set chosen [::hue::chooseOne "Multiple lights named '$k':" $opts]
    regexp {id=(.+)\)$} $chosen -> chosenId
    return $chosenId
}

proc ::hue::lights::getNameByID {id} {
    set k [::hue::lights::_resolveKeyFuzzy nameById $id "light id"]
    return $::hue::lights::nameById($k)
}

proc ::hue::lights::getIndexByID {id} {
    set k [::hue::lights::_resolveKeyFuzzy indexById $id "light id"]
    return $::hue::lights::indexById($k)
}

proc ::hue::lights::getNameByIndex {index} {
    if {!$::hue::lights::loaded} { ::hue::lights::loadCache }
    if {![info exists ::hue::lights::nameByIndex($index)]} {
        ::hue::softError "Unknown light index: $index"
    }
    return $::hue::lights::nameByIndex($index)
}

proc ::hue::lights::getIDByIndex {index} {
    if {!$::hue::lights::loaded} { ::hue::lights::loadCache }
    if {![info exists ::hue::lights::idByIndex($index)]} {
        ::hue::softError "Unknown light index: $index"
    }
    return $::hue::lights::idByIndex($index)
}

# ----------------------------------------------------------------------
# GET light attributes + state (v2)
# ----------------------------------------------------------------------
proc ::hue::lights::_v2Get {path} {
    # Works in local + remote (core decides headers/host)
    set body [::hue::httpGet $path]
    return [json::json2dict $body]
}

proc ::hue::lights::getLightByID {id} {
    set resp [::hue::lights::_v2Get "/clip/v2/resource/light/$id"]
    if {![dict exists $resp data]} {
        ::hue::softError "Invalid Hue v2 response (no data)"
    }
    set data [dict get $resp data]
    if {[llength $data] < 1} {
        ::hue::softError "Light not found: $id"
    }
    return [lindex $data 0]
}

proc ::hue::lights::getLightByIndex {index} {
    if {!$::hue::lights::loaded} { ::hue::lights::loadCache }
    set id [::hue::lights::getIDByIndex $index]
    return [::hue::lights::getLightByID $id]
}

proc ::hue::lights::getLightByName {name} {
    if {!$::hue::lights::loaded} { ::hue::lights::loadCache }
    set id [::hue::lights::getIDByName $name]
    return [::hue::lights::getLightByID $id]
}

# State-ish subset from the v2 light object
proc ::hue::lights::getStateByID {id} {
    set l [::hue::lights::getLightByID $id]
    set out {}
    foreach k {on dimming color color_temperature gradient dynamics effects effects_v2 alert signaling} {
        if {[dict exists $l $k]} {
            dict set out $k [dict get $l $k]
        }
    }
    return $out
}

proc ::hue::lights::getStateByIndex {index} {
    set id [::hue::lights::getIDByIndex $index]
    return [::hue::lights::getStateByID $id]
}

proc ::hue::lights::getStateByName {name} {
    set id [::hue::lights::getIDByName $name]
    return [::hue::lights::getStateByID $id]
}

# ----------------------------------------------------------------------
# Dict -> array helpers
# ----------------------------------------------------------------------
proc ::hue::lights::_lightDictToArray {lightDict arrName} {
    upvar 1 $arrName A

    catch {unset A}
    array set A {}

    # Defaults
    set A(x)  ""
    set A(y)  ""
    set A(ct) ""

    set A(name) ""
    set A(archetype) ""
    set A(function) ""
    set A(id) ""
    set A(index) ""

    set A(type) ""
    set A(mode) ""
    set A(on) ""
    set A(brightness) ""
    set A(effect) ""
    set A(alert) ""
    set A(transitiontime) ""

    set A(alert_values) ""
    set A(effect_values) ""
    set A(timed_effect_values) ""

    set A(metadata_raw) ""
    set A(alert_raw) ""
    set A(effects_raw) ""
    set A(effects_v2_raw) ""

    if {[dict exists $lightDict id]} {
        set A(id) [dict get $lightDict id]
    }
    if {[dict exists $lightDict id_v1]} {
        set A(index) [lindex [split [dict get $lightDict id_v1] "/"] end]
    }

    if {[dict exists $lightDict type]} { set A(type) [dict get $lightDict type] }
    if {[dict exists $lightDict mode]} { set A(mode) [dict get $lightDict mode] }

    if {[dict exists $lightDict metadata]} { set A(metadata_raw) [dict get $lightDict metadata] }
    if {[dict exists $lightDict metadata name]} { set A(name) [dict get $lightDict metadata name] }
    if {[dict exists $lightDict metadata archetype]} { set A(archetype) [dict get $lightDict metadata archetype] }
    if {[dict exists $lightDict metadata function]} { set A(function) [dict get $lightDict metadata function] }

    if {[dict exists $lightDict on on]} {
        set A(on) [dict get $lightDict on on]
    }

    if {[dict exists $lightDict dimming brightness]} {
        set A(brightness) [::hue::lights::_nullToEmpty [dict get $lightDict dimming brightness]]
    }

    if {[dict exists $lightDict color xy x]} {
        set A(x) [::hue::lights::_nullToEmpty [dict get $lightDict color xy x]]
    }
    if {[dict exists $lightDict color xy y]} {
        set A(y) [::hue::lights::_nullToEmpty [dict get $lightDict color xy y]]
    }

    if {[dict exists $lightDict color_temperature mirek]} {
        set A(ct) [::hue::lights::_nullToEmpty [dict get $lightDict color_temperature mirek]]
    }

    if {[dict exists $lightDict dynamics duration]} {
        set A(transitiontime) [expr {[dict get $lightDict dynamics duration] / 1000.0}]
    }

    if {[dict exists $lightDict alert]} { set A(alert_raw) [dict get $lightDict alert] }
    if {[dict exists $lightDict alert action]} { set A(alert) [dict get $lightDict alert action] }
    if {[dict exists $lightDict alert action_values]} { set A(alert_values) [dict get $lightDict alert action_values] }

    if {[dict exists $lightDict effects_v2]} { set A(effects_v2_raw) [dict get $lightDict effects_v2] }
    if {[dict exists $lightDict effects]}    { set A(effects_raw)    [dict get $lightDict effects] }

    if {[dict exists $lightDict effects_v2 status effect]} {
        set A(effect) [dict get $lightDict effects_v2 status effect]
    } elseif {[dict exists $lightDict effects status]} {
        set A(effect) [dict get $lightDict effects status]
    }

    if {[dict exists $lightDict effects_v2 action effect_values]} {
        set A(effect_values) [dict get $lightDict effects_v2 action effect_values]
    } elseif {[dict exists $lightDict effects effect_values]} {
        set A(effect_values) [dict get $lightDict effects effect_values]
    }

    if {[dict exists $lightDict timed_effects effect_values]} {
        set A(timed_effect_values) [dict get $lightDict timed_effects effect_values]
    }
}

proc ::hue::lights::getLightByNameArray {name arrName} {
    set l [::hue::lights::getLightByName $name]
    ::hue::lights::_lightDictToArray $l $arrName
    return
}
proc ::hue::lights::getLightByIndexArray {index arrName} {
    set l [::hue::lights::getLightByIndex $index]
    ::hue::lights::_lightDictToArray $l $arrName
    return
}
proc ::hue::lights::getLightByIDArray {id arrName} {
    set l [::hue::lights::getLightByID $id]
    ::hue::lights::_lightDictToArray $l $arrName
    return
}

# ----------------------------------------------------------------------
# GET light state (v1) for compatibility/testing (LOCAL ONLY)
# ----------------------------------------------------------------------
proc ::hue::lights::getStateV1ByIndex {index} {
    ::hue::lights::_requireLocalForV1

    set bridge [::hue::config get -bridge]
    set key    [::hue::config get -key]
    if {$bridge eq "" || $key eq ""} {
        ::hue::softError "Missing local config. Use: ::hue::config set -mode local -bridge <ip> -key <key>"
    }

    set url "https://$bridge/api/$key/lights/$index"
    set body [exec curl -sS -k $url]
    set d [json::json2dict $body]
    if {[dict exists $d error]} {
        ::hue::softError "Hue v1 error: $body"
    }
    if {![dict exists $d state]} {
        ::hue::softError "Invalid Hue v1 response (no state)"
    }
    return [dict get $d state]
}

proc ::hue::lights::getStateV1ByName {name} {
    set idx [::hue::lights::getIndexByName $name]
    return [::hue::lights::getStateV1ByIndex $idx]
}

# ----------------------------------------------------------------------
# Simple setters requested
# ----------------------------------------------------------------------

# V1: /api/<key>/lights/<idx>/state  (LOCAL ONLY)
proc ::hue::lights::setLightV1 {who args} {
    ::hue::lights::_requireLocalForV1

    set idx ""
    if {[regexp {^[0-9]+$} $who]} {
        set idx $who
    } else {
        set idx [::hue::lights::getIndexByName $who]
    }

    set haveX 0; set haveY 0; set x ""; set y ""
    set haveCT 0; set ct ""
    set haveTT 0; set ttSec ""
    set haveEffect 0; set effect ""
    set haveBri 0; set bri ""
    set haveAlert 0; set alert ""
    set haveOn 0; set onVal 0

    set i 0
    while {$i < [llength $args]} {
        set a [lindex $args $i]
        switch -nocase -- $a {
            on  { set haveOn 1; set onVal 1; incr i; continue }
            off { set haveOn 1; set onVal 0; incr i; continue }

            x { if {$i+1 >= [llength $args]} { ::hue::softError "setLightV1: missing value for x" }
                set x [lindex $args [incr i]]; set haveX 1; incr i; continue }
            y { if {$i+1 >= [llength $args]} { ::hue::softError "setLightV1: missing value for y" }
                set y [lindex $args [incr i]]; set haveY 1; incr i; continue }

            ct { if {$i+1 >= [llength $args]} { ::hue::softError "setLightV1: missing value for ct" }
                set ct [lindex $args [incr i]]; set haveCT 1; incr i; continue }

            transitiontime { if {$i+1 >= [llength $args]} { ::hue::softError "setLightV1: missing value for transitiontime (seconds)" }
                set ttSec [lindex $args [incr i]]; set haveTT 1; incr i; continue }

            effect { if {$i+1 >= [llength $args]} { ::hue::softError "setLightV1: missing value for effect" }
                set effect [lindex $args [incr i]]; set haveEffect 1; incr i; continue }

            bri { if {$i+1 >= [llength $args]} { ::hue::softError "setLightV1: missing value for bri" }
                set bri [lindex $args [incr i]]; set haveBri 1; incr i; continue }

            alert { if {$i+1 >= [llength $args]} { ::hue::softError "setLightV1: missing value for alert" }
                set alert [string tolower [string trim [lindex $args [incr i]]]]
                set haveAlert 1; incr i; continue }

            breathe {
                set haveAlert 1
                set alert "select"
                incr i
                continue
            }
            breathe_long {
                set haveAlert 1
                set alert "lselect"
                incr i
                continue
            }

            default { ::hue::softError "setLightV1: unknown parameter '$a'" }
        }
    }

    if {$haveX != $haveY} { ::hue::softError "setLightV1: x and y must be provided together" }

    if {$haveX} {
        if {![regexp {^[0-9]+(\.[0-9]+)?$} $x] || ![regexp {^[0-9]+(\.[0-9]+)?$} $y]} {
            ::hue::softError "setLightV1: x/y must be numeric"
        }
    }
    if {$haveCT && ![regexp {^[0-9]+$} $ct]} { ::hue::softError "setLightV1: ct must be integer" }
    if {$haveBri} {
        if {![regexp {^[0-9]+$} $bri]} { ::hue::softError "setLightV1: bri must be integer 0..254" }
        set bi [expr {int($bri)}]
        if {$bi < 0 || $bi > 254} { ::hue::softError "setLightV1: bri out of range (0..254)" }
        set bri $bi
    }
    if {$haveAlert} {
        if {$alert ni {"select" "lselect" "none"}} {
            ::hue::softError "setLightV1: alert must be select|lselect|none (or use breathe/breathe_long)"
        }
    }

    set ttDs ""
    if {$haveTT} {
        if {![regexp {^[0-9]+(\.[0-9]+)?$} $ttSec]} {
            ::hue::softError "setLightV1: transitiontime must be seconds as number (e.g. 0.3)"
        }
        set ttDs [expr {int(($ttSec * 10.0) + 0.5)}]
        if {$ttDs < 0} { set ttDs 0 }
    }

    set json "{"
    set first 1
    if {$haveOn} {
        if {!$first} { append json "," } else { set first 0 }
        append json "\"on\":" [expr {$onVal ? "true" : "false"}]
    }
    if {$haveX} {
        if {!$first} { append json "," } else { set first 0 }
        append json "\"xy\":[" $x "," $y "]"
    }
    if {$haveCT} {
        if {!$first} { append json "," } else { set first 0 }
        append json "\"ct\":" $ct
    }
    if {$haveBri} {
        if {!$first} { append json "," } else { set first 0 }
        append json "\"bri\":" $bri
    }
    if {$haveTT} {
        if {!$first} { append json "," } else { set first 0 }
        append json "\"transitiontime\":" $ttDs
    }
    if {$haveEffect} {
        if {!$first} { append json "," } else { set first 0 }
        append json "\"effect\":\"" $effect "\""
    }
    if {$haveAlert} {
        if {!$first} { append json "," } else { set first 0 }
        append json "\"alert\":\"" $alert "\""
    }
    append json "}"

    if {$first} { return {} }

    set bridge [::hue::config get -bridge]
    set key    [::hue::config get -key]
    if {$bridge eq "" || $key eq ""} {
        ::hue::softError "Missing local config: ::hue::config set -mode local -bridge <ip> -key <key>"
    }

    set url "https://$bridge/api/$key/lights/$idx/state"
    set body [exec curl -sS -k -X PUT -H "Content-Type: application/json" -d $json $url]
    return [json::json2dict $body]
}

# V2: /clip/v2/resource/light/<v2id> (local OR remote)
proc ::hue::lights::setLightV2 {who args} {
    set id ""
    if {[regexp {^[0-9]+$} $who]} {
        set id [::hue::lights::getIDByIndex $who]
    } elseif {[regexp {^[0-9a-fA-F-]{20,}$} $who]} {
        set id $who
    } else {
        set id [::hue::lights::getIDByName $who]
    }

    set haveX 0; set haveY 0; set x ""; set y ""
    set haveCT 0; set ct ""
    set haveTT 0; set ttSec ""
    set haveBrightness 0; set brightness ""
    set haveEffects 0; set eff ""
    set haveAlert 0; set alertAction ""
    set haveOn 0; set onVal 0

    set i 0
    while {$i < [llength $args]} {
        set a [lindex $args $i]
        switch -nocase -- $a {
            on  { set haveOn 1; set onVal 1; incr i; continue }
            off { set haveOn 1; set onVal 0; incr i; continue }

            x { if {$i+1 >= [llength $args]} { ::hue::softError "setLightV2: missing value for x" }
                set x [lindex $args [incr i]]; set haveX 1; incr i; continue }
            y { if {$i+1 >= [llength $args]} { ::hue::softError "setLightV2: missing value for y" }
                set y [lindex $args [incr i]]; set haveY 1; incr i; continue }

            ct { if {$i+1 >= [llength $args]} { ::hue::softError "setLightV2: missing value for ct" }
                set ct [lindex $args [incr i]]; set haveCT 1; incr i; continue }

            transitiontime { if {$i+1 >= [llength $args]} { ::hue::softError "setLightV2: missing value for transitiontime (seconds)" }
                set ttSec [lindex $args [incr i]]; set haveTT 1; incr i; continue }

            brightness { if {$i+1 >= [llength $args]} { ::hue::softError "setLightV2: missing value for brightness" }
                set brightness [lindex $args [incr i]]; set haveBrightness 1; incr i; continue }

            effects_v2 { if {$i+1 >= [llength $args]} { ::hue::softError "setLightV2: missing value for effects_v2" }
                set eff [lindex $args [incr i]]; set haveEffects 1; incr i; continue }

            alert { if {$i+1 >= [llength $args]} { ::hue::softError "setLightV2: missing value for alert" }
                set alertAction [string tolower [string trim [lindex $args [incr i]]]]
                set haveAlert 1; incr i; continue }

            breathe {
                set haveAlert 1
                set alertAction "breathe"
                incr i
                continue
            }

            default { ::hue::softError "setLightV2: unknown parameter '$a'" }
        }
    }

    if {$haveX != $haveY} { ::hue::softError "setLightV2: x and y must be provided together" }

    if {$haveX} {
        if {![regexp {^[0-9]+(\.[0-9]+)?$} $x] || ![regexp {^[0-9]+(\.[0-9]+)?$} $y]} {
            ::hue::softError "setLightV2: x/y must be numeric"
        }
    }
    if {$haveCT} {
        set ct [string trim $ct]
        if {![regexp {^[0-9]+(\.[0-9]+)?$} $ct]} {
            ::hue::softError "setLightV2: ct must be a number (mirek), e.g. 366"
        }
        set ct [expr {int(double($ct) + 0.5)}]
    }

    set ms ""
    if {$haveTT} {
        if {![regexp {^[0-9]+(\.[0-9]+)?$} $ttSec]} {
            ::hue::softError "setLightV2: transitiontime must be seconds as number (e.g. 0.3)"
        }
        set ms [expr {int(($ttSec * 1000.0) + 0.5)}]
        if {$ms < 0} { set ms 0 }
    }

    if {$haveBrightness} {
        if {![regexp {^[0-9]+(\.[0-9]+)?$} $brightness]} {
            ::hue::softError "setLightV2: brightness must be number 0..100"
        }
        set b [expr {double($brightness)}]
        if {$b < 0.0 || $b > 100.0} { ::hue::softError "setLightV2: brightness out of range (0..100)" }
        set brightness $b
    }

    if {$haveAlert} {
        if {$alertAction ni {"breathe" "none"}} {
            ::hue::softError "setLightV2: alert must be breathe|none (or use breathe)"
        }
    }

    set json "{"
    set firstTop 1

    if {$haveOn} {
        if {!$firstTop} { append json "," } else { set firstTop 0 }
        append json "\"on\":{\"on\":" [expr {$onVal ? "true" : "false"}] "}"
    }
    if {$haveX} {
        if {!$firstTop} { append json "," } else { set firstTop 0 }
        append json "\"color\":{\"xy\":{\"x\":" $x ",\"y\":" $y "}}"
    }
    if {$haveCT} {
        if {!$firstTop} { append json "," } else { set firstTop 0 }
        append json "\"color_temperature\":{\"mirek\":" $ct "}"
    }
    if {$haveBrightness} {
        if {!$firstTop} { append json "," } else { set firstTop 0 }
        append json "\"dimming\":{\"brightness\":" $brightness "}"
    }
    if {$haveTT} {
        if {!$firstTop} { append json "," } else { set firstTop 0 }
        append json "\"dynamics\":{\"duration\":" $ms "}"
    }
    if {$haveEffects} {
        if {!$firstTop} { append json "," } else { set firstTop 0 }
        append json "\"effects_v2\":{\"action\":{\"effect\":\"" $eff "\"}}"
    }
    if {$haveAlert} {
        if {!$firstTop} { append json "," } else { set firstTop 0 }
        append json "\"alert\":{\"action\":\"" $alertAction "\"}"
    }

    append json "}"

    if {$firstTop} { return {} }

    set body [::hue::httpPutJson "/clip/v2/resource/light/$id" $json]
    return [json::json2dict $body]
}

# Normalize on/off from array value
proc ::hue::lights::_bool {v} {
    set s [string tolower [string trim $v]]
    if {$s in {"1" "true" "on" "yes"}} { return 1 }
    if {$s in {"0" "false" "off" "no"}} { return 0 }
    ::hue::softError "Invalid boolean: $v (use true/false or on/off)"
}

# Apply array -> V1 (only keys present and non-empty are sent) (LOCAL ONLY)
proc ::hue::lights::applyLightArrayV1 {who arrName} {
    ::hue::lights::_requireLocalForV1
    upvar 1 $arrName A

    set args {}
    if {[info exists A(on)] && $A(on) ne ""} {
        if {[::hue::lights::_bool $A(on)]} { lappend args on } else { lappend args off }
    }

    if {[info exists A(bri)] && $A(bri) ne ""} {
        lappend args bri $A(bri)
    }
    if {[info exists A(x)] && $A(x) ne "" && [info exists A(y)] && $A(y) ne ""} {
        lappend args x $A(x) y $A(y)
    }
    if {[info exists A(ct)] && $A(ct) ne ""} {
        lappend args ct $A(ct)
    }
    if {[info exists A(transitiontime)] && $A(transitiontime) ne ""} {
        lappend args transitiontime $A(transitiontime)
    }
    if {[info exists A(effect)] && $A(effect) ne ""} {
        lappend args effect $A(effect)
    }
    if {[info exists A(alert)] && $A(alert) ne ""} {
        lappend args alert $A(alert)
    }

    if {[llength $args] == 0} { return {} }
    return [::hue::lights::setLightV1 $who {*}$args]
}

# Apply array -> V2 (only keys present and non-empty are sent)
proc ::hue::lights::applyLightArrayV2 {who arrName} {
    upvar 1 $arrName A

    array set S [array get A]

    foreach k [array names S] {
        set v [string trim $S($k)]
        # treat literal "null" as empty
        if {[string tolower $v] eq "null"} { set v "" }
        if {$v eq ""} {
            unset S($k)
        } else {
            set S($k) $v
        }
    }

    # If ct is present but not numeric, DROP it (do not error)
    if {[info exists S(ct)]} {
        if {![regexp {^[0-9]+(\.[0-9]+)?$} $S(ct)]} {
            unset S(ct)
        }
    }

    set args {}

    if {[info exists S(on)]} {
        if {[::hue::lights::_bool $S(on)]} { lappend args on } else { lappend args off }
    }
    if {[info exists S(brightness)]} {
        lappend args brightness $S(brightness)
    }
    if {[info exists S(x)] && [info exists S(y)]} {
        lappend args x $S(x) y $S(y)
    }
    if {[info exists S(ct)]} {
        lappend args ct $S(ct)
    }
    if {[info exists S(transitiontime)]} {
        lappend args transitiontime $S(transitiontime)
    }
    if {[info exists S(effects_v2)]} {
        lappend args effects_v2 $S(effects_v2)
    } elseif {[info exists S(effect)]} {
        lappend args effects_v2 $S(effect)
    }
    if {[info exists S(alert)]} {
        lappend args alert $S(alert)
    }

    if {[llength $args] == 0} { return {} }
    return [::hue::lights::setLightV2 $who {*}$args]
}

proc ::hue::lights::help {} {
    puts "Hue Lights (v2 mapping + v1/v2 control) - ::hue::lights::*"
    puts ""
    puts "Load/cache:"
    puts "  ::hue::ensureLoaded light"
    puts "  ::hue::lights::ensureLoaded ?force?"
    puts ""
    puts "Lists:"
    puts "  ::hue::lights::list names|indices|ids|all"
    puts ""
    puts "Lookups (case-insensitive + fuzzy; prompts on ambiguity unless non-interactive):"
    puts "  ::hue::lights::getIndexByName <name>     ;# v1 index (best-effort; may be unavailable in remote)"
    puts "  ::hue::lights::getIDByName    <name>     ;# v2 id"
    puts "  ::hue::lights::getNameByID    <v2id>"
    puts "  ::hue::lights::getIndexByID   <v2id>     ;# only if v1 index known"
    puts "  ::hue::lights::getNameByIndex <index>"
    puts "  ::hue::lights::getIDByIndex   <index>"
    puts ""
    puts "Get attributes/state (v2):"
    puts "  ::hue::lights::getLightByName   <name>"
    puts "  ::hue::lights::getLightByIndex  <index>"
    puts "  ::hue::lights::getLightByID     <v2id>"
    puts "  ::hue::lights::getStateByName   <name>"
    puts "  ::hue::lights::getStateByIndex  <index>"
    puts "  ::hue::lights::getStateByID     <v2id>"
    puts ""
    puts "Array getters:"
    puts "  ::hue::lights::getLightByNameArray  <name>  ::Arr"
    puts "  ::hue::lights::getLightByIndexArray <idx>   ::Arr"
    puts "  ::hue::lights::getLightByIDArray    <v2id>  ::Arr"
    puts ""
    puts "Set light (only passed parameters change):"
    puts "  V1 (LOCAL only): ::hue::lights::setLightV1 <index|name>  ?on|off? ?bri 0..254?"
    puts "  V2 (local+remote): ::hue::lights::setLightV2 <index|name|v2id> ?on|off? ?brightness 0..100?"
    puts "        ?x <float> y <float>? ?ct <mirek int>? ?transitiontime <seconds float>?"
    puts "        ?effects_v2 <string>? ?alert breathe|none? ?breathe?"
    puts ""
    puts "Apply array:"
    puts "  ::hue::lights::applyLightArrayV2 <index|name|v2id> ::Arr"
}
