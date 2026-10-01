#!/bin/bash
hue_env_by_device() {
  local pattern="$1*"                 # glob, e.g. 'super-tester#2345*'
  local out="${2:-.env.hue}"
  local delim=";"
  local cli="${HUE_TCL_CLI:-hue.sh}"  # set this to your launcher

  if [[ -z "$pattern" ]]; then
    echo "Usage: hue_env_by_device <device_glob> [outfile]" >&2
    return 2
  fi

  # Expect header line first; skip it.
  type -a "$cli"
echo "cli=<$cli>"
  echo hier
  "$cli" ::hue::users::printUsers -csv "$delim" -clientkey -lastuse | head -n 1
  exit
  local row
  row="$(
    "$cli" ::hue::users::printUsers -csv "$delim" -clientkey -lastuse \
    | tail -n +2 \
    | awk -F"$delim" -v pat="$(echo "$pattern" | tr '[:upper:]' '[:lower:]')" '
        BEGIN{IGNORECASE=1}
        {
          dev=tolower($3)
          # glob-ish match: translate * -> .*
          gsub(/\*/, ".*", pat)
          if (dev ~ "^" pat "$") { print $0; exit }
        }'
  )"

  if [[ -z "$row" ]]; then
    echo "No match for device pattern: $pattern" >&2
    return 1
  fi

  IFS="$delim" read -r local_user remote_user devicetype created last_use clientkey <<<"$row"

  if [[ -z "$remote_user" ]]; then
    echo "Matched row but remote_user empty (unexpected)" >&2
    return 1
  fi
  if [[ -z "$clientkey" ]]; then
    echo "Matched row but clientkey is empty. Tip: run once with -force and create with generateclientkey=1." >&2
    return 1
  fi

  cat >"$out" <<EOF
HUE_REMOTE_USER=${remote_user}
HUE_CLIENTKEY=${clientkey}
HUE_DEVICETYPE=${devicetype}
HUE_CREATED=${created}
HUE_LAST_USE=${last_use}
EOF

  echo "Wrote $out"
}
hue_env_by_device my-ent-app