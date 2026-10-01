# hue.inc.groups.tcl  (Tcl 8.5)
#
# Hue Bridge v1 groups under ::hue::groups   (LOCAL API)
# - persistent cache in .resources next to hue.inc.core.tcl
# - TTL 30 days
# - fuzzy + case-insensitive lookups with interactive disambiguation
# - group array getters/setters similar to lights
#
# NOTE:
#   Groups are managed via Hue v1 local bridge API (/api/<key>/groups...).
#   Even if ::hue::mode is "remote", this module can still operate using
#   ::hue::http*Local helpers (requires local -bridge and -key in config).
#
# Requires (from hue.inc.core.tcl):
#   ::hue::config get -bridge/-key (local creds must exist)
#   ::hue::cacheDir
#   ::hue::ensureCacheDirExists
#   ::hue::softError
#   ::hue::chooseOne
#   ::hue::log (optional)
#   ::hue::httpGetLocal
#   ::hue::httpPutJsonLocal

package require json

namespace eval ::hue::groups {
    variable nameByIndex;   array set nameByIndex  {}
    variable typeByIndex;   array set typeByIndex  {}
    variable classByIndex;  array set classByIndex {}
    variable lightsByIndex; array set lightsByIndex {}

    # preferred mapping for convenience (Room > LightGroup > Zone > others)
    variable indexByName;   array set indexByName  {}

    variable loaded 0
    variable lastLoad 0
    variable cacheTTL 2592000
}

# ----------------------------------------------------------------------
# Local API guard (requires local bridge+key)
# ----------------------------------------------------------------------
proc ::hue::groups::_requireLocalCreds {} {
    set bridge [::hue::config get -bridge]
    set key    [::hue::config get -key]
    if {$bridge eq "" || $key eq ""} {
        ::hue::softError "Hue groups use local v1 API; missing local bridge/key. Set: ::hue::config set -bridge <ip> -key <key>  (mode may remain remote)."
    }
}

# ----------------------------------------------------------------------
# JSON string escaper (minimal, safe)
# ----------------------------------------------------------------------
proc ::hue::groups::_jsonEscape {s} {
    regsub -all {\\} $s {\\\\} s
    regsub -all {"}  $s {\\"}  s
    regsub -all {\r} $s {\\r}  s
    regsub -all {\n} $s {\\n}  s
    regsub -all {\t} $s {\\t}  s
    regsub -all {\f} $s {\\f} s
    regsub -all {\b} $s {\\b} s
    return $s
}

# ----------------------------------------------------------------------
# Cache
# ----------------------------------------------------------------------
proc ::hue::groups::cacheFile {} {
    ::hue::ensureCacheDirExists
    return [file join [::hue::cacheDir] "hue_groups_cache.tcl"]
}

proc ::hue::groups::clear {} {
    foreach a {nameByIndex typeByIndex classByIndex lightsByIndex indexByName} {
        catch {unset ::hue::groups::$a}
        array set ::hue::groups::$a {}
    }
    set ::hue::groups::loaded 0
    set ::hue::groups::lastLoad 0
}

proc ::hue::groups::saveCache {} {
    set f [::hue::groups::cacheFile]
    set ch [open $f w]
    fconfigure $ch -translation lf
    puts $ch "namespace eval ::hue::groups {"
    puts $ch "  set loaded 1"
    puts $ch "  set lastLoad [::list $::hue::groups::lastLoad]"
    foreach a {nameByIndex typeByIndex classByIndex lightsByIndex indexByName} {
        puts $ch "  catch {unset $a}; array set $a [::list [array get ::hue::groups::$a]]"
    }
    puts $ch "}"
    close $ch
}

proc ::hue::groups::loadCache {} {
    set f [::hue::groups::cacheFile]
    if {![file exists $f]} { return 0 }
    if {[catch {source $f}]} { return 0 }

    foreach a {nameByIndex typeByIndex classByIndex lightsByIndex indexByName} {
        if {![info exists ::hue::groups::$a]} { array set ::hue::groups::$a {} }
    }
    return [expr {$::hue::groups::loaded ? 1 : 0}]
}

# ----------------------------------------------------------------------
# Internal: v1 GET/PUT helpers (via core local HTTP wrappers)
# ----------------------------------------------------------------------
proc ::hue::groups::_v1Get {path} {
    ::hue::groups::_requireLocalCreds
    set key [::hue::config get -key]
    set body [::hue::httpGetLocal "/api/$key$path"]
    return [json::json2dict $body]
}

proc ::hue::groups::_v1PutJson {path jsonBody} {
    ::hue::groups::_requireLocalCreds
    set key [::hue::config get -key]
    set body [::hue::httpPutJsonLocal "/api/$key$path" $jsonBody]

    # Hue v1 returns JSON array of success/error objects; simplest: if raw contains "error" -> fail
    if {[string first "\"error\"" $body] >= 0} {
        ::hue::softError "Hue v1 error: $body"
    }
    return [json::json2dict $body]
}

# ----------------------------------------------------------------------
# Load all groups from bridge (v1)
# ----------------------------------------------------------------------
proc ::hue::groups::loadAll {} {
    ::hue::groups::_requireLocalCreds
    ::hue::groups::clear

    set d [::hue::groups::_v1Get "/groups"]
    foreach idx [dict keys $d] {
        set g [dict get $d $idx]

        set name  ""; if {[dict exists $g name]}  { set name  [dict get $g name] }
        set type  ""; if {[dict exists $g type]}  { set type  [dict get $g type] }
        set class ""; if {[dict exists $g class]} { set class [dict get $g class] }
        set lights {}; if {[dict exists $g lights]} { set lights [dict get $g lights] }

        set ::hue::groups::nameByIndex($idx)   $name
        set ::hue::groups::typeByIndex($idx)   $type
        set ::hue::groups::classByIndex($idx)  $class
        set ::hue::groups::lightsByIndex($idx) $lights
    }

    ::hue::groups::_rebuildPreferredIndexByName

    set ::hue::groups::loaded 1
    set ::hue::groups::lastLoad [clock seconds]
    ::hue::groups::saveCache
}

proc ::hue::groups::ensureLoaded {{force 0}} {
    ::hue::groups::_requireLocalCreds

    if {!$::hue::groups::loaded} {
        ::hue::groups::loadCache
    }

    if {$force} {
        ::hue::log "groups: reset -> refreshing from bridge"
        ::hue::groups::loadAll
        return
    }

    if {$::hue::groups::loaded} {
        set age [expr {[clock seconds] - $::hue::groups::lastLoad}]
        if {$age < $::hue::groups::cacheTTL} {
            ::hue::log "groups: using cache (age=${age}s)"
            return
        }
        ::hue::log "groups: cache expired (age=${age}s) -> refreshing"
    } else {
        ::hue::log "groups: no cache -> refreshing"
    }

    ::hue::groups::loadAll
}

# ----------------------------------------------------------------------
# Preferred mapping helpers
# ----------------------------------------------------------------------
proc ::hue::groups::_typeRank {t} {
    set t [string tolower [string trim $t]]
    switch -- $t {
        room       { return 1 }
        lightgroup { return 2 }
        zone       { return 3 }
        default    { return 9 }
    }
}

proc ::hue::groups::_rebuildPreferredIndexByName {} {
    catch {unset ::hue::groups::indexByName}
    array set ::hue::groups::indexByName {}

    foreach idx [array names ::hue::groups::nameByIndex] {
        set n $::hue::groups::nameByIndex($idx)
        set t ""
        if {[info exists ::hue::groups::typeByIndex($idx)]} {
            set t $::hue::groups::typeByIndex($idx)
        }

        if {![info exists ::hue::groups::indexByName($n)]} {
            set ::hue::groups::indexByName($n) $idx
        } else {
            set cur $::hue::groups::indexByName($n)
            set r1 [::hue::groups::_typeRank $t]
            set r2 [::hue::groups::_typeRank $::hue::groups::typeByIndex($cur)]
            if {$r1 < $r2} {
                set ::hue::groups::indexByName($n) $idx
            }
        }
    }
}

# ----------------------------------------------------------------------
# Fuzzy resolver for group names (duplicates safe)
# ----------------------------------------------------------------------
proc ::hue::groups::_resolveIndexByNameFuzzy {wanted} {
    ::hue::groups::ensureLoaded 0
    set w [string tolower [string trim $wanted]]

    foreach n [array names ::hue::groups::indexByName] {
        if {[string tolower [string trim $n]] eq $w} {
            return $::hue::groups::indexByName($n)
        }
    }

    set prefix {}
    set substr {}

    foreach idx [array names ::hue::groups::nameByIndex] {
        set n $::hue::groups::nameByIndex($idx)
        set nn [string tolower [string trim $n]]
        if {$nn eq ""} continue

        if {[string first $w $nn] == 0} {
            lappend prefix $idx
        } elseif {[string first $w $nn] >= 0} {
            lappend substr $idx
        }
    }

    set cands $prefix
    if {[llength $cands] == 0} { set cands $substr }
    if {[llength $cands] == 0} {
        ::hue::softError "Unknown group name: $wanted"
    }
    if {[llength $cands] == 1} { return [lindex $cands 0] }

    set opts {}
    foreach idx [lsort -integer $cands] {
        set n $::hue::groups::nameByIndex($idx)
        set t $::hue::groups::typeByIndex($idx)
        lappend opts [format "%s (index=%s, type=%s)" $n $idx $t]
    }

    set chosenLabel [::hue::chooseOne "Multiple matches for group name '$wanted':" $opts]
    if {![regexp {index=([0-9]+)} $chosenLabel -> chosenIdx]} {
        ::hue::softError "Internal error: could not parse chosen group index"
    }
    return $chosenIdx
}

# ----------------------------------------------------------------------
# Getters
# ----------------------------------------------------------------------
proc ::hue::groups::getIndexByName {name} {
    return [::hue::groups::_resolveIndexByNameFuzzy $name]
}

proc ::hue::groups::getNameByIndex {index} {
    if {!$::hue::groups::loaded} { ::hue::groups::loadCache }
    if {![info exists ::hue::groups::nameByIndex($index)]} {
        ::hue::softError "Unknown group index: $index"
    }
    return $::hue::groups::nameByIndex($index)
}

proc ::hue::groups::getTypeByIndex {index} {
    if {!$::hue::groups::loaded} { ::hue::groups::loadCache }
    if {![info exists ::hue::groups::typeByIndex($index)]} {
        ::hue::softError "Unknown group index: $index"
    }
    return $::hue::groups::typeByIndex($index)
}

proc ::hue::groups::getClassByIndex {index} {
    if {!$::hue::groups::loaded} { ::hue::groups::loadCache }
    if {![info exists ::hue::groups::classByIndex($index)]} {
        ::hue::softError "Unknown group index: $index"
    }
    return $::hue::groups::classByIndex($index)
}

proc ::hue::groups::getLightsByIndex {index} {
    if {!$::hue::groups::loaded} { ::hue::groups::loadCache }
    if {![info exists ::hue::groups::lightsByIndex($index)]} {
        ::hue::softError "Unknown group index: $index"
    }
    return $::hue::groups::lightsByIndex($index)
}

proc ::hue::groups::getLightsByName {name} {
    set idx [::hue::groups::getIndexByName $name]
    return [::hue::groups::getLightsByIndex $idx]
}

# ----------------------------------------------------------------------
# List / inventory helpers
# ----------------------------------------------------------------------
proc ::hue::groups::list {{what all}} {
    ::hue::groups::ensureLoaded 0

    switch -nocase -- $what {
        names {
            set seen {}
            set out {}
            foreach idx [lsort -integer [array names ::hue::groups::nameByIndex]] {
                set n $::hue::groups::nameByIndex($idx)
                if {[dict exists $seen $n]} continue
                dict set seen $n 1
                lappend out $n
            }
            return $out
        }
        indices {
            return [lsort -integer [array names ::hue::groups::nameByIndex]]
        }
        all {
            set out {}
            foreach idx [lsort -integer [array names ::hue::groups::nameByIndex]] {
                set n $::hue::groups::nameByIndex($idx)
                set t $::hue::groups::typeByIndex($idx)
                set c $::hue::groups::classByIndex($idx)
                set l $::hue::groups::lightsByIndex($idx)
                lappend out [::list $idx $n $t $c $l]
            }
            return $out
        }
        default {
            ::hue::softError "Usage: ::hue::groups::list ?names|indices|all?"
        }
    }
}

proc ::hue::groups::printGroups {} {
    ::hue::groups::ensureLoaded 0
    foreach row [::hue::groups::list all] {
        lassign $row idx n t c l
        puts [format "%s: %-25s type=%-14s class=%-12s lights=%s" $idx $n $t $c $l]
    }
}

# ----------------------------------------------------------------------
# Array getter (flat group view like lights)
# ----------------------------------------------------------------------
proc ::hue::groups::_groupToArray {index arrName} {
    upvar 1 $arrName A
    catch {unset A}
    array set A {}

    set A(index) $index
    set A(name) ""
    set A(type) ""
    set A(class) ""
    set A(lights) ""

    if {[info exists ::hue::groups::nameByIndex($index)]}   { set A(name)   $::hue::groups::nameByIndex($index) }
    if {[info exists ::hue::groups::typeByIndex($index)]}   { set A(type)   $::hue::groups::typeByIndex($index) }
    if {[info exists ::hue::groups::classByIndex($index)]}  { set A(class)  $::hue::groups::classByIndex($index) }
    if {[info exists ::hue::groups::lightsByIndex($index)]} { set A(lights) $::hue::groups::lightsByIndex($index) }
}

proc ::hue::groups::getGroupByIndexArray {index arrName} {
    ::hue::groups::ensureLoaded 0
    if {![info exists ::hue::groups::nameByIndex($index)]} {
        ::hue::softError "Unknown group index: $index"
    }
    ::hue::groups::_groupToArray $index $arrName
    return
}

proc ::hue::groups::getGroupByNameArray {name arrName} {
    ::hue::groups::ensureLoaded 0
    set idx [::hue::groups::getIndexByName $name]
    ::hue::groups::_groupToArray $idx $arrName
    return
}

# ----------------------------------------------------------------------
# Membership editing helpers
# ----------------------------------------------------------------------
proc ::hue::groups::_ensureEditable {groupIndex} {
    set t [::hue::groups::getTypeByIndex $groupIndex]
    set tl [string tolower [string trim $t]]
    if {$tl in {"room" "lightgroup" "zone"}} {
        return
    }
    ::hue::softError "Group $groupIndex is type '$t' and does not accept editing 'lights' (use the Room/LightGroup id, not Entertainment)."
}

proc ::hue::groups::lightsJson {lightsList} {
    set json "{"
    append json "\"lights\":["
    set first 1
    foreach li $lightsList {
        if {!$first} { append json "," } else { set first 0 }
        append json "\"" [::hue::groups::_jsonEscape $li] "\""
    }
    append json "]}"
    return $json
}

proc ::hue::groups::setLightsByIndex {groupIndex lightsList} {
    ::hue::groups::ensureLoaded 0
    ::hue::groups::_ensureEditable $groupIndex

    set jsonBody [::hue::groups::lightsJson $lightsList]
    set resp [::hue::groups::_v1PutJson "/groups/$groupIndex" $jsonBody]

    set ::hue::groups::lightsByIndex($groupIndex) $lightsList
    ::hue::groups::saveCache
    return $resp
}

proc ::hue::groups::addLightToGroupByIndex {groupIndex lightIndex} {
    ::hue::groups::ensureLoaded 0
    set cur [::hue::groups::getLightsByIndex $groupIndex]
    if {[lsearch -exact $cur $lightIndex] >= 0} {
        return {}
    }
    set updated [concat $cur [::list $lightIndex]]
    return [::hue::groups::setLightsByIndex $groupIndex $updated]
}

proc ::hue::groups::removeLightFromGroupByIndex {groupIndex lightIndex} {
    ::hue::groups::ensureLoaded 0
    set cur [::hue::groups::getLightsByIndex $groupIndex]
    set pos [lsearch -exact $cur $lightIndex]
    if {$pos < 0} { return {} }
    set updated [lreplace $cur $pos $pos]
    return [::hue::groups::setLightsByIndex $groupIndex $updated]
}

proc ::hue::groups::addLightToGroupByName {groupName lightIndex} {
    ::hue::groups::ensureLoaded 0
    set idx [::hue::groups::getIndexByName $groupName]
    return [::hue::groups::addLightToGroupByIndex $idx $lightIndex]
}

proc ::hue::groups::removeLightFromGroupByName {groupName lightIndex} {
    ::hue::groups::ensureLoaded 0
    set idx [::hue::groups::getIndexByName $groupName]
    return [::hue::groups::removeLightFromGroupByIndex $idx $lightIndex]
}

# ----------------------------------------------------------------------
# Rename group
# ----------------------------------------------------------------------
proc ::hue::groups::renameGroupByIndex {groupIndex newName} {
    ::hue::groups::ensureLoaded 0

    set json "{"
    append json "\"name\":\"" [::hue::groups::_jsonEscape $newName] "\""
    append json "}"

    set resp [::hue::groups::_v1PutJson "/groups/$groupIndex" $json]

    set ::hue::groups::nameByIndex($groupIndex) $newName
    ::hue::groups::_rebuildPreferredIndexByName
    ::hue::groups::saveCache
    return $resp
}

proc ::hue::groups::renameGroupByName {groupName newName} {
    ::hue::groups::ensureLoaded 0
    set idx [::hue::groups::getIndexByName $groupName]
    return [::hue::groups::renameGroupByIndex $idx $newName]
}

# ----------------------------------------------------------------------
# Array setter (round-trip)
# ----------------------------------------------------------------------
proc ::hue::groups::applyGroupArrayV1 {who arrName} {
    upvar 1 $arrName A
    ::hue::groups::ensureLoaded 0

    set groupIndex ""
    if {[regexp {^[0-9]+$} $who]} {
        set groupIndex $who
    } else {
        set groupIndex [::hue::groups::getIndexByName $who]
    }

    set did 0
    set resp {}

    if {[info exists A(name)] && [string trim $A(name)] ne ""} {
        set resp [::hue::groups::renameGroupByIndex $groupIndex [string trim $A(name)]]
        set did 1
    }

    if {[info exists A(lights)] && $A(lights) ne ""} {
        set resp [::hue::groups::setLightsByIndex $groupIndex $A(lights)]
        set did 1
    }

    if {!$did} { return {} }
    return $resp
}

# ----------------------------------------------------------------------
# Help
# ----------------------------------------------------------------------
proc ::hue::groups::help {} {
    puts "Hue Groups (v1 via LOCAL bridge API) - ::hue::groups::*"
    puts ""
    puts "Load/cache:"
    puts "  ::hue::ensureLoaded group"
    puts "  ::hue::groups::ensureLoaded ?force?"
    puts "    force=1 refreshes from bridge, else uses cache (TTL=30 days)"
    puts ""
    puts "Fast lists (in-memory):"
    puts "  ::hue::groups::list names"
    puts "  ::hue::groups::list indices"
    puts "  ::hue::groups::list all       ;# {idx name type class lights}"
    puts "  ::hue::groups::printGroups"
    puts ""
    puts "Lookups (case-insensitive + fuzzy, prefix-first):"
    puts "  ::hue::groups::getIndexByName <name>"
    puts "  ::hue::groups::getNameByIndex <index>"
    puts "  ::hue::groups::getLightsByName <name>"
    puts ""
    puts "Array getters:"
    puts "  ::hue::groups::getGroupByNameArray  <name>  ::G"
    puts "  ::hue::groups::getGroupByIndexArray <index> ::G"
    puts ""
    puts "Membership editing (Room/LightGroup/Zone only):"
    puts "  ::hue::groups::setLightsByIndex <groupIndex> {20 22 28}"
    puts "  ::hue::groups::addLightToGroupByName \"guestbath\" 32"
    puts "  ::hue::groups::removeLightFromGroupByName \"guestbath\" 32"
    puts ""
    puts "Rename:"
    puts "  ::hue::groups::renameGroupByName \"guestbath\" \"Guest Bathroom\""
    puts ""
    puts "Round-trip array apply:"
    puts "  ::hue::groups::applyGroupArrayV1 \"guestbath\" ::G"
    puts ""
    puts "Examples:"
    puts {  ::hue::ensureLoaded group}
    puts {  ::hue::groups::printGroups}
    puts {  ::hue::groups::getGroupByNameArray "guestbath" ::G}
    puts {  parray ::G}
    puts {  set ::G(lights) {20 22 28 21}}
    puts {  ::hue::groups::applyGroupArrayV1 "guestbath" ::G}
}
