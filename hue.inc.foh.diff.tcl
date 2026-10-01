# --- hue.inc.foh.diff.tcl (or wherever your dump lives) ---

namespace eval ::hue::foh {
    variable _dumpSections {config sensors rules schedules resourcelinks scenes groups}
}

proc ::hue::foh::_getV1Raw {path} {
    # Prefer remote, since your local GET sometimes returns HTML.
    if {[string tolower [string trim [::hue::config get -mode]]] eq "remote"} {
        return [::hue::httpGetRemoteV1 $path]
    }
    return [::hue::httpGetLocal $path]
}

proc ::hue::foh::dumpAll {outfile args} {
    # Usage:
    #   ::hue::config set -mode remote
    #   ::hue::foh::dumpAll /tmp/hue_before.json
    # Optional: ::hue::foh::dumpAll /tmp/x.json -sections {rules sensors}

    set sections $::hue::foh::_dumpSections

    set i 0
    while {$i < [llength $args]} {
        set a [lindex $args $i]
        switch -exact -- $a {
            -sections { incr i; set sections [lindex $args $i] }
            default { ::hue::softError "dumpAll: unknown arg '$a'" }
        }
        incr i
    }

    # Build JSON object WITHOUT parsing JSON.
    set ts [clock seconds]
    set iso [clock format $ts -format {%Y-%m-%dT%H:%M:%S}]
    set mode [string tolower [string trim [::hue::config get -mode]]]
    if {$mode eq ""} { set mode "local" }

    set json "{\n"
    append json "  \"meta\": {\"mode\": \"${mode}\", \"time_iso\": \"${iso}\"}"

    foreach sec $sections {
        set path "/$sec"
        if {$sec eq "config"} { set path "/config" }

        set body [string trim [::hue::foh::_getV1Raw $path]]

        # Fail fast if we got HTML (common when local endpoint is wrong)
        if {[string match -nocase "<!DOCTYPE*" $body] || [string match -nocase "<html*" $body]} {
            ::hue::softError "dumpAll: $sec returned HTML (not JSON). Use -mode remote or fix local endpoint. First bytes: [string range $body 0 80]"
        }
        if {$body eq ""} { set body "{}" }

        append json ",\n  \"$sec\": $body"
    }
    append json "\n}\n"

    # Write raw temp, then jq pretty+sorted into outfile.
    ::hue::ensureCacheDirExists
    set tmp [file join [::hue::cacheDir] "hue_dump_tmp_[pid].json"]
    set ch [open $tmp w]
    fconfigure $ch -translation lf
    puts -nonewline $ch $json
    close $ch

    # Pretty print. Requires jq on PATH.
    if {[catch {exec jq -S . $tmp > $outfile} e]} {
        # fallback: write raw JSON if jq missing
        set ch [open $outfile w]
        fconfigure $ch -translation lf
        puts -nonewline $ch $json
        close $ch
        catch {file delete -force $tmp}
        ::hue::softError "dumpAll: jq failed (wrote unformatted JSON). Error: $e"
    }

    catch {file delete -force $tmp}
    return $outfile
}
