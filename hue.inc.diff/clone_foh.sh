#!/usr/bin/env bash
set -euo pipefail

# clone_foh.sh <oldid> <newid>
# Example: clone_foh.sh 24 33

old="${1:-}"
new="${2:-}"
[[ "$old" =~ ^[0-9]+$ && "$new" =~ ^[0-9]+$ ]] || {
  echo "Usage: $0 <oldid> <newid>" >&2
  exit 1
}

need(){ command -v "$1" >/dev/null || { echo "Missing dependency: $1" >&2; exit 1; }; }
need jq

buttons=( tl tr bl br trl brl )

for b in "${buttons[@]}"; do
  in="${old}_${b}.json"
  out="${new}_${b}.json"

  [[ -f "$in" ]] || {
    echo "Skip missing $in"
    continue
  }

  jq \
    --argjson new "$new" '
      .sensor = $new
      | del(.rocker, .resourcelink, .resourcelink_name)
      | if .long? then
          .long.threshold_ms = (.long.threshold_ms // 700)
        else
          .
        end
    ' "$in" > "${out}.tmp"

  mv "${out}.tmp" "$out"
  echo "Wrote $out"
done
