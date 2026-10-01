# hue.inc.core.tcl  (Tcl 8.5)
#
# Shared Hue configuration, cache directory, helpers, loader, and env/token handling.
#
# Usage (local):
#   source hue.inc.core.tcl
#   ::hue::config                 ;# loads env and defaults to local (bridge/key from env)
#   ::hue::ensureLoaded light|group|user|all ?reset?
#
# Usage (remote / official Hue cloud):
#   source hue.inc.core.tcl
#   ::hue::config set -mode remote
#   ::hue::ensureLoaded light|group|all ?reset?
#
# Notes:
#   - Remote mode uses:
#       Authorization: Bearer <accessToken>
#       hue-application-key: <key>   (same key as local application key / whitelist username)
#     and base https://api.meethue.com/route/...
#   - Tokens/client secrets are ALWAYS read from ./env (master), never cached.
#   - Token refresh is implemented (refresh on demand) using ./env/.../hue_remote_env
#
# Env layout (relative to this file's directory):
#   ./env/.appid                         -> one line: <appid>
#   ./env/<appid>/app_env                -> CLIENTID="..." and CLIENTSECRET="..."
#   ./env/<appid>/config.hue.tcl         -> set user ..., set ip ..., set id ...
#   ./env/<appid>/hue_remote_env         -> ACCESS_TOKEN=..., REFRESH_TOKEN=..., EXPIRES_AT=... # (...)
#
# The hue_remote_env file format is preserved when updating tokens.
#
# PATCH (key/env precedence):
#   - config.hue.tcl is ALWAYS read (master) for bridge/key
#   - BUT if user explicitly does ::hue::config set -key <...>, that key overrides env
#   - Key is NOT cached on disk (like tokens), so env edits take effect immediately unless overridden.

namespace eval ::hue {
    # --- connection config ---------------------------------------------
    variable mode "local"          ;# local | remote

    # local
    variable bridge ""
    variable key ""

    # Explicit override (wins over env master)
    variable keyOverride ""
    variable keyOverrideSet 0

    # remote (official Hue cloud API OAuth)
    variable remoteBase "https://api.meethue.com"
    variable accessToken ""
    variable refreshToken ""
    variable clientId ""
    variable clientSecret ""
    variable expiresAt ""          ;# unix epoch (string ok)

    # Token refresh settings
    variable oauthRefreshUrl "https://api.meethue.com/oauth2/refresh"
    variable tokenSkewSeconds 90  ;# refresh a little before expiry

    # Loaded-from-env bookkeeping
    variable envLoaded 0
    variable envAppId ""
    variable envBaseDir ""        ;# .../env
    variable envAppDir ""         ;# .../env/<appid>
    variable envRemoteFile ""     ;# .../hue_remote_env
    variable envAppFile ""        ;# .../app_env
    variable envConfigFile ""     ;# .../config.hue.tcl

    # Track if modules were sourced
    variable lightsLoaded 0
    variable groupsLoaded 0
    variable usersLoaded  0

    # Logging
    variable logEnabled 0
    proc ::hue::setLog {flag} { set ::hue::logEnabled [expr {$flag ? 1 : 0}] }
    proc ::hue::log {msg} { if {$::hue::logEnabled} { puts stderr $msg } }

    # Non-interactive mode:
    variable nonInteractive 0
    proc ::hue::setNonInteractive {flag} { set ::hue::nonInteractive [expr {$flag ? 1 : 0}] }
    proc ::hue::isNonInteractive {} {
        if {$::hue::nonInteractive} { return 1 }
        if {[info exists ::env(HUE_NONINTERACTIVE)] && $::env(HUE_NONINTERACTIVE) ne ""} {
            set v [string tolower [string trim $::env(HUE_NONINTERACTIVE)]]
            if {$v in {1 true yes on}} { return 1 }
        }
        return 0
    }

    # --- filesystem -----------------------------------------------------
    proc scriptDir {} {
        set s [info script]
        if {$s ne ""} { return [file dirname [file normalize $s]] }
        return [pwd]
    }

    proc cacheDir {} { return [file join [::hue::scriptDir] ".resources"] }

    proc ensureCacheDirExists {} {
        set d [::hue::cacheDir]
        if {![file exists $d]} { file mkdir $d }
        if {![file isdirectory $d]} {
            puts stderr "Cache path exists but is not a directory: $d"
            exit 0
        }
    }

    proc softError {msg} { puts stderr $msg ; exit 0 }

    # --- small file helpers --------------------------------------------
    proc _readFileTrim {path} {
        if {![file exists $path]} { return "" }
        set ch [open $path r]
        set data [read $ch]
        close $ch
        set data [string trim $data]
        set line [lindex [split $data "\n"] 0]
        return [string trim $line]
    }

    proc _stripQuotes {s} {
        set t [string trim $s]
        if {[string length $t] >= 2} {
            set a [string index $t 0]
            set b [string index $t end]
            if {($a eq "\"" && $b eq "\"") || ($a eq "'" && $b eq "'")} {
                return [string range $t 1 end-1]
            }
        }
        return $t
    }

    # --- env discovery + loading ---------------------------------------
    proc envBaseDir {} { return [file join [::hue::scriptDir] "env"] }

    proc envDiscover {} {
        set base [::hue::envBaseDir]
        if {![file exists $base]} { return 0 }
        if {![file isdirectory $base]} { return 0 }

        set appid [::hue::_readFileTrim [file join $base ".appid"]]
        if {$appid eq ""} { return 0 }

        set ::hue::envAppId    $appid
        set ::hue::envBaseDir  $base

        set ::hue::envAppDir     [file join $base $appid]
        set ::hue::envAppFile    [file join $::hue::envAppDir "app_env"]
        set ::hue::envRemoteFile [file join $::hue::envAppDir "hue_remote_env"]
        set ::hue::envConfigFile [file join $::hue::envAppDir "config.hue.tcl"]
        return 1
    }

    proc _parseAppEnv {path} {
        # app_env:
        #   CLIENTID="..."
        #   CLIENTSECRET="..."
        if {![file exists $path]} { return }
        set ch [open $path r]
        set data [read $ch]
        close $ch
        foreach line [split $data "\n"] {
            set line [string trim $line]
            if {$line eq ""} continue
            if {[string match "#*" $line]} continue
            if {[regexp {^CLIENTID\s*=\s*(.+)$} $line -> v]} {
                set ::hue::clientId [::hue::_stripQuotes [string trim $v]]
            } elseif {[regexp {^CLIENTSECRET\s*=\s*(.+)$} $line -> v]} {
                set ::hue::clientSecret [::hue::_stripQuotes [string trim $v]]
            }
        }
    }

    proc _parseHueRemoteEnv {path} {
        # hue_remote_env:
        #   ACCESS_TOKEN=...
        #   REFRESH_TOKEN=...
        #   EXPIRES_AT=...   # (...)
        if {![file exists $path]} { return }
        set ch [open $path r]
        set data [read $ch]
        close $ch
        foreach line [split $data "\n"] {
            set line [string trim $line]
            if {$line eq ""} continue
            if {[string match "#*" $line]} continue

            set noC $line
            if {[regexp {^([^#]+)#.*$} $line -> pre]} { set noC [string trim $pre] }

            if {[regexp {^ACCESS_TOKEN\s*=\s*(.+)$} $noC -> v]} {
                set ::hue::accessToken [string trim $v]
            } elseif {[regexp {^REFRESH_TOKEN\s*=\s*(.+)$} $noC -> v]} {
                set ::hue::refreshToken [string trim $v]
            } elseif {[regexp {^EXPIRES_AT\s*=\s*([0-9]+)} $noC -> v]} {
                set ::hue::expiresAt [string trim $v]
            }
        }
    }

    proc _parseConfigHueTcl {path} {
        # config.hue.tcl contains Tcl 'set' lines; parse gently.
        if {![file exists $path]} { return }
        set ch [open $path r]
        set data [read $ch]
        close $ch
        foreach line [split $data "\n"] {
            set line [string trim $line]
            if {$line eq ""} continue
            if {[string match "#*" $line]} continue

            if {[regexp {^set\s+user\s+(.+)$} $line -> v]} {
                set v [string trim $v]
                if {[regexp {^(.+?);.*$} $v -> vv]} { set v [string trim $vv] }
                set v [::hue::_stripQuotes $v]
                if {$v ne "" && $v ne "0"} { set ::hue::key $v }

            } elseif {[regexp {^set\s+ip\s+(.+)$} $line -> v]} {
                set v [string trim $v]
                if {[regexp {^(.+?);.*$} $v -> vv]} { set v [string trim $vv] }
                set v [::hue::_stripQuotes $v]
                if {$v ne "" && $v ne "0.0.0.0"} { set ::hue::bridge $v }

            }
        }
    }

    # Master env load:
    # - config.hue.tcl is master for local bridge/key
    # - app_env is master for clientId/clientSecret
    # - hue_remote_env is master for access/refresh/expiresAt
    #
    # IMPORTANT:
    #   - tokens/secrets are ALWAYS re-read from env on every call.
    #   - config.hue.tcl is ALWAYS read on every call.
    #   - explicit ::hue::config set -key <...> overrides env key (until cleared).
    proc envLoad {{force 0}} {
        # Ensure env paths are discovered at least once, or when forced
        if {!$::hue::envLoaded || $force} {
            if {![::hue::envDiscover]} { return 0 }
        } elseif {$::hue::envRemoteFile eq "" || $::hue::envAppFile eq "" || $::hue::envConfigFile eq ""} {
            if {![::hue::envDiscover]} { return 0 }
        }

        # ALWAYS read config.hue.tcl (master for bridge/key)
        ::hue::_parseConfigHueTcl $::hue::envConfigFile

        # Apply explicit key override if set
        if {$::hue::keyOverrideSet && [string trim $::hue::keyOverride] ne ""} {
            set ::hue::key $::hue::keyOverride
        }

        # For clientId/clientSecret: env is master (always overwrite)
        ::hue::_parseAppEnv $::hue::envAppFile

        # For tokens: env is master (always overwrite)
        ::hue::_parseHueRemoteEnv $::hue::envRemoteFile

        if {$::hue::remoteBase eq ""} { set ::hue::remoteBase "https://api.meethue.com" }

        set ::hue::envLoaded 1
        return 1
    }

    # Convenience: force refresh of everything from env (including bridge/key),
    # while still respecting explicit -key override.
    proc ::hue::envReloadSecrets {} {
        catch { ::hue::envLoad 1 }
        return
    }

    proc _updateHueRemoteEnvFile {access refresh expiresAt} {
        set f $::hue::envRemoteFile
        if {$f eq ""} { return }

        set lines {}
        if {[file exists $f]} {
            set ch [open $f r]
            set data [read $ch]
            close $ch
            set lines [split $data "\n"]
        }

        set haveA 0; set haveR 0; set haveE 0
        set out {}
        foreach line $lines {
            if {[regexp {^\s*ACCESS_TOKEN\s*=} $line]} {
                set suffix ""
                if {[regexp {^(.*?)(\s*#.*)$} $line -> _pre _suf]} { set suffix $_suf }
                lappend out "ACCESS_TOKEN=$access$suffix"
                set haveA 1
            } elseif {[regexp {^\s*REFRESH_TOKEN\s*=} $line]} {
                set suffix ""
                if {[regexp {^(.*?)(\s*#.*)$} $line -> _pre _suf]} { set suffix $_suf }
                lappend out "REFRESH_TOKEN=$refresh$suffix"
                set haveR 1
            } elseif {[regexp {^\s*EXPIRES_AT\s*=} $line]} {
                set suffix ""
                if {[regexp {^(.*?)(\s*#.*)$} $line -> _pre _suf]} { set suffix $_suf }
                lappend out "EXPIRES_AT=$expiresAt$suffix"
                set haveE 1
            } else {
                lappend out $line
            }
        }

        if {!$haveA} { lappend out "ACCESS_TOKEN=$access" }
        if {!$haveR} { lappend out "REFRESH_TOKEN=$refresh" }
        if {!$haveE} { lappend out "EXPIRES_AT=$expiresAt   # (updated)" }

        file mkdir [file dirname $f]
        set ch [open $f w]
        fconfigure $ch -translation lf
        puts -nonewline $ch [join $out "\n"]
        close $ch
    }

    proc ensureFreshAccessToken {} {
        if {$::hue::mode ne "remote"} { return }

        # MASTER READ before doing anything (prevents stale in-memory token)
        catch { ::hue::envLoad 0 }

        # manual token case
        if {$::hue::expiresAt eq ""} { return }

        set now [clock seconds]
        set exp [expr {int($::hue::expiresAt)}]
        if {$now + $::hue::tokenSkewSeconds < $exp} { return }

        if {$::hue::refreshToken eq ""} {
            ::hue::softError "Remote token expired and no REFRESH_TOKEN available (env hue_remote_env)."
        }
        if {$::hue::clientId eq "" || $::hue::clientSecret eq ""} {
            ::hue::softError "Remote token expired and CLIENTID/CLIENTSECRET not available (env app_env)."
        }

        ::hue::log "remote: access token expired/near-expiry -> refreshing"

        set url $::hue::oauthRefreshUrl
        if {[string first "grant_type=" $url] < 0} { append url "?grant_type=refresh_token" }

        set body [exec curl -sS \
            -u "$::hue::clientId:$::hue::clientSecret" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "refresh_token=$::hue::refreshToken" \
            -d "grant_type=refresh_token" \
            $url]

        package require json
        if {[catch {json::json2dict $body} resp]} {
            ::hue::softError "Token refresh failed (invalid JSON): $body"
        }
        if {![dict exists $resp access_token]} {
            ::hue::softError "Token refresh failed (no access_token): $body"
        }

        set newAT [dict get $resp access_token]
        set newRT $::hue::refreshToken
        if {[dict exists $resp refresh_token]} { set newRT [dict get $resp refresh_token] }

        set newExp ""
        if {[dict exists $resp expires_in]} {
            set sec [dict get $resp expires_in]
            set newExp [expr {[clock seconds] + int($sec)}]
        } else {
            set newExp [expr {[clock seconds] + 3600}]
        }

        # update memory + file
        set ::hue::accessToken  $newAT
        set ::hue::refreshToken $newRT
        set ::hue::expiresAt    $newExp

        catch { ::hue::_updateHueRemoteEnvFile $newAT $newRT $newExp }

        # re-read from master to guarantee we match the file
        catch { ::hue::envLoad 0 }

        ::hue::log "remote: token refreshed (expiresAt=$newExp)"
    }

    # --- config ---------------------------------------------------------
    proc ::hue::_setDefaultsFromEnvForLocal {} {
        # "default local" should use env master, so clear explicit key override
        set ::hue::keyOverride ""
        set ::hue::keyOverrideSet 0

        catch { ::hue::envLoad 0 }
        set ::hue::mode "local"
        if {$::hue::remoteBase eq ""} { set ::hue::remoteBase "https://api.meethue.com" }
    }

    proc ::hue::_redact {s {keep 6}} {
        set s [string trim $s]
        if {$s eq ""} { return "" }
        if {[string length $s] <= $keep} { return "***" }
        return "[string range $s 0 [expr {$keep-1}]]…"
    }

    proc ::hue::configSnapshot {{raw 0}} {
        # Always sync from env (master), applying any explicit key override
        catch { ::hue::envLoad 0 }

        set d [dict create]
        dict set d mode $::hue::mode
        dict set d bridge $::hue::bridge
        dict set d key    [expr {$raw ? $::hue::key : [::hue::_redact $::hue::key]}]
        dict set d remoteBase $::hue::remoteBase
        dict set d accessToken  [expr {$raw ? $::hue::accessToken  : [::hue::_redact $::hue::accessToken]}]
        dict set d refreshToken [expr {$raw ? $::hue::refreshToken : [::hue::_redact $::hue::refreshToken]}]
        dict set d clientId     [expr {$raw ? $::hue::clientId     : [::hue::_redact $::hue::clientId]}]
        dict set d clientSecret [expr {$raw ? $::hue::clientSecret : [::hue::_redact $::hue::clientSecret]}]
        dict set d expiresAt    $::hue::expiresAt
        return $d
    }

    proc ::hue::configPrint {{raw 0}} {
        set d [::hue::configSnapshot $raw]
        puts "Hue config snapshot:"
        foreach k [lsort [dict keys $d]] {
            puts [format "  %-15s %s" $k [dict get $d $k]]
        }
    }

    proc ::hue::config {args} {
        # ::hue::config                   -> force local defaults from env
        # ::hue::config set ...           -> set values (tokens/secrets still come from env master)
        # ::hue::config get               -> dict snapshot (redacted)
        # ::hue::config get -raw          -> dict snapshot (unredacted)
        # ::hue::config print             -> print snapshot (redacted)
        # ::hue::config print -raw        -> print snapshot (unredacted)

        if {[llength $args] == 0} {
            ::hue::_setDefaultsFromEnvForLocal
            ::hue::saveConfig
            return
        }

        set cmd  [lindex $args 0]
        set rest [lrange $args 1 end]

        switch -exact -- $cmd {
            print {
                set raw 0
                if {[llength $rest] >= 1 && [lindex $rest 0] eq "-raw"} { set raw 1 }
                ::hue::configPrint $raw
                return
            }

            set {
                if {[llength $rest] % 2} { ::hue::softError "Usage: ::hue::config set ... (key/value pairs)" }

                # load env paths/defaults
                catch { ::hue::envLoad 0 }

                foreach {k v} $rest {
                    switch -exact -- $k {
                        -mode       { set ::hue::mode [string tolower [string trim $v]] }
                        -bridge     { set ::hue::bridge $v }

                        -key {
                            # Explicit override over env master
                            set v [string trim $v]
                            if {$v eq ""} {
                                # clear override -> env becomes master immediately
                                set ::hue::keyOverride ""
                                set ::hue::keyOverrideSet 0
                                catch { ::hue::envLoad 0 }
                            } else {
                                set ::hue::keyOverride $v
                                set ::hue::keyOverrideSet 1
                                set ::hue::key $v
                            }
                        }

                        -remoteBase { set ::hue::remoteBase $v }

                        # you can set these, but env master will overwrite them on next auth/snapshot:
                        -accessToken  { set ::hue::accessToken $v }
                        -refreshToken { set ::hue::refreshToken $v }
                        -clientId     { set ::hue::clientId $v }
                        -clientSecret { set ::hue::clientSecret $v }
                        -expiresAt    { set ::hue::expiresAt $v }

                        default { ::hue::softError "Unknown config option: $k" }
                    }
                }

                if {$::hue::mode eq ""} { set ::hue::mode "local" }
                if {$::hue::mode ni {local remote}} { ::hue::softError "Invalid -mode (use local|remote)" }
                if {$::hue::remoteBase eq ""} { set ::hue::remoteBase "https://api.meethue.com" }

                # persist only non-secrets (and NEVER the key)
                ::hue::saveConfig
                return
            }

            get {
                if {[llength $rest] == 0} { return [::hue::configSnapshot 0] }
                set opt [lindex $rest 0]

                if {$opt eq "-all"} { return [::hue::configSnapshot 0] }
                if {$opt eq "-raw"} { return [::hue::configSnapshot 1] }

                # ensure env master (and key override) are applied
                catch { ::hue::envLoad 0 }

                switch -exact -- $opt {
                    -mode         { return $::hue::mode }
                    -bridge       { return $::hue::bridge }
                    -key          { return $::hue::key }
                    -remoteBase   { return $::hue::remoteBase }
                    -accessToken  { return $::hue::accessToken }
                    -refreshToken { return $::hue::refreshToken }
                    -clientId     { return $::hue::clientId }
                    -clientSecret { return $::hue::clientSecret }
                    -expiresAt    { return $::hue::expiresAt }
                    default {
                        ::hue::softError "Usage: ::hue::config get ?-all|-raw|-mode|-bridge|-key|-remoteBase|-accessToken|-refreshToken|-clientId|-clientSecret|-expiresAt?"
                    }
                }
            }

            default {
                ::hue::softError "Usage: ::hue::config ?set|get|print? ..."
            }
        }
    }

    proc configFile {} {
        ::hue::ensureCacheDirExists
        return [file join [::hue::cacheDir] "hue_config.tcl"]
    }

    # Persist ONLY non-secrets. Key is NOT cached (env master + optional override).
    proc ::hue::saveConfig {} {
        set f [::hue::configFile]
        set ch [open $f w]
        puts $ch "namespace eval ::hue {"
        puts $ch "  set mode       [list $::hue::mode]"
        puts $ch "  set bridge     [list $::hue::bridge]"
        puts $ch "  set remoteBase [list $::hue::remoteBase]"
        puts $ch "}"
        close $ch
    }

    proc ::hue::loadConfig {} {
        set f [::hue::configFile]
        if {[file exists $f]} { catch {source $f} }

        if {![info exists ::hue::mode] || $::hue::mode eq ""} { set ::hue::mode "local" }
        set ::hue::mode [string tolower [string trim $::hue::mode]]
        if {$::hue::mode ni {local remote}} { set ::hue::mode "local" }

        if {![info exists ::hue::bridge]}     { set ::hue::bridge "" }
        if {![info exists ::hue::remoteBase]} { set ::hue::remoteBase "" }
        if {$::hue::remoteBase eq ""} { set ::hue::remoteBase "https://api.meethue.com" }

        # ALWAYS refresh from env master after cache (applies key override if set)
        catch { ::hue::envLoad 0 }

        return 1
    }

    # --- Remote/local URL + headers ------------------------------------
    proc apiUrl {path} {
        if {$::hue::mode eq "local"} {
            if {$::hue::bridge eq ""} { ::hue::softError "Missing -bridge for local mode" }
            return "https://$::hue::bridge$path"
        }
        if {$::hue::remoteBase eq ""} { set ::hue::remoteBase "https://api.meethue.com" }
        return "$::hue::remoteBase/route$path"
    }

    proc curlAuthArgs {} {
        # MASTER read every time auth is built (and apply key override)
        catch { ::hue::envLoad 0 }

        if {$::hue::mode eq "remote"} {
            # refresh FIRST so Authorization uses fresh token
            catch { ::hue::ensureFreshAccessToken }

            if {$::hue::accessToken eq ""} {
                ::hue::softError "Missing access token for remote mode (env hue_remote_env)."
            }
            if {$::hue::key eq ""} {
                ::hue::softError "Missing -key (hue-application-key) for remote mode (env config.hue.tcl, unless overridden)."
            }
            return [::list \
                -H "Authorization: Bearer $::hue::accessToken" \
                -H "hue-application-key: $::hue::key"]
        }

        # local
        if {$::hue::key eq ""} { ::hue::softError "Missing -key for local mode (env config.hue.tcl, unless overridden)." }
        return [::list -k -H "hue-application-key: $::hue::key"]
    }

    # --- core HTTP wrappers (mode-aware) --------------------------------
    proc httpGet {path {extraHeaders {}}} {
        set url  [::hue::apiUrl $path]
        set auth [::hue::curlAuthArgs]
        set args [concat $auth $extraHeaders [::list -sS $url]]
        ::hue::log "httpGet: url=$url"
        return [exec curl {*}$args]
    }

    proc httpPutJson {path jsonBody {extraHeaders {}}} {
        set url  [::hue::apiUrl $path]
        set auth [::hue::curlAuthArgs]
        set args [concat $auth $extraHeaders [::list -sS -X PUT -H "Content-Type: application/json" -d $jsonBody $url]]
        ::hue::log "httpPutJson: url=$url"
        puts "curl $args"
        return [exec curl {*}$args]
    }

    proc httpPostJson {path jsonBody {extraHeaders {}}} {
        set url  [::hue::apiUrl $path]
        set auth [::hue::curlAuthArgs]
        set args [concat $auth $extraHeaders [::list -sS -X POST -H "Content-Type: application/json" -d $jsonBody $url]]
        ::hue::log "httpPostJson: url=$url"
        return [exec curl {*}$args]
    }

    proc httpDelete {path {extraHeaders {}}} {
        set url  [::hue::apiUrl $path]
        set auth [::hue::curlAuthArgs]
        set args [concat $auth $extraHeaders [::list -sS -X DELETE $url]]
        ::hue::log "httpDelete: url=$url"
        return [exec curl {*}$args]
    }

    # ----------------------------------------------------------------------
    # Remote "virtual link button" (bluebutton)
    # ----------------------------------------------------------------------
    proc ::hue::remoteLinkButton {} {
        if {$::hue::mode ne "remote"} {
            ::hue::softError "remoteLinkButton requires -mode remote"
        }

        catch { ::hue::envLoad 0 }
        catch { ::hue::ensureFreshAccessToken }

        if {$::hue::accessToken eq ""} {
            ::hue::softError "Missing access token for remote link button"
        }

        set url "$::hue::remoteBase/route/api/0/config"
        set json "{ \"linkbutton\": true }"

        ::hue::log "remoteLinkButton: PUT $url"

        return [exec curl -sS \
            -X PUT \
            -H "Authorization: Bearer $::hue::accessToken" \
            -H "Content-Type: application/json" \
            -d $json \
            $url]
    }

# --- Remote v1 (proxied) wrappers -------------------------------------
# Remote v1 proxy has two "roots":
#   - Most endpoints: /route/api/0/...
#   - Create-user POST: /route/api        (NO /0)
#
# These use ONLY Authorization: Bearer <accessToken>.
proc ::hue::jsonFixBraces {s} {
    # Undo bash->tcl escaping that turns { } into \{ \}
    # Only remove the backslash directly in front of braces.
    return [string map [list "\\{" "{" "\\}" "}"] $s]
}

proc ::hue::curlBearerArgs {} {
    catch { ::hue::envReloadSecrets }
    catch { ::hue::ensureFreshAccessToken }
    if {$::hue::accessToken eq ""} {
        ::hue::softError "Missing -accessToken for remote mode (env hue_remote_env)."
    }
    return [list -H "Authorization: Bearer $::hue::accessToken"]
}

# /route/api/0 + path  (path must start with /)
proc ::hue::remoteV1Url0 {path} {
    if {$::hue::remoteBase eq ""} { set ::hue::remoteBase "https://api.meethue.com" }
    return "$::hue::remoteBase/route/api/0$path"
}

# /route/api (NO /0)  -- used for POST create user
proc ::hue::remoteV1UrlNo0 {} {
    if {$::hue::remoteBase eq ""} { set ::hue::remoteBase "https://api.meethue.com" }
    return "$::hue::remoteBase/route/api"
}

proc ::hue::httpGetRemoteV1 {path} {
    set url  [::hue::remoteV1Url0 $path]
    set auth [::hue::curlBearerArgs]
    ::hue::log "httpGetRemoteV1: url=$url"
    return [exec curl {*}$auth -sS $url]
}

proc ::hue::httpPutJsonRemoteV1 {path jsonBody} {
    set url  [::hue::remoteV1Url0 $path]
    set auth [::hue::curlBearerArgs]
    ::hue::log "httpPutJsonRemoteV1: url=$url"
    return [exec curl {*}$auth -sS -X PUT -H "Content-Type: application/json" -d $jsonBody $url]
}

# Standard remote v1 POSTs that go to /route/api/0/<path>
proc ::hue::httpPostJsonRemoteV1 {path jsonBody} {
    set url  [::hue::remoteV1Url0 $path]
    set auth [::hue::curlBearerArgs]
    set jsonBody [::hue::jsonFixBraces $jsonBody]
    ::hue::log "httpPostJsonRemoteV1: url=$url"
    return [exec curl {*}$auth -sS -X POST -H "Content-Type: application/json" -d $jsonBody $url]
}

# Special: remote v1 create user POST goes to /route/api (no /0)
proc ::hue::httpPostJsonRemoteV1No0 {jsonBody} {
    set url  [::hue::remoteV1UrlNo0]
    set auth [::hue::curlBearerArgs]
    ::hue::log "httpPostJsonRemoteV1No0: url=$url"
    return [exec curl {*}$auth -sS -X POST -H "Content-Type: application/json" -d $jsonBody $url]
}

proc ::hue::httpDeleteRemoteV1 {path} {
    set url  [::hue::remoteV1Url0 $path]
    set auth [::hue::curlBearerArgs]
    ::hue::log "httpDeleteRemoteV1: url=$url"
    return [exec curl {*}$auth -sS -X DELETE $url]
}

    # --- explicit local-only wrappers (ignore ::hue::mode) --------------
    proc _needLocalBridgeKey {{needKey 1}} {
        catch { ::hue::envLoad 0 }
        if {$::hue::bridge eq ""} { ::hue::softError "Missing local -bridge" }
        if {$needKey && $::hue::key eq ""} { ::hue::softError "Missing local -key" }
    }

    proc httpGetLocal {path {extraHeaders {}}} {
        ::hue::_needLocalBridgeKey 0
        set url "https://$::hue::bridge$path"
        set args [concat [::list -k -H "hue-application-key: $::hue::key"] $extraHeaders [::list -sS $url]]
        ::hue::log "httpGetLocal: url=$url"
        return [exec curl {*}$args]
    }

    proc httpPutJsonLocal {path jsonBody {extraHeaders {}}} {
        ::hue::_needLocalBridgeKey 0
        set url "https://$::hue::bridge$path"
        set args [concat [::list -k -H "hue-application-key: $::hue::key"] $extraHeaders [::list -sS -X PUT -H "Content-Type: application/json" -d $jsonBody $url]]
        ::hue::log "httpPutJsonLocal: url=$url"
        return [exec curl {*}$args]
    }

    proc httpPostJsonLocal {path jsonBody {extraHeaders {}}} {
        ::hue::_needLocalBridgeKey 0
        set url "https://$::hue::bridge$path"
        set args [concat [::list -k -H "hue-application-key: $::hue::key"] $extraHeaders [::list -sS -X POST -H "Content-Type: application/json" -d $jsonBody $url]]
        ::hue::log "httpPostJsonLocal: url=$url"
        return [exec curl {*}$args]
    }

    proc httpDeleteLocal {path {extraHeaders {}}} {
        ::hue::_needLocalBridgeKey 0
        set url "https://$::hue::bridge$path"
        set args [concat [::list -k -H "hue-application-key: $::hue::key"] $extraHeaders [::list -sS -X DELETE $url]]
        ::hue::log "httpDeleteLocal: url=$url"
        return [exec curl {*}$args]
    }

    # chooseOne
    proc ::hue::chooseOne {title options} {
        set n [llength $options]
        if {$n <= 0} { ::hue::softError "No matches." }
        if {$n == 1} { return [lindex $options 0] }
        if {[::hue::isNonInteractive]} {
            puts stderr $title
            puts stderr "Ambiguous match in non-interactive mode. Set a more specific name."
            exit 0
        }
        puts stderr $title
        set i 1
        foreach opt $options { puts stderr [format "  %2d) %s" $i $opt] ; incr i }
        puts stderr "  0) cancel"
        puts -nonewline stderr "Choose 1-$n (or 0): "
        flush stderr
        if {[gets stdin choice] < 0} { exit 0 }
        set choice [string trim $choice]
        if {![regexp {^[0-9]+$} $choice]} { exit 0 }
        set choice [expr {$choice + 0}]
        if {$choice == 0} { exit 0 }
        if {$choice < 1 || $choice > $n} { exit 0 }
        return [lindex $options [expr {$choice - 1}]]
    }

    # --- module sourcing ------------------------------------------------
    proc sourceUsers {} {
        if {[info exists ::hue::usersLoaded] && $::hue::usersLoaded} { return }
        set f [file join [::hue::scriptDir] "hue.inc.users.tcl"]
        if {![file exists $f]} { ::hue::softError "Missing file: $f" }
        source $f
        set ::hue::usersLoaded 1
    }

    proc sourceLights {} {
        if {$::hue::lightsLoaded} { return }
        set f [file join [::hue::scriptDir] "hue.inc.lights.tcl"]
        if {![file exists $f]} { ::hue::softError "Missing file: $f" }
        source $f
        set ::hue::lightsLoaded 1
    }

    proc sourceGroups {} {
        if {$::hue::groupsLoaded} { return }
        set f [file join [::hue::scriptDir] "hue.inc.groups.tcl"]
        if {![file exists $f]} { ::hue::softError "Missing file: $f" }
        source $f
        set ::hue::groupsLoaded 1
    }

    # --- ensureLoaded ---------------------------------------------------
    proc ensureLoaded {args} {
        if {[llength $args] == 0} { return }

        set wantLights 0
        set wantGroups 0
        set wantUsers  0
        set force 0

        foreach a $args {
            switch -nocase -- $a {
                light  - lights { set wantLights 1 }
                group  - groups { set wantGroups 1 }
                user   - users  { set wantUsers 1 }
                all           { set wantLights 1; set wantGroups 1; set wantUsers 1 }
                reset         { set force 1 }
                default       { ::hue::softError "Usage: ::hue::ensureLoaded light|group|user|all ?reset?" }
            }
        }

        if {!$wantLights && !$wantGroups && !$wantUsers} {
            ::hue::softError "Usage: ::hue::ensureLoaded light|group|user|all ?reset?"
        }

        if {$::hue::remoteBase eq ""} { set ::hue::remoteBase "https://api.meethue.com" }

        if {$::hue::bridge eq "" && $::hue::key eq "" && $::hue::accessToken eq ""} {
            ::hue::loadConfig
        } else {
            catch { ::hue::envLoad 0 }
        }

        if {$::hue::mode eq "remote"} {
            catch { ::hue::ensureFreshAccessToken }
        }

        if {$wantLights} {
            ::hue::sourceLights
            if {[info command ::hue::lights::ensureLoaded] eq ""} {
                ::hue::softError "Lights module missing ::hue::lights::ensureLoaded"
            }
            ::hue::lights::ensureLoaded $force
        }

        if {$wantGroups} {
            ::hue::sourceGroups
            if {[info command ::hue::groups::ensureLoaded] eq ""} {
                ::hue::softError "Groups module missing ::hue::groups::ensureLoaded"
            }
            ::hue::groups::ensureLoaded $force
        }

        if {$wantUsers} {
            ::hue::sourceUsers
            if {[info command ::hue::users::ensureLoaded] eq ""} {
                ::hue::softError "Users module missing ::hue::users::ensureLoaded"
            }
            ::hue::users::ensureLoaded $force
        }
    }
}

# Auto-load persisted config (if available) + env (best-effort)
catch { ::hue::loadConfig }
catch { ::hue::envLoad 0 }

proc ::hue::help {} {
    puts "Hue Tcl toolkit"
    puts ""
    puts "Core config:"
    puts "  Local:  ::hue::config                  ;# defaults to local via env config.hue.tcl"
    puts "  Remote: ::hue::config set -mode remote"
    puts ""
    puts "Config snapshots:"
    puts "  set cfg [::hue::config get]            ;# dict (redacted)"
    puts "  set cfg [::hue::config get -raw]       ;# dict (unredacted)"
    puts "  ::hue::config print                    ;# redacted"
    puts "  ::hue::config print -raw               ;# unredacted"
    puts ""
    puts "Logging:"
    puts "  ::hue::setLog 0|1"
    puts "  ::hue::setNonInteractive 0|1   (or env HUE_NONINTERACTIVE=1)"
    puts ""
    puts "Loading:"
    puts "  ::hue::ensureLoaded light|group|users|all ?reset?"
    puts ""
    puts "Env auto-load (master for secrets/tokens):"
    puts "  ./env/.appid points to:"
    puts "    ./env/<appid>/hue_remote_env    (ACCESS_TOKEN/REFRESH_TOKEN/EXPIRES_AT)"
    puts "    ./env/<appid>/app_env           (CLIENTID/CLIENTSECRET)"
    puts "    ./env/<appid>/config.hue.tcl    (user/ip/id)"
    puts ""
    puts "Key precedence:"
    puts "  - config.hue.tcl is always read (master) for key/bridge"
    puts "  - BUT: ::hue::config set -key <...> overrides env until cleared with -key \"\""
    puts ""
    puts "Remote notes:"
    puts "  - Remote requires BOTH:"
    puts "      Authorization: Bearer <accessToken>"
    puts "      hue-application-key: <key>"
    puts "  - Access token refresh runs on-demand when EXPIRES_AT is reached."
    puts ""
    puts "Remote v1 proxy helpers:"
    puts "  ::hue::remoteLinkButton"
    puts "  ::hue::httpGetRemoteV1 \"/config\""
    puts "  ::hue::httpDeleteRemoteV1 \"/config/whitelist/<username>\""
}
