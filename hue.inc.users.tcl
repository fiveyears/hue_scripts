# hue.inc.users.tcl (Tcl 8.5)
#
# Hue "users" / application keys / whitelist management.
#
# This version keeps ONLY a unified cache (local<->remote mapping),
# because building the mapping is expensive (active-key flipping).
#
# LOCAL (bridge v1):
#   GET    https://<bridge>/api/<username>/config                 -> includes "whitelist"
#   DELETE https://<bridge>/api/<username>/config/whitelist/<u>
#   POST   https://<bridge>/api                                   -> create user (link button)
#
# REMOTE (Hue cloud proxy "route/api"):
#   PUT    https://api.meethue.com/route/api/0/config             {"linkbutton":true}
#   POST   https://api.meethue.com/route/api                      {"devicetype":"x#y", ...}   (NO /0)
#   DELETE https://api.meethue.com/route/api/0/config/whitelist/<u>
#   GET    https://api.meethue.com/route/api/0/config             (whitelist may be filtered/omitted)
#
# NOTE:
#   - Remote list may be filtered; local /config is authoritative for "full" whitelist.
#   - Remote username and local username can differ for the same logical app key.
#   - Active-key flipping is used to map remote<->local usernames without relying on last-use.
#
# IMPORTANT CONVENTIONS (as discussed):
#   - listUsers ALWAYS returns FULL rows with 6 columns:
#       {local_username remote_username devicetype created last_use clientkey}
#     last_use and/or clientkey may be "", but the columns are always present.
#   - clientkey is cached durably and NEVER cleared by -force.
#     It is only removed when the user/key is deleted.
#   - unified cache is cleared when deletions happen.

package require json

namespace eval ::hue::users {
    # Unified mapping cache only
    variable unifiedRows {}          ;# list of rows (see listUsers)
    variable unifiedLoaded 0
    variable unifiedLastLoad 0
    variable unifiedCacheTTL 2592000 ;# 30 days

    # Persistent clientkey cache (never cleared by -force)
    variable clientKeyLoaded 0
    variable clientKeyByUser
    catch {unset clientKeyByUser}
    array set clientKeyByUser {}

    # Optional scratch vars (used by some helpers)
    variable _savedMode ""
    variable _savedKey  ""
}

# -----------------------------
# small helpers
# -----------------------------
proc ::hue::users::_mode {} {
    set m [::hue::config get -mode]
    set m [string tolower [string trim $m]]
    if {$m eq ""} { set m "local" }
    return $m
}

proc ::hue::users::_redact {s {keep 10}} {
    set s [string trim $s]
    if {$s eq ""} { return "" }
    if {[string length $s] <= $keep} { return "***" }
    return "[string range $s 0 [expr {$keep-1}]]…"
}

# Minimal JSON string escaping for devicetype
proc ::hue::users::_jsonEscape {s} {
    # escape backslash and quote; keep it simple
    set s [string map {\\ \\\\ \" \\\"} $s]
    return $s
}

# Join key for matching WITHOUT last use (as requested)
proc ::hue::users::_joinKeyNoLastUse {info} {
    set name ""; set create ""
    if {[dict exists $info name]} { set name [dict get $info name] }
    if {[dict exists $info {create date}]} { set create [dict get $info {create date}] }
    return "${name}\u001F${create}"
}

# -----------------------------
# unified cache file
# -----------------------------
proc ::hue::users::unifiedCacheFile {} {
    ::hue::ensureCacheDirExists
    return [file join [::hue::cacheDir] "hue_users_unified_cache.tcl"]
}

proc ::hue::users::unifiedClearCache {} {
    # in-memory
    set ::hue::users::unifiedRows {}
    set ::hue::users::unifiedLoaded 0
    set ::hue::users::unifiedLastLoad 0

    # on-disk
    set f [::hue::users::unifiedCacheFile]
    catch { if {[file exists $f]} { file delete -force $f } }
}

proc ::hue::users::unifiedSaveCache {} {
    set f [::hue::users::unifiedCacheFile]
    set ch [open $f w]
    fconfigure $ch -translation lf
    puts $ch "namespace eval ::hue::users {"
    puts $ch "  set unifiedLoaded 1"
    puts $ch "  set unifiedLastLoad [list $::hue::users::unifiedLastLoad]"
    puts $ch "  set unifiedRows [list $::hue::users::unifiedRows]"
    puts $ch "}"
    close $ch
}

proc ::hue::users::unifiedLoadCache {} {
    set f [::hue::users::unifiedCacheFile]
    if {![file exists $f]} { return 0 }
    if {[catch {source $f}]} { return 0 }
    if {![info exists ::hue::users::unifiedRows]}     { set ::hue::users::unifiedRows {} }
    if {![info exists ::hue::users::unifiedLoaded]}   { set ::hue::users::unifiedLoaded 0 }
    if {![info exists ::hue::users::unifiedLastLoad]} { set ::hue::users::unifiedLastLoad 0 }
    return [expr {$::hue::users::unifiedLoaded ? 1 : 0}]
}

# -----------------------------
# LOCAL v1 direct whitelist fetch with an explicit key
# (this is the key-flip primitive)
# -----------------------------
proc ::hue::users::_localWhitelistWithKey {key} {
    # save current config so we restore exactly afterwards
    set savedMode [::hue::config get -mode]
    set savedKey  [::hue::config get -key]

    # force local + override key
    ::hue::config set -mode local -key $key

    set bridge [::hue::config get -bridge]
    if {$bridge eq ""} {
        catch { ::hue::config set -mode $savedMode -key $savedKey }
        ::hue::softError "Missing local -bridge (env config.hue.tcl)."
    }

    set url "https://$bridge/api/$key/config"
    set body [exec curl -sS -k $url]

    if {[catch {json::json2dict $body} cfg]} {
        catch { ::hue::config set -mode $savedMode -key $savedKey }
        ::hue::softError "Local /config invalid JSON (key=$key): $body"
    }
    if {![dict exists $cfg whitelist]} {
        catch { ::hue::config set -mode $savedMode -key $savedKey }
        ::hue::softError "Invalid Hue v1 response: /config has no whitelist (key=$key)"
    }

    set wl [dict get $cfg whitelist]

    # restore previous mode/key
    catch { ::hue::config set -mode $savedMode -key $savedKey }

    return $wl
}

# -----------------------------------------------------------------------------
# Persistent clientkey cache (NEVER cleared by -force)
# Cleared ONLY when a user/key is deleted.
# Stores: clientKeyByUser(<remote_or_local_username>) = <clientkey>
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# Persistent clientkey cache (REMOTE USERNAME ONLY)
# Cleared ONLY when a remote user/key is deleted.
# Stores: clientKeyByRemote(<remote_username>) = <clientkey>
# -----------------------------------------------------------------------------

proc ::hue::users::clientKeyCacheFile {} {
    ::hue::ensureCacheDirExists
    return [file join [::hue::cacheDir] "hue_users_clientkeys_cache.tcl"]
}

proc ::hue::users::clientKeyEnsureLoaded {} {
    if {[info exists ::hue::users::clientKeyLoaded] && $::hue::users::clientKeyLoaded} {
        return
    }
    set ::hue::users::clientKeyLoaded 0
    catch {unset ::hue::users::clientKeyByRemote}
    array set ::hue::users::clientKeyByRemote {}

    set f [::hue::users::clientKeyCacheFile]
    if {![file exists $f]} {
        set ::hue::users::clientKeyLoaded 1
        return
    }
    if {[catch {source $f}]} {
        set ::hue::users::clientKeyLoaded 1
        return
    }
    if {![info exists ::hue::users::clientKeyByRemote]} {
        array set ::hue::users::clientKeyByRemote {}
    }
    set ::hue::users::clientKeyLoaded 1
}

proc ::hue::users::clientKeySave {} {
    ::hue::users::clientKeyEnsureLoaded
    set f [::hue::users::clientKeyCacheFile]
    set ch [open $f w]
    fconfigure $ch -translation lf
    puts $ch "namespace eval ::hue::users {"
    puts $ch "  set clientKeyLoaded 1"
    puts $ch "  catch {unset clientKeyByRemote}; array set clientKeyByRemote [list [array get ::hue::users::clientKeyByRemote]]"
    puts $ch "}"
    close $ch
}

# Remember a clientkey for ONE remote username (remote is the canonical id).
proc ::hue::users::clientKeyRemember {remoteUsername clientkey} {
    set remoteUsername [string trim $remoteUsername]
    set clientkey      [string trim $clientkey]
    if {$remoteUsername eq ""} { return }
    if {$clientkey eq ""} { return }
    ::hue::users::clientKeyEnsureLoaded
    set ::hue::users::clientKeyByRemote($remoteUsername) $clientkey
    catch { ::hue::users::clientKeySave }
}

# Get cached clientkey for a remote username (exact or prefix).
proc ::hue::users::clientKeyGet {remotePattern} {
    set remotePattern [string tolower [string trim $remotePattern]]
    if {$remotePattern eq ""} { return "" }
    ::hue::users::clientKeyEnsureLoaded

    # exact first
    foreach u [array names ::hue::users::clientKeyByRemote] {
        if {[string tolower $u] eq $remotePattern} {
            return $::hue::users::clientKeyByRemote($u)
        }
    }
    # prefix fallback
    foreach u [array names ::hue::users::clientKeyByRemote] {
        if {[string match "${remotePattern}*" [string tolower $u]]} {
            return $::hue::users::clientKeyByRemote($u)
        }
    }
    return ""
}

# Remove cached clientkey entry for a remote username (call after successful deleteRemote).
proc ::hue::users::clientKeyForget {remoteUsername} {
    set remoteUsername [string trim $remoteUsername]
    if {$remoteUsername eq ""} { return }
    ::hue::users::clientKeyEnsureLoaded
    catch {unset ::hue::users::clientKeyByRemote($remoteUsername)}
    catch { ::hue::users::clientKeySave }
}

# Add/overwrite a known clientkey in the persistent cache.
# Usage:
#   ::hue::users::clientKeyAdd <clientkey> <username1> ?<username2> ...?
# You can pass remote username, local username, or both.
proc ::hue::users::clientKeyAdd {remoteUsername clientkey} {
    ::hue::users::clientKeyRemember $remoteUsername $clientkey
}
# -----------------------------
# REMOTE list helper (via core proxy procs)
# -----------------------------
proc ::hue::users::_remoteListAll {} {
    set body [::hue::httpGetRemoteV1 "/config"]
    if {[catch {json::json2dict $body} cfg]} {
        ::hue::softError "Remote /config invalid JSON: $body"
    }

    if {![dict exists $cfg whitelist]} {
        ::hue::softError "Remote /config has no whitelist (filtered/omitted). Cannot build unified mapping from remote side."
    }

    set wl [dict get $cfg whitelist]
    set out {}
    foreach uname [dict keys $wl] {
        lappend out [list $uname [dict get $wl $uname]]
    }
    return [lsort -index 0 $out]
}

# -----------------------------
# Devicetype helper
# -----------------------------
proc ::hue::users::makeDevicetype {{app "tcl-hue"} {device ""}} {
    if {$device eq ""} {
        set device [info hostname]
    }

    set app    [string trim $app]
    set device [string trim $device]

    regsub -all {\s+} $app "_" app
    regsub -all {\s+} $device "_" device

    set dt "$app#$device"

    if {[string length $dt] > 40} {
        set dt [string range $dt 0 39]
    }
    return $dt
}

# -----------------------------
# CREATE helpers returning dict {username ... clientkey ...}
# -----------------------------
proc ::hue::users::createInfoRemote {devicetype {generateclientkey 1}} {
    # you already have this core helper (as used in your file)
    ::hue::remoteLinkButton

    set devicetype [::hue::users::_jsonEscape [string trim $devicetype]]
    set parts [list "\"devicetype\":\"$devicetype\""]
    if {$generateclientkey} { lappend parts "\"generateclientkey\":true" }
    set json "{[join $parts ,]}"

    set body [::hue::httpPostJsonRemoteV1No0 $json]
    if {[string first "\"error\"" $body] >= 0} {
        ::hue::softError "Hue remote v1 error: $body"
    }
    if {[catch {json::json2dict $body} resp]} {
        ::hue::softError "Remote create invalid JSON: $body"
    }

    set username ""
    set clientkey ""
    foreach item $resp {
        if {[dict exists $item success username]}  { set username  [dict get $item success username] }
        if {[dict exists $item success clientkey]} { set clientkey [dict get $item success clientkey] }
    }
    if {$username eq ""} {
        ::hue::softError "Remote create did not return a username. Raw response: $body"
    }

    ::hue::users::clientKeyRemember $username $clientkey
    return [dict create username $username clientkey $clientkey]
}

proc ::hue::users::createInfoLocal {devicetype {generateclientkey 1}} {
    set bridge [::hue::config get -bridge]
    if {$bridge eq ""} {
        ::hue::softError "Missing local -bridge. (env config.hue.tcl)"
    }

    puts "Waiting 5 seconds for the Hue LINK BUTTON window..."
    after 5000

    set url [format {https://%s/api} $bridge]

    # build JSON safely
    set json [format {{"devicetype":"%s"%s}} \
        $devicetype \
        [expr {$generateclientkey ? {,"generateclientkey":true} : {}}]
    ]

    set body [exec curl -sS -k -X POST \
        -H "Content-Type: application/json" \
        -d $json $url]

    # If link button was NOT pressed, Hue returns an "error" (often type 101)
    if {[string first "\"error\"" $body] >= 0} {
        if {[catch {json::json2dict $body} resp]} {
            ::hue::softError "Hue v1 error (non-JSON): $body"
        }
        # find the first error description (usually "link button not pressed")
        set desc ""
        foreach item $resp {
            if {[dict exists $item error description]} {
                set desc [dict get $item error description]
                break
            }
        }
        if {$desc eq ""} { set desc $body }

        ::hue::softError "Hue v1 create failed (did you press the blue link button?): $desc"
    }
    set resp [json::json2dict $body]
    set username ""
    set clientkey ""
    foreach item $resp {
        if {[dict exists $item success username]}  { set username  [dict get $item success username] }
        if {[dict exists $item success clientkey]} { set clientkey [dict get $item success clientkey] }
    }
    if {$username eq ""} {
        ::hue::softError "Create did not return a username. Raw response: $body"
    }

    ::hue::users::clientKeyRemember $username $clientkey
    return [dict create username $username clientkey $clientkey]
}

# Convenience wrapper (returns dict; matches your current behavior)
proc ::hue::users::create {devicetype {generateclientkey 0}} {
    if {[::hue::users::_mode] eq "remote"} {
        return [::hue::users::createInfoRemote $devicetype $generateclientkey]
    }
    return [::hue::users::createInfoLocal $devicetype $generateclientkey]
}

# -----------------------------
# DELETE (remote only, as you observed local delete is unauthorized)
# -----------------------------
proc ::hue::users::deleteRemote {remoteUsername} {
    set body [::hue::httpDeleteRemoteV1 "/config/whitelist/$remoteUsername"]
    if {[string first "\"error\"" $body] >= 0} {
        ::hue::softError "Hue remote v1 error: $body"
    }

    # Clear durable clientkey for this username ONLY after successful delete
    # after success:
    ::hue::users::clientKeyForget $remoteUsername
    catch { ::hue::users::unifiedClearCache }
    return [json::json2dict $body]
}

proc ::hue::users::deleteByDevice {pattern args} {
    set pattern [string tolower [string trim $pattern]]
    if {$pattern eq ""} { return {} }
    set lc [string range $pattern end end]
    if {"$lc" != "*" } {
        set pattern "$pattern*"
    }
    set deleteAll 0
    set force 0

    foreach a $args {
        switch -- $a {
            -all   { set deleteAll 1 }
            -force { set force 1 }
            default {
                ::hue::softError "Usage: deleteByDevice <pattern> ?-all? ?-force?"
            }
        }
    }

    set rows [::hue::users::listUsers $force]

    set matches {}
    foreach r $rows {
        set remote [lindex $r 1]
        set device [string tolower [lindex $r 2]]
        if {[string match $pattern $device]} {
            lappend matches $remote
        }
    }

    if {[llength $matches] == 0} {
        return {}
    }

    if {!$deleteAll && [llength $matches] > 1} {
        ::hue::softError "deleteByDevice: pattern '$pattern' matches multiple users. Use -all to delete all."
    }

    set deleted {}
    foreach remoteUser $matches {
        ::hue::users::deleteRemote $remoteUser
        lappend deleted $remoteUser
    }

    # extra safety: ensure unified cache invalid
    catch { ::hue::users::unifiedClearCache }

    return $deleted
}

proc ::hue::users::delete {username} {
    # You confirmed local delete isn't allowed; always remote delete.
    return [::hue::users::deleteRemote $username]
}

# -----------------------------
# Unified mapping by flip (CACHED)
# Rows are ALWAYS:
#   {local_username remote_username devicetype created last_use clientkey}
# -----------------------------
proc ::hue::users::listUsers {{force 0} {withLastUse 0}} {
    # withLastUse is kept for API-compatibility, but we ALWAYS store/return last_use anyway.
    # (last_use is cheap to fetch from the remote list you already do)

    if {![info exists ::hue::users::unifiedLoaded]}   { set ::hue::users::unifiedLoaded 0 }
    if {![info exists ::hue::users::unifiedLastLoad]} { set ::hue::users::unifiedLastLoad 0 }
    if {![info exists ::hue::users::unifiedCacheTTL]} { set ::hue::users::unifiedCacheTTL 2592000 }

    # Try load unified cache from disk
    if {!$force && !$::hue::users::unifiedLoaded} {
        catch { ::hue::users::unifiedLoadCache }
    }

    # If cached and fresh, rehydrate clientkeys from durable cache and return FULL rows
    if {!$force && $::hue::users::unifiedLoaded} {
        set age [expr {[clock seconds] - $::hue::users::unifiedLastLoad}]
        if {$age < $::hue::users::unifiedCacheTTL} {

            catch { ::hue::users::clientKeyEnsureLoaded }

            set newRows {}
            foreach r $::hue::users::unifiedRows {
                # expected: {local remote dev created last_use clientkey}
                set ru [lindex $r 1]
                set lu [lindex $r 0]
                set ck [lindex $r 5]

                if {$ck eq ""} {
                    if {$ru ne "" && [info exists ::hue::users::clientKeyByUser($ru)]} {
                        set ck $::hue::users::clientKeyByUser($ru)
                        lset r 5 $ck
                    } elseif {$lu ne "" && [info exists ::hue::users::clientKeyByUser($lu)]} {
                        set ck $::hue::users::clientKeyByUser($lu)
                        lset r 5 $ck
                        # link remote too (durable)
                        if {$ru ne ""} { ::hue::users::clientKeyRemember $ck $ru }
                    }
                }

                # if we have ck, keep both ids linked durably
                if {$ck ne ""} {
                    if {$ru ne ""} { ::hue::users::clientKeyRemember $ck $ru }
                    if {$lu ne ""} { ::hue::users::clientKeyRemember $ck $lu }
                }

                lappend newRows $r
            }
            set ::hue::users::unifiedRows $newRows

            return $::hue::users::unifiedRows
        }
    }

    # Save current mode/key; must restore exactly
    set savedMode [::hue::config get -mode]
    set savedKey  [::hue::config get -key]

    # 1) Remote usernames (active key doesn't matter)
    ::hue::config set -mode remote
    set remotePairs [::hue::users::_remoteListAll]  ;# list of {ru info}

    if {[llength $remotePairs] < 2} {
        catch { ::hue::config set -mode $savedMode -key $savedKey }
        ::hue::softError "Need at least 2 remote keys to build mapping by flipping."
    }

    # remoteInfo(ru)=info and ordered list of ru
    array set remoteInfo {}
    set remoteUList {}
    foreach p $remotePairs {
        lassign $p ru info
        set remoteInfo($ru) $info
        lappend remoteUList $ru
    }

    # 2) Flip cycle: derive local id for each remote id by switching to another remote key
    array set mapRemoteToLocal {}
    set n [llength $remoteUList]

    for {set i 0} {$i < $n} {incr i} {
        set ra [lindex $remoteUList $i]
        set rb [lindex $remoteUList [expr {($i+1) % $n}]]

        set wlA [::hue::users::_localWhitelistWithKey $ra]
        set wlB [::hue::users::_localWhitelistWithKey $rb]

        if {![dict exists $wlA $ra]} {
            continue
        }

        set infoA [dict get $wlA $ra]
        set jkA   [::hue::users::_joinKeyNoLastUse $infoA]

        set foundLocal ""
        foreach u [dict keys $wlB] {
            set infoB [dict get $wlB $u]
            if {[::hue::users::_joinKeyNoLastUse $infoB] eq $jkA} {
                if {$u ne $ra} { set foundLocal $u ; break }
            }
        }
        if {$foundLocal eq ""} {
            foreach u [dict keys $wlB] {
                set infoB [dict get $wlB $u]
                if {[::hue::users::_joinKeyNoLastUse $infoB] eq $jkA} {
                    set foundLocal $u
                    break
                }
            }
        }

        if {$foundLocal ne ""} {
            set mapRemoteToLocal($ra) $foundLocal
        }
    }

    # 3) Emit unified rows (ALWAYS 6 columns)
    catch { ::hue::users::clientKeyEnsureLoaded }

    set rows {}
    foreach ru $remoteUList {
        set info $remoteInfo($ru)

        set dev ""; set create ""; set lastuse ""
        if {[dict exists $info name]}          { set dev    [dict get $info name] }
        if {[dict exists $info {create date}]} { set create [dict get $info {create date}] }
        if {[dict exists $info {last use date}]} { set lastuse [dict get $info {last use date}] }

        set lu ""
        if {[info exists mapRemoteToLocal($ru)]} { set lu $mapRemoteToLocal($ru) }

        # clientkey: prefer remote id, then local id; and link both ids durably
        set ck ""
        if {[info exists ::hue::users::clientKeyByRemote($ru)]} {
            set ck $::hue::users::clientKeyByRemote($ru)
        } elseif {$lu ne "" && [info exists ::hue::users::clientKeyByRemote($ru)]} {
            set ck $::hue::users::clientKeyByUser($lu)
            ::hue::users::clientKeyRemember $ck $ru
        }
        if {$ck ne "" && $lu ne ""} {
            ::hue::users::clientKeyRemember $ck $lu
        }

        lappend rows [list $lu $ru $dev $create $lastuse $ck]
    }

    # Restore config exactly as it was
    catch { ::hue::config set -mode $savedMode -key $savedKey }

    # Cache result
    set ::hue::users::unifiedRows $rows
    set ::hue::users::unifiedLoaded 1
    set ::hue::users::unifiedLastLoad [clock seconds]
    catch { ::hue::users::unifiedSaveCache }

    return $rows
}

# -----------------------------
# printUsers (options + sort + csv)
# -----------------------------
proc ::hue::users::printUsers {args} {
    # Defaults
    set matchPat ""
    set notPat ""
    set devPat ""
    set onlyHasClientKey 0
    set onlyNoClientKey 0
    set force 0
    set withLastUse 0
    set withClientKey 0
    set withLocal 0
    set withCreated 0
    set delimiter ""
    set sortSpec ""

    set i 0
    while {$i < [llength $args]} {
        set a [lindex $args $i]
        switch -nocase -exact -- $a {
            -match     { incr i; set matchPat  [lindex $args $i] }
            -not       { incr i; set notPat    [lindex $args $i] }
            -dev       { incr i; set devPat    [lindex $args $i] }
            -hasclientkey { set onlyHasClientKey 1 ; set withClientKey 1  }
            -noclientkey  { set onlyNoClientKey 1 }
            -force      { set force 1 }
            -lastuse    { set withLastUse 1 }
            -clientkey  { set withClientKey 1 }
            -local      { set withLocal 1 }
            -created    { set withCreated 1 }
            -csv        { incr i; set delimiter [lindex $args $i] }
            -sort       { incr i; set sortSpec [lindex $args $i] }
            ""          { incr i}
            default {
                if {$sortSpec eq ""} {
                    set sortSpec $a
                } else {
                    ::hue::softError "printUsers: unknown arg '$a'"
                }
            }
        }
        incr i
    }

    # listUsers ALWAYS returns FULL rows:
    # {local remote devicetype created last_use clientkey}
    set rows [::hue::users::listUsers $force]
    # --------------------------------------------------
    # Filtering (case-insensitive, glob patterns)
    # --------------------------------------------------
    if {$onlyHasClientKey && $onlyNoClientKey} {
        ::hue::softError "printUsers: -hasclientkey and -noclientkey are mutually exclusive"
    }

    # normalize patterns to lowercase once
    set matchPat  [string tolower [string trim $matchPat]]
    set notPat    [string tolower [string trim $notPat]]
    set devPat    [string tolower [string trim $devPat]]

    if {$matchPat ne "" || $notPat ne "" || $devPat ne "" || $onlyHasClientKey || $onlyNoClientKey} {
        set filtered {}
        foreach r $rows {
            set local  [string tolower [lindex $r 0]]
            set remote [string tolower [lindex $r 1]]
            set dev    [string tolower [lindex $r 2]]
            set ck     [string trim [lindex $r 5]]

            # include tests
            if {$matchPat ne ""} {
                if {![string match $matchPat $local] && ![string match $matchPat $remote] && ![string match $matchPat $dev]} {
                    continue
                }
            }
            if {$devPat ne "" && ![string match $devPat $dev]} { continue }

            if {$onlyHasClientKey && $ck eq ""} { continue }
            if {$onlyNoClientKey  && $ck ne ""} { continue }

            # exclude tests
            if {$notPat ne ""} {
                if {[string match $notPat $local] || [string match $notPat $remote] || [string match $notPat $dev]} {
                    continue
                }
            }

            lappend filtered $r
        }
        set rows $filtered
    }

    # --------------------------------------------------
    # Column descriptor list
    # each entry = {header fullRowIndex}
    # FULL ROW indices:
    # 0 local, 1 remote, 2 devicetype, 3 created, 4 last_use, 5 clientkey
    # --------------------------------------------------
    set colDefs {}

    if {$withLocal} {
        lappend colDefs [list local_username 0]
    }

    lappend colDefs [list remote_username 1]
    lappend colDefs [list devicetype 2]

    if {$withCreated} {
        lappend colDefs [list created 3]
    }

    if {$withLastUse} {
        lappend colDefs [list last_use 4]
    }

    if {$withClientKey} {
        lappend colDefs [list clientkey 5]
    }

    # derive headers + column count
    set headers {}
    foreach c $colDefs { lappend headers [lindex $c 0] }
    set cols [llength $colDefs]

    # map printed col -> value from FULL row
    # Full row indices: 0 local, 1 remote, 2 dev, 3 created, 4 last_use, 5 clientkey
    proc ::hue::users::_colVal {row colIdx colDefs} {
        set fullIdx [lindex [lindex $colDefs $colIdx] 1]
        return [lindex $row $fullIdx]
    }

    # Sort parsing (1..N, optional -, optional r)
    array set redactCol {}
    set sortTokens {}

    if {$sortSpec ne ""} {
        foreach tok [split $sortSpec ","] {
            set tok [string trim $tok]
            if {$tok eq ""} continue

            set re [format {^(-?)([1-%d])(r?)$} $cols]
            if {![regexp $re $tok -> sign col rflag]} {
                ::hue::softError "printUsers: invalid sort token '$tok' (allowed 1..$cols, optional -, optional r)"
            }

            if {$rflag eq "r"} {
                set redactCol([expr {$col - 1}]) 1
            }
            lappend sortTokens [list $sign $col]
        }

        # stable multi-sort: apply right-to-left
        foreach spec [lreverse $sortTokens] {
            lassign $spec sign col
            set idx [expr {$col - 1}]

            set tmp {}
            foreach r $rows {
                set key [::hue::users::_colVal $r $i $colDefs]
                lappend tmp [list $key $r]
            }

            if {$sign eq "-"} {
                set tmp [lsort -dictionary -decreasing -index 0 $tmp]
            } else {
                set tmp [lsort -dictionary -index 0 $tmp]
            }

            set newRows {}
            foreach t $tmp { lappend newRows [lindex $t 1] }
            set rows $newRows
        }
    }

    # Redaction helper
    proc ::hue::users::_pp {idx val} {
        if {[info exists ::hue::users::redactCol($idx)] && $::hue::users::redactCol($idx)} {
            return [::hue::users::_redact $val]
        }
        return $val
    }
    catch {unset ::hue::users::redactCol}
    array set ::hue::users::redactCol [array get redactCol]

    # CSV-like output
    if {$delimiter ne ""} {
        puts [join $headers $delimiter]
        foreach r $rows {
            set out {}
            for {set i 0} {$i < $cols} {incr i} {
                set v [::hue::users::_colVal $r $i $colDefs]
                set v [::hue::users::_pp $i $v]
                lappend out $v
            }
            puts [join $out $delimiter]
        }
        catch {unset ::hue::users::redactCol}
        return
    }

    # dynamic widths
    set widths {}
    for {set i 0} {$i < $cols} {incr i} {
        lappend widths [string length [lindex $headers $i]]
    }
    foreach r $rows {
        for {set i 0} {$i < $cols} {incr i} {
            set v [::hue::users::_colVal $r $i $colDefs]
            set v [::hue::users::_pp $i $v]
            set L [string length $v]
            if {$L > [lindex $widths $i]} { lset widths $i $L }
        }
    }

    set fmt ""
    for {set i 0} {$i < $cols} {incr i} {
        append fmt "%-[lindex $widths $i]s"
        if {$i < ($cols-1)} { append fmt " " }
    }

    set sepLen [expr {$cols - 1}]
    foreach w $widths { incr sepLen $w }

    puts [format $fmt {*}$headers]
    puts [string repeat "-" $sepLen]

    foreach r $rows {
        set out {}
        for {set i 0} {$i < $cols} {incr i} {
            set v [::hue::users::_colVal $r $i $colDefs]
            set v [::hue::users::_pp $i $v]
            lappend out $v
        }
        puts [format $fmt {*}$out]
    }

    catch {unset ::hue::users::redactCol}
}

# ------------------------------------------------------------
# get <pattern>
# - case-insensitive prefix match against: local OR remote OR devicetype
# - returns first match only, or "" (no error, no list)
# - default return is remote username
# ------------------------------------------------------------
proc ::hue::users::get {pattern {which ""} {force 0}} {
    set pattern [string tolower [string trim $pattern]]
    if {$pattern eq ""} { return "" }

    set w [string tolower [string trim $which]]
    set wantAll 0
    set wantLocal 0
    set wantDevice 0
    set wantCreate 0
    if {$w ne ""} {
        if {$w eq "0" || [string match "a*" $w]} {
            set wantAll 1
        } elseif {$w eq "1" || [string match "l*" $w]} {
            set wantLocal 1
        } elseif {$w eq "2" || [string match "d*" $w]} {
            set wantDevice 1
        } elseif {$w eq "3" || [string match "c*" $w]} {
            set wantCreate 1
        }
    }

    # rows are FULL rows; we use only base fields here
    set rows [::hue::users::listUsers $force]

    foreach r $rows {
        set local  [lindex $r 0]
        set remote [lindex $r 1]
        set device [lindex $r 2]
        set create [lindex $r 3]

        if {[string match "${pattern}*" [string tolower $local]] ||
            [string match "${pattern}*" [string tolower $remote]] ||
            [string match "${pattern}*" [string tolower $device]]} {

            if {$wantLocal}  { return $local }
            if {$wantDevice} { return $device }
            if {$wantCreate} { return $create }
            if {$wantAll}    { return [list $remote $local $device $create] }
            return $remote
        }
    }
    return ""
}

# ------------------------------------------------------------
# oppositeKey <key> ?force?
# - if key is local -> return remote
# - if key is remote -> return local
# - returns "" if not found
# ------------------------------------------------------------
proc ::hue::users::oppositeKey {key {force 0}} {
    set key [string trim $key]
    if {$key eq ""} { return "" }
    set keyL [string tolower $key]

    set rows [::hue::users::listUsers $force]
    foreach row $rows {
        set local  [string tolower [lindex $row 0]]
        set remote [string tolower [lindex $row 1]]

        if {$keyL eq $local}  { return [lindex $row 1] }
        if {$keyL eq $remote} { return [lindex $row 0] }
    }
    return ""
}

# -----------------------------
# Compatibility wrappers (naming only)
# -----------------------------
proc ::hue::users::listV2   {{what all}} { return [::hue::users::listUsers 0] }
proc ::hue::users::createV2 {devicetype {generateclientkey 0}} { return [::hue::users::create $devicetype $generateclientkey] }
proc ::hue::users::deleteV2 {username} { return [::hue::users::delete $username] }

# -----------------------------
# help
# -----------------------------
proc ::hue::users::help {} {
    puts "Hue Users (unified local<->remote whitelist) - ::hue::users::*"
    puts ""

    puts "Unified listing (cached; slow to build without cache):"
    puts "  ::hue::users::listUsers ?force?"
    puts "      force: 0/1  (1 = rebuild now; ignore cache)"
    puts "      Returns FULL rows (always cached):"
    puts "        {local_username remote_username devicetype created last_use clientkey}"
    puts ""

    puts "Printing (recommended):"
    puts "  ::hue::users::printUsers ?options...? ?sortSpec?"
    puts ""

    puts "printUsers options:"
    puts "  -force             Rebuild unified mapping now (ignore cache)"
    puts "  -csv <delimiter>   Delimited output instead of aligned columns"
    puts ""
    puts "Column selection (all are OPT-IN, default is minimal view):"
    puts "  -local             Show local_username column"
    puts "  -created           Show created column"
    puts "  -lastuse           Show last_use column"
    puts "  -clientkey         Show clientkey column"
    puts "  -hasClientKey      Filter: only rows with clientkey != \"\" (also implies -clientkey)"
    puts ""
    puts "Default columns (no flags):"
    puts "  1) remote_username"
    puts "  2) devicetype"
    puts ""
    puts "If you add optional columns, the printed column order is:"
    puts "  (optional) local_username"
    puts "            remote_username"
    puts "            devicetype"
    puts "  (optional) created"
    puts "  (optional) last_use"
    puts "  (optional) clientkey"
    puts ""
    puts "sortSpec (optional):"
    puts "  Comma-separated column numbers referring to the PRINTED columns."
    puts "  Use '-' for descending. Use 'r' to redact that column via ::hue::users::_redact."
    puts "  Examples:"
    puts "    1            sort by column 1 asc"
    puts "    -2           sort by column 2 desc"
    puts "    2,3          sort by col2 asc, then col3 asc"
    puts "    3,-2r        sort by col3 asc, then col2 desc and redact col2"
    puts "    1r           sort by col1 asc and redact col1"
    puts ""

    puts "printUsers examples:"
    puts "  ::hue::users::printUsers"
    puts "  ::hue::users::printUsers -local"
    puts "  ::hue::users::printUsers -created -sort 2"
    puts "  ::hue::users::printUsers -clientkey -sort 3"
    puts "  ::hue::users::printUsers -hasClientKey -sort -1"
    puts "  ::hue::users::printUsers -local -created -lastuse -clientkey -sort 2,1"
    puts "  ::hue::users::printUsers -csv \";\" -clientkey -sort 1"
    puts ""

    puts "Convenience getters (case-insensitive; return \"\" on no match; no errors):"
    puts ""
    puts "  ::hue::users::get <pattern> ?which? ?force?"
    puts "    pattern: prefix matched against local_username OR remote_username OR devicetype"
    puts "    which:"
    puts "      (empty)        -> remote_username"
    puts "      all / a* / 0   -> {remote local devicetype created}"
    puts "      local / l* / 1 -> local_username"
    puts "      device / d* / 2-> devicetype"
    puts "      create / c* / 3-> created timestamp"
    puts "    force: 0=use cache, 1=rebuild now"
    puts ""
    puts "  ::hue::users::oppositeKey <key> ?force?"
    puts "      If key is local -> return remote, if key is remote -> return local."
    puts ""

    puts "Create users (returns dict {username ... clientkey ...}):"
    puts "  ::hue::users::createInfoLocal  <devicetype> ?generateclientkey 0|1?"
    puts "  ::hue::users::createInfoRemote <devicetype> ?generateclientkey 0|1?"
    puts ""
    puts "Create/delete convenience:"
    puts "  ::hue::users::create <devicetype> ?generateclientkey 0|1?"
    puts "  ::hue::users::delete <username>    ;# remote delete"
    puts ""
    puts "Bulk delete by devicetype pattern:"
    puts "  ::hue::users::deleteByDevice <pattern> ?-all? ?-force?"
    puts ""

    puts "Notes:"
    puts "  - Local and remote usernames differ per app key; devicetype+create date match."
    puts "  - last use date changes for the active key (expected). Use -force + -lastuse to refresh."
    puts "  - Unified mapping is built by key-flipping; cached to avoid repeated slow rebuilds."
    puts "  - clientkey is persisted in a separate cache and is NOT cleared by -force; only on delete."
}
