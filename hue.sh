#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE="$DIR/hue.inc.core.tcl"
USERS="$DIR/hue.inc.users.tcl"

# Convert bash args to a SINGLE Tcl list literal (one Tcl word)
tcl_list() {
  local inner="" a esc
  for a in "$@"; do
    esc=$a
    esc=${esc//\\/\\\\}   # \  -> \\
    esc=${esc//\{/\\\{}   # {  -> \{
    esc=${esc//\}/\\\}}   # }  -> \}
    inner+="{${esc}} "
  done
  printf '{%s}' "$inner"
}

ARGV_TCL="$(tcl_list "$@")"

exec tclsh <<TCL
set ::argv $ARGV_TCL

source {$CORE}
source {$USERS}

# default to remote for your tooling
::hue::config set -mode remote

# Run and print result (if any). On error, print error and exit non-zero.
if {[catch { uplevel #0 \$::argv } __res __opts]} {
  puts stderr "ERROR: \$__res"
  if {[dict exists \$__opts -errorinfo]} {
    puts stderr [dict get \$__opts -errorinfo]
  }
  exit 1
}
if {[string length \$__res]} {
  puts \$__res
}
TCL
