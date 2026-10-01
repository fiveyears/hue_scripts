#!/usr/bin/env bash
set -euo pipefail

# Uses your existing wrapper:
#   cli=/path/to/hue.sh
#   "$cli" <tcl-command> [args...]
#
# Requires: jq

die(){ echo "ERROR: $*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null || die "Missing dependency: $1"; }

need jq
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
cli="${cli:-"$DIR/hue.sh"}"
[[ -n "$cli" ]] || die "Set cli=/path/to/hue.sh (your wrapper)"
# Generate desired rules JSON (short/long_start/long_end) from model using jq filter
jq_filter="${jq_filter:-$DIR/hue.inc.diff/foh_to_hue_rules.jq}"
[[ -f "$jq_filter" ]] || die "Missing jq filter file: $jq_filter"
sid="${1:-}"
arg2="${2:-}"
[[ "$sid" =~ ^[0-9]+$ ]] || die "Usage: $0 <sensorId> <button|-delete>   (sensorId must be numeric)"
[[ -n "$arg2" ]] || die "Usage: $0 <sensorId> <button|-delete>"
rl_dumped=0
dry_run=0
for a in "$@"; do
  case "$a" in
    -n|--dry-run) dry_run=1 ;;
  esac
done
# ---------------- canonicalize button ----------------
canon_btn() {
  local b s
  b="$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cd 'tblr')"
  [[ -n "$b" ]] || return 1

  # --- 2-button: order-insensitive ---
  if [[ ${#b} -eq 2 ]]; then
    s="$(echo "$b" | fold -w1 | sort | tr -d '\n')"
    case "$s" in
      lt) echo "tl"; return 0;;
      rt) echo "tr"; return 0;;
      bl) echo "bl"; return 0;;
      br) echo "br"; return 0;;
    esac
    return 1
  fi

  # --- 3-button: order-insensitive ---
  if [[ ${#b} -eq 3 ]]; then
    s="$(echo "$b" | fold -w1 | sort | tr -d '\n')"
    case "$s" in
      lrt) echo "trl"; return 0;;
      blr) echo "brl"; return 0;;
    esac
    return 1
  fi

  return 1
}

# ---------------- Hue API helpers via your TCL ----------------
# All calls are remote v1. You should run:
#   ::hue::config set -mode remote
tcl_get()  { "$cli" ::hue::httpGetRemoteV1 "$1"; }

tcl_put()  {
  if [[ "$dry_run" -eq 1 ]]; then
    echo "DRYRUN PUT  $1"
    echo "$2" | jq .
    return 0
  fi
  "$cli" ::hue::httpPutJsonRemoteV1 "$1" "$2"
}

tcl_post() {
  if [[ "$dry_run" -eq 1 ]]; then
    echo "DRYRUN POST $1"
    echo "$2" | jq .
    # return fake success id so later code can continue if needed
    echo '[{"success":{"id":"0"}}]'
    return 0
  fi
  "$cli" ::hue::httpPostJsonRemoteV1 "$1" "$2"
}

tcl_del()  {
  if [[ "$dry_run" -eq 1 ]]; then
    echo "DRYRUN DEL  $1"
    return 0
  fi
  "$cli" ::hue::httpDeleteRemoteV1 "$1"
}

# ---- normalize TCL output to a real JSON object/array ----
json_norm() {
  # Strip any junk before the first { or [
  awk '
    BEGIN{p=0}
    {
      if(!p){
        for(i=1;i<=length($0);i++){
          c=substr($0,i,1)
          if(c=="{" || c=="["){ p=1; print substr($0,i); next }
        }
        next
      }
      print
    }
  ' \
  | jq -c '
      def unwrap:
        if type=="string" then
          (try (fromjson | unwrap) catch .)
        else .
        end;
      unwrap
    '
}

# ---------------- mappings ----------------
press_release() {
  case "$1" in
    tl)  echo "16 20" ;;
    bl)  echo "17 21" ;;
    br)  echo "18 22" ;;
    tr)  echo "19 23" ;;
    trl) echo "100 101" ;; # top pair
    brl) echo "98 99" ;;   # bottom pair
    *) return 1 ;;
  esac
}
all_buttons_for_sensor() {
  # The 6 supported buttons (4 singles + 2 pairs)
  echo "tl tr bl br trl brl"
}

# ---------------- read helpers (Option A: no recursion) ----------------
write_empty_button_file() {
  local sid="$1"
  local btn="$2"
  local out="${sid}_${btn}.json"

  jq -n \
    --argjson sensor "$sid" \
    --arg button "$btn" \
    '
    {
      sensor: $sensor,
      button: $button,
      short: { actions: [] },
      long:  {
        threshold_ms: 700,
        start: { actions: [] },
        end:   { actions: [] }
      }
    }
    ' | jq '.' >"$out"

  echo "Wrote $out (empty; no resourcelink/rules found)" >&2
}


dump_resourcelink_once() {
  # expects: rl_json, rl_id, rl_name already set in caller
  local out="${sid}_resourcelink.json"

  # no rl_id => nothing to dump
  if [[ -z "${rl_id:-}" ]]; then
    echo "WARN: no resourcelink id for sensor $sid; not writing ${sid}_resourcelink.json" >&2
    return 0
  fi

  # only once
  if [[ "${rl_dumped:-0}" -eq 0 ]]; then
    jq --arg id "$rl_id" --argjson rid "$rl_id" '
      .[$id] as $o
      | ($o + {id: $rid})
    ' <<<"$rl_json" | jq '.' >"$out"

    echo "Wrote $out (resourcelink=$rl_id name='$rl_name')" >&2
    rl_dumped=1
  fi
}

read_one_button_from_bridge() {
  # args: <btn> <rl_id> <rl_name> <rl_links_json>
  local btn="$1"
  local rl_id="$2"
  local rl_name="$3"
  local rl_links="$4"

  local file="${sid}_${btn}.json"
  local press release
  read -r press release < <(press_release "$btn") || die "No mapping for button '$btn'"

  # Determine rocker (CLIPGenericStatus) from rl_links
  local rocker_id
  rocker_id="$(
    jq -r '.[] | select(startswith("/sensors/")) | sub("^/sensors/";"")' <<<"$rl_links" \
    | while read -r x; do
        [[ "$x" == "$sid" ]] && continue
        jq -e --arg id "$x" '.[$id].type=="CLIPGenericStatus"' <<<"$sensors_json" >/dev/null 2>&1 && echo "$x"
      done | head -n 1
  )"
  [[ -n "$rocker_id" ]] || die "Resourcelink '$rl_name' does not reference a CLIPGenericStatus rocker"

  # Rule ids referenced by RL
  local rule_ids rule_ids_json
  rule_ids="$(jq -r '.[] | select(startswith("/rules/")) | sub("^/rules/";"")' <<<"$rl_links" | sort -u)"
  [[ -n "$rule_ids" ]] || die "Resourcelink '$rl_name' contains no /rules/ links"

  rule_ids_json="$(printf '%s\n' $rule_ids | jq -R . | jq -s .)"

  # Pick iConnectHue-style rules
  local picked support_press_rule short_rule long_start_rule long_end_rule
  picked="$(jq -c \
    --arg sid "$sid" \
    --arg rid "$rocker_id" \
    --argjson press "$press" \
    --argjson release "$release" \
    --argjson ids "$rule_ids_json" '
    . as $all
    | def hasCond($r; $addr; $op; $val):
        any(($r.conditions // [])[]?; .address==$addr and .operator==$op and ((.value|tostring)==($val|tostring)));
      def hasDx($r; $addr):
        any(($r.conditions // [])[]?; .address==$addr and .operator=="dx");
      def hasDdx($r; $addr):
        any(($r.conditions // [])[]?; .address==$addr and .operator=="ddx");
      def hasRockerCond($r; $rid; $v):
        any(($r.conditions // [])[]?; .address==("/sensors/"+$rid+"/state/status") and .operator=="eq" and ((.value|tostring)==($v|tostring)));
      def onlyRockerActions($r; $rid):
        ((($r.actions // [])|length) > 0)
        and ((($r.actions // []) | all(
              .address==("/sensors/"+$rid+"/state")
              and ((.method // "PUT")=="PUT")
              and (.body.status? != null)
            )));
      def setsRockerTo($r; $rid; $v):
        any(($r.actions // [])[]?;
          .address==("/sensors/"+$rid+"/state")
          and ((.method // "PUT")=="PUT")
          and ((.body.status? // null)|tostring)==($v|tostring)
        );

      {
        support_press:
          ( $ids
            | map(tostring)
            | map(select(
                ($all[.]? // null) as $r
                | $r != null
                and hasCond($r; ("/sensors/"+$sid+"/state/buttonevent"); "eq"; $press)
                and hasDx($r; ("/sensors/"+$sid+"/state/lastupdated"))
                and setsRockerTo($r; $rid; 1)
                and onlyRockerActions($r; $rid)
              ))
            | .[0] // empty
          ),

        short_action:
          ( $ids
            | map(tostring)
            | map(select(
                ($all[.]? // null) as $r
                | $r != null
                and hasCond($r; ("/sensors/"+$sid+"/state/buttonevent"); "eq"; $release)
                and hasDx($r; ("/sensors/"+$sid+"/state/lastupdated"))
                and hasRockerCond($r; $rid; 1)
                and (onlyRockerActions($r; $rid) | not)
                and (looksLikeStop($r; $rid) | not)
              ))
            | .[0] // empty
          ),

        long_start:
          ( $ids
            | map(tostring)
            | map(select(
                ($all[.]? // null) as $r
                | $r != null
                and hasCond($r; ("/sensors/"+$sid+"/state/buttonevent"); "eq"; $press)
                and hasDdx($r; ("/sensors/"+$sid+"/state/lastupdated"))
                and hasRockerCond($r; $rid; 1)
              ))
            | .[0] // empty
          ),

        long_end_2:
          ( $ids
            | map(tostring)
            | map(select(
                ($all[.]? // null) as $r
                | $r != null
                and hasCond($r; ("/sensors/"+$sid+"/state/buttonevent"); "eq"; $release)
                and hasDx($r; ("/sensors/"+$sid+"/state/lastupdated"))
                and hasRockerCond($r; $rid; 2)
              ))
            | .[0] // empty
          ),

        long_end_1:
          ( $ids
            | map(tostring)
            | map(select(
                ($all[.]? // null) as $r
                | $r != null
                and hasCond($r; ("/sensors/"+$sid+"/state/buttonevent"); "eq"; $release)
                and hasDx($r; ("/sensors/"+$sid+"/state/lastupdated"))
                and hasRockerCond($r; $rid; 1)
                and (onlyRockerActions($r; $rid) | not)
              ))
            | .[0] // empty
          )
      }
    ' <<<"$rules_json")"

  support_press_rule="$(jq -r '.support_press // empty' <<<"$picked")"
  short_rule="$(jq -r '.short_action // empty' <<<"$picked")"
  long_start_rule="$(jq -r '.long_start // empty' <<<"$picked")"
  long_end_rule="$(jq -r '(.long_end_2 // empty) // (.long_end_1 // empty)' <<<"$picked")"

  rule_body() { jq -c --arg rid "$1" '.[$rid]' <<<"$rules_json"; }

  local short_body="null" ls_body="null" le_body="null"
  [[ -n "$short_rule" ]] && short_body="$(rule_body "$short_rule")"
  [[ -n "$long_start_rule" ]] && ls_body="$(rule_body "$long_start_rule")"
  [[ -n "$long_end_rule" ]] && le_body="$(rule_body "$long_end_rule")"

  # threshold from ddx
  local threshold_ms=700 dur sec
  if [[ "$ls_body" != "null" ]]; then
    dur="$(jq -r '.conditions[]? | select(.operator=="ddx" and (.address|endswith("/lastupdated"))) | .value' <<<"$ls_body" | head -n1)"
    if [[ "$dur" =~ PT00:00:([0-9]+(\.[0-9]+)?) ]]; then
      sec="${BASH_REMATCH[1]}"
      threshold_ms="$(python3 - <<PY
sec=float("$sec")
print(int(round(sec*1000)))
PY
)"
    fi
  fi

  # strip rocker writes
  local strip_rocker_actions_jq='
    def stripRockerWrites($rid):
      map(select(
        .address != ("/sensors/"+($rid|tostring)+"/state")
        or ((.method // "PUT") != "PUT")
        or (.body.status? == null)
      ));
    def cleaned($rid):
      . as $x
      | ($x // {})
      | .actions = ((($x.actions // []) | stripRockerWrites($rid)));
  '

  local short_clean ls_clean le_clean
  short_clean="$(jq -c --argjson rid "$rocker_id" "$strip_rocker_actions_jq cleaned(\$rid)" <<<"$short_body" 2>/dev/null || echo "null")"
  ls_clean="$(jq -c --argjson rid "$rocker_id" "$strip_rocker_actions_jq cleaned(\$rid)" <<<"$ls_body" 2>/dev/null || echo "null")"
  le_clean="$(jq -c --argjson rid "$rocker_id" "$strip_rocker_actions_jq cleaned(\$rid)" <<<"$le_body" 2>/dev/null || echo "null")"

  export RLID="$rl_id"
  export RLNAME="$rl_name"

  jq -n \
    --argjson sensor "$sid" \
    --argjson rocker "$rocker_id" \
    --arg button "$btn" \
    --argjson press "$press" \
    --argjson release "$release" \
    --argjson threshold "$threshold_ms" \
    --argjson short "$short_clean" \
    --argjson ls "$ls_clean" \
    --argjson le "$le_clean" '
    def acts($r): ($r.actions // []);
    {
      sensor: $sensor,
      rocker: $rocker,
      button: $button,
      resourcelink: ($ENV.RLID | tonumber),
      resourcelink_name: ($ENV.RLNAME),
      mapping: {
        short: { press: $press, release: $release },
        long:  { press: $press, release: $release, threshold_ms: $threshold }
      },
      short: { name: ($short.name // ($button + " short")), actions: (acts($short)) },
      long: {
        start: { name: ($ls.name // ($button + " long start")), actions: (acts($ls)) },
        end:   { name: ($le.name // ($button + " long end")),   actions: (acts($le)) }
      }
    }
    | if ($short == null or $short == {}) then .short.actions=[] else . end
    | if ($ls == null or $ls == {}) then .long.start.actions=[] else . end
    | if ($le == null or $le == {}) then .long.end.actions=[] else . end
  ' | jq '.' >"$file"

  echo "Wrote $file from bridge (resourcelink=$rl_id name='$rl_name' rocker=$rocker_id)" >&2
}

do_delete() {
  local path="$1"
  local label="$2"

  if [[ "$dry_run" -eq 1 ]]; then
    echo "  - WOULD delete $label ($path)"
  else
    echo "  - delete $label ($path)"
    tcl_del "$path" >/dev/null || true
  fi
}
do_put() {
  local path="$1" label="$2" body="$3"
  if [[ "$dry_run" -eq 1 ]]; then
    echo "  - WOULD update $label ($path)"
    echo "$body" | jq '.' >&2
  else
    echo "  - update $label ($path)"
    tcl_put "$path" "$body" >/dev/null || true
  fi
}

# ---------------- "delete all managed stuff" ----------------
delete_all_for_sensor() {
  local sid="$1"
  if [[ "$dry_run" -eq 1 ]]; then
    echo "DRY-RUN: Deleting managed FoH objects for sensor $sid (no changes will be made)"
  else
    echo "Deleting managed FoH objects for sensor $sid ..."
  fi

  local rl_json rules_json sensors_json
  rl_json="$(tcl_get "/resourcelinks" | json_norm)"
  rules_json="$(tcl_get "/rules" | json_norm)"
  sensors_json="$(tcl_get "/sensors" | json_norm)"
  # Find all resourcelinks that reference /sensors/<sid>
  local rls
  rls="$(jq -r --arg sid "$sid" '
    to_entries[]
    | select(
        (.value.links // [])
        | any(. == ("/sensors/" + $sid))
      )
    | .key
  ' <<<"$rl_json")"

  if [[ -z "$rls" ]]; then
    echo "No resourcelinks referencing /sensors/$sid"
  fi

  # From those resourcelinks, collect rule ids and CLIPGenericStatus sensor ids to delete
  local rule_ids rocker_ids
  rule_ids="$(jq -r --arg sid "$sid" '
    to_entries[]
    | select((.value.links // []) | any(. == ("/sensors/" + $sid)))
    | (.value.links // [])
    | map(select(startswith("/rules/")))
    | .[]
    | sub("^/rules/";"")
  ' <<<"$rl_json" | sort -u)"

  # rockers: CLIPGenericStatus sensors referenced by those resourcelinks
  rocker_ids="$(
    jq -r --arg sid "$sid" '
      [
        to_entries[]
        | select((.value.links // []) | any(. == ("/sensors/" + $sid)))
        | (.value.links // [])[]?
        | select(startswith("/sensors/"))
        | sub("^/sensors/";"")
      ]
      | unique
      | .[]
    ' <<<"$rl_json" \
    | while read -r x; do
        [[ "$x" == "$sid" ]] && continue
        jq -e --arg id "$x" '.[$id].type == "CLIPGenericStatus"' <<<"$sensors_json" >/dev/null 2>&1 && echo "$x"
      done \
    | sort -u
  )"
  # Delete resourcelinks first (break references)
  for rid in $rls; do
    do_delete "/resourcelinks/$rid" "resourcelink $rid"
  done

  # Delete rules
  for rid in $rule_ids; do
    do_delete "/rules/$rid" "rule $rid"
  done

  # Delete rockers
  for x in $rocker_ids; do
    do_delete "/sensors/$x" "rocker sensor $x (CLIPGenericStatus)"
  done
  if [[ "$dry_run" -eq 1 ]]; then
    echo "DRY-RUN complete."
  else
    echo "Done."
  fi
}

find_rule_id_by_name_for_sid() {
  local name="$1"
  local sid="$2"

  jq -r --arg name "$name" --arg sid "$sid" '
    to_entries[]
    | select((.value.name // "") == $name)
    | select(
        ((.value.conditions // []) | any(
          (.address // "") | contains("/sensors/" + $sid + "/")
        ))
      )
    | .key
    | first
  ' <<<"$rules_json"
}


delete_button_for_sensor() {
  local sid="$1"
  local btn="$2"
  local file="${sid}_${btn}.json"

  [[ -f "$file" ]] || die "Missing model file: $file (needed to know rule names)"

  local short_name ls_name le_name
  short_name="$(jq -r '.short.name // empty' "$file")"
  ls_name="$(jq -r '.long.start.name // empty' "$file")"
  le_name="$(jq -r '.long.end.name // empty' "$file")"

  [[ -n "$short_name$ls_name$le_name" ]] || die "No rule names in $file"

  echo "Deleting ONLY button '$btn' for sensor $sid ..."
  [[ "$dry_run" -eq 1 ]] && echo "DRY-RUN (no changes)."

  # Pull current bridge state
  local rl_json rules_json sensors_json
  rl_json="$(tcl_get "/resourcelinks" | json_norm)"
  rules_json="$(tcl_get "/rules" | json_norm)"
  sensors_json="$(tcl_get "/sensors" | json_norm)"
  # Find RL(s) referencing /sensors/<sid> (classid 10050 preferred)
  local rl_ids rl_id rl_links rl_name
  rl_ids="$(jq -r --arg sid "$sid" '
    to_entries[]
    | select((.value.links//[]) | any(. == ("/sensors/"+$sid)))
    | .key
  ' <<<"$rl_json")"
  [[ -n "$rl_ids" ]] || die "No resourcelink references /sensors/$sid"
  rl_id="$(
    jq -r --arg sid "$sid" '
      [ to_entries[]
        | select((.value.links//[]) | any(. == ("/sensors/"+$sid)))
        | select((.value.classid//0) == 10050)
        | .key
      ][0] // empty
    ' <<<"$rl_json"
  )"
  [[ -n "$rl_id" ]] || rl_id="$(echo "$rl_ids" | head -n1)"

  rl_name="$(jq -r --arg id "$rl_id" '.[$id].name // ""' <<<"$rl_json")"
  rl_links="$(jq -c --arg id "$rl_id" '.[$id].links // []' <<<"$rl_json")"
  # Helper: find rule id by exact name
  # Delete the three possible rules (if they exist)
  local r_short="" r_ls="" r_le=""
  [[ -n "$short_name" ]] && r_short="$(find_rule_id_by_name_for_sid "$short_name" "$sid")"
  [[ -n "$ls_name" ]] && r_ls="$(find_rule_id_by_name "$ls_name")"
  [[ -n "$le_name" ]] && r_le="$(find_rule_id_by_name "$le_name")"


  # Build list of rule ids we will remove from RL links
  local remove_rule_ids=()
  [[ -n "$r_short" && "$r_short" != "null" ]] && remove_rule_ids+=("$r_short")
  [[ -n "$r_ls" && "$r_ls" != "null" ]] && remove_rule_ids+=("$r_ls")
  [[ -n "$r_le" && "$r_le" != "null" ]] && remove_rule_ids+=("$r_le")

  if [[ "${#remove_rule_ids[@]}" -eq 0 ]]; then
    echo "  - no matching rules found on bridge for $file (nothing to delete)"
    return 0
  fi

  # Delete rules first
  for rid in "${remove_rule_ids[@]}"; do
    do_delete "/rules/$rid" "rule $rid"
  done

  # Update RL: remove /rules/<rid> links
  local new_links
  new_links="$(
    jq -c --argjson rm "$(printf '%s\n' "${remove_rule_ids[@]}" | jq -R . | jq -s .)" '
      . as $links
      | ($rm | map("/rules/" + .)) as $rm_links
      | [ $links[] | select(. as $x | ($rm_links | index($x) | not)) ]
    ' <<<"$rl_links"
  )"

  # Only PUT if it actually changed
  local old_links_compact
  old_links_compact="$(jq -c '.' <<<"$rl_links")"
  if [[ "$new_links" != "$old_links_compact" ]]; then
    local rl_body
    rl_body="$(jq -n --arg name "$rl_name" --arg desc "$(jq -r --arg id "$rl_id" '.[$id].description // ""' <<<"$rl_json")" --argjson links "$new_links" '
      {
        name: $name,
        description: $desc,
        type: "Link",
        classid: 10050,
        recycle: false,
        links: $links
      }
    ')"
    do_put "/resourcelinks/$rl_id" "resourcelink $rl_id ($rl_name)" "$rl_body"
  else
    echo "  - resourcelink already missing those rules (no update needed)"
  fi

  # -------------------------------
  # Optional: delete rocker if unused
  # (safe: only if no remaining rule in RL references rocker status)
  # -------------------------------

  # Determine rocker id from NEW RL links
  local rocker_id
  rocker_id="$(
    jq -r '.[] | select(startswith("/sensors/")) | sub("^/sensors/";"")' <<<"$new_links" \
    | while read -r x; do
        [[ "$x" == "$sid" ]] && continue
        jq -e --arg id "$x" '.[$id].type=="CLIPGenericStatus"' <<<"$sensors_json" >/dev/null 2>&1 && echo "$x"
      done | head -n1
  )"
  if [[ -n "$rocker_id" ]]; then
    # Remaining rule ids still linked by RL
    local remaining_rule_ids
    remaining_rule_ids="$(
      jq -r '.[] | select(startswith("/rules/")) | sub("^/rules/";"")' <<<"$new_links"
    )"

    # Check if any remaining rule has condition on rocker status
    local still_used=0
    for rr in $remaining_rule_ids; do
      jq -e --arg rr "$rr" --arg rid "$rocker_id" '
        (.[$rr].conditions // [])
        | any(.address==("/sensors/"+$rid+"/state/status"))
      ' <<<"$rules_json" >/dev/null 2>&1 && { still_used=1; break; }
    done

    if [[ "$still_used" -eq 0 ]]; then
      echo "  - rocker $rocker_id appears unused; removing from RL and deleting"

      # Remove rocker sensor link from RL
      local new_links2
      new_links2="$(jq -c --arg rid "$rocker_id" '
        [ .[] | select(. != ("/sensors/" + $rid)) ]
      ' <<<"$new_links")"

      if [[ "$new_links2" != "$new_links" ]]; then
        local rl_body2
        rl_body2="$(jq -n \
          --arg name "$rl_name" \
          --arg desc "$(jq -r --arg id "$rl_id" '.[$id].description // ""' <<<"$rl_json")" \
          --argjson links "$new_links2" '
          {
            name: $name,
            description: $desc,
            type: "Link",
            classid: 10050,
            recycle: false,
            links: $links
          }
        ')"
        do_put "/resourcelinks/$rl_id" "resourcelink $rl_id (remove rocker link)" "$rl_body2"
        new_links="$new_links2"
      fi

      do_delete "/sensors/$rocker_id" "rocker sensor $rocker_id (unused)"
    else
      echo "  - rocker $rocker_id still used by other rules; keeping"
    fi
  else
    echo "  - no rocker link found in RL; nothing to cleanup"
  fi

  echo "OK: deleted button '$btn' rules (and updated RL '$rl_name')"
}

# ---------------- main ----------------
if [[ "$arg2" == "-delete" ]]; then
  delete_all_for_sensor "$sid"
  exit 0
fi
# NEW: <sid> <btn> -delete
if [[ "${3:-}" == "-delete" ]]; then
  btn="$(canon_btn "$arg2")" || die "Bad button '$arg2'"
  delete_button_for_sensor "$sid" "$btn"
  exit 0
fi

read_one_button_from_bridge() {
  local btn="$1"
  local rl_id="$2"
  local rl_name="$3"
  local rl_links="$4"

  local file="${sid}_${btn}.json"
  local bname="$btn"

  # mapping per button
  local press release
  read -r press release < <(press_release "$btn") || die "No mapping for button '$btn'"

  # ---- If there is no resourcelink (or empty links), write empty skeleton and return success
  if [[ -z "${rl_id:-}" || -z "${rl_links:-}" || "$rl_links" == "[]" ]]; then
    jq -n \
      --argjson sensor "$sid" \
      --arg button "$btn" \
      '{
        sensor: $sensor,
        rocker: null,
        button: $button,
        resourcelink: null,
        resourcelink_name: null,
        short: { name: ($button + " short"), actions: [] },
        long: {
          threshold_ms: 700,
          start: { name: ($button + " long start"), actions: [] },
          end:   { name: ($button + " long end"),   actions: [] }
        }
      }' | jq '.' >"$file"

    echo "Wrote $file (empty; no resourcelink/rules found)" >&2
    return 0
  fi

  # rocker from rl_links (same for all buttons)
  # IMPORTANT: keep it EMPTY if not found (don't set string "null")
  local rocker_id=""
  rocker_id="$(
    jq -r '.[] | select(startswith("/sensors/")) | sub("^/sensors/";"")' <<<"$rl_links" \
    | while read -r x; do
        [[ "$x" == "$sid" ]] && continue
        jq -e --arg id "$x" '.[$id].type=="CLIPGenericStatus"' <<<"$sensors_json" >/dev/null 2>&1 && echo "$x"
      done | head -n 1
  )"
  if [[ -z "$rocker_id" ]]; then
    echo "WARN(${btn}): no rocker found in resourcelink; continuing with rocker=null (picker will ignore rocker-conds)" >&2
  fi

  # rule ids referenced by RL
  local rule_ids rule_ids_json
  rule_ids="$(jq -r '.[] | select(startswith("/rules/")) | sub("^/rules/";"")' <<<"$rl_links" | sort -u)"

  # If RL has no rules (or iConnectHue made a weird RL), write empty skeleton and continue.
  if [[ -z "$rule_ids" ]]; then
    jq -n \
      --argjson sensor "$sid" \
      --arg button "$btn" \
      --argjson rlid "$rl_id" \
      --arg rlname "$rl_name" \
      '{
        sensor: $sensor,
        rocker: null,
        button: $button,
        resourcelink: $rlid,
        resourcelink_name: $rlname,
        short: { name: ($button + " short"), actions: [] },
        long: {
          threshold_ms: 700,
          start: { name: ($button + " long start"), actions: [] },
          end:   { name: ($button + " long end"),   actions: [] }
        }
      }' | jq '.' >"$file"

    echo "WARN(${btn}): resourcelink has no /rules/* links; wrote empty $file" >&2
    return 0
  fi

  rule_ids_json="$(printf '%s\n' $rule_ids | jq -R . | jq -s .)"

  # ---- pick rules: SIMPLE (no support press, no rocker logic) ----
  local picked short_rule long_start_rule long_end_rule threshold_ms

picked="$(
  jq -c \
    --arg sid "$sid" \
    --arg rid "$rocker_id" \
    --arg btn "$btn" \
    --argjson press "$press" \
    --argjson release "$release" \
    --argjson ids "$rule_ids_json" '
    # -------- defs at top level only --------
    def isRockerWrite($rid):
      (.address == ("/sensors/" + $rid + "/state"))
      and ((.method // "PUT") == "PUT")
      and (.body.status? != null);

    def nonRockerActs($rid):
      [ (.actions // [])[]? | select(isRockerWrite($rid) | not) ];

    def isStopAction:
      (.body.bri_inc? == 0) or (.body.transitiontime? == 0);

    def looksLikeStop($rid):
      (nonRockerActs($rid) | any(isStopAction));

    def hasBtnEq($sid; $val):
      any((.conditions // [])[]?;
        .address==("/sensors/"+$sid+"/state/buttonevent")
        and .operator=="eq"
        and (.value|tostring)==($val|tostring)
      );

    def hasOp($sid; $op):
      any((.conditions // [])[]?;
        .address==("/sensors/"+$sid+"/state/lastupdated")
        and .operator==$op
      );

    def ddxDur($sid):
      ((.conditions // [])
        | map(select(.operator=="ddx" and (.address==("/sensors/"+$sid+"/state/lastupdated"))))
        | .[0].value? // "");

    def msFromDur($dur):
      if ($dur|test("^PT00:00:")) then
        ($dur
          | sub("^PT00:00:";"")
          | (try tonumber catch 1)
          | (. * 1000) | round)
      else 700 end;

    # ---- rocker status helpers (only used if rule has such a condition) ----
    def baseStatus($btn):
      if ($btn|test("^t")) then 1 else 3 end;

    def activeStatus($btn):
      if ($btn|test("^t")) then 2 else 4 end;

    def hasRockerEq($rid; $v):
      any((.conditions // [])[]?;
        .address==("/sensors/"+$rid+"/state/status")
        and .operator=="eq"
        and ((.value|tostring)==($v|tostring))
      );

    def rockerOkOrNone($rid; $v):
      # if rule has ANY rocker status condition -> it must match $v
      # if rule has NO rocker status condition -> accept
      (any((.conditions // [])[]?; .address==("/sensors/"+$rid+"/state/status")) | not)
      or hasRockerEq($rid; $v);

    # -------- main --------
    . as $all
    | ($ids | map(tostring)) as $ids2

    # SHORT: release + dx + non-rocker actions + NOT stop-rule
    | ([ $ids2[]
         | select(($all[.]? // null) != null)
         | select($all[.] | hasBtnEq($sid; $release))
         | select($all[.] | hasOp($sid; "dx"))
         | select(($all[.] | nonRockerActs($rid) | length) > 0)
         | select(($all[.] | looksLikeStop($rid)) | not)              # <--- THIS is where it goes
         | select($all[.] | rockerOkOrNone($rid; baseStatus($btn)))   # prefer correct rocker status (if present)
       ][0] // "") as $short

    # LONG_START: press + ddx + non-rocker actions (+ rocker base status if present)
    | ([ $ids2[]
         | select(($all[.]? // null) != null)
         | select($all[.] | hasBtnEq($sid; $press))
         | select($all[.] | hasOp($sid; "ddx"))
         | select(($all[.] | nonRockerActs($rid) | length) > 0)
         | select($all[.] | rockerOkOrNone($rid; baseStatus($btn)))
       ][0] // "") as $ls

    # LONG_END: release + dx + looksLikeStop (+ rocker active status if present)
    | ([ $ids2[]
         | select(($all[.]? // null) != null)
         | select($all[.] | hasBtnEq($sid; $release))
         | select($all[.] | hasOp($sid; "dx"))
         | select($all[.] | looksLikeStop($rid))
         | select($all[.] | rockerOkOrNone($rid; activeStatus($btn)))
       ][0] // "") as $le

    | (if $ls != "" then ($all[$ls] | ddxDur($sid)) else "" end) as $dur
    | { short:$short, long_start:$ls, long_end:$le, threshold_ms: msFromDur($dur) }
  ' <<<"$rules_json"
)"


  if [[ -z "$picked" ]]; then
    echo "WARN(${btn}): picker produced no output; using empty selection" >&2
    picked='{"short":"","long_start":"","long_end":"","threshold_ms":700}'
  fi

  # If jq output is not valid JSON object, also fallback
  if ! jq -e 'type=="object"' >/dev/null 2>&1 <<<"$picked"; then
    echo "WARN(${btn}): picker returned non-object; using empty selection: $picked" >&2
    picked='{"short":"","long_start":"","long_end":"","threshold_ms":700}'
  fi

  short_rule="$(jq -r '.short // ""' <<<"$picked")"
  long_start_rule="$(jq -r '.long_start // ""' <<<"$picked")"
  long_end_rule="$(jq -r '.long_end // ""' <<<"$picked")"
  threshold_ms="$(jq -r '.threshold_ms // 700' <<<"$picked")"

  # bodies
  local short_body ls_body le_body
  short_body="null"; ls_body="null"; le_body="null"
  [[ -n "$short_rule" ]] && short_body="$(jq -c --arg rid "$short_rule" '.[$rid]' <<<"$rules_json")"
  [[ -n "$long_start_rule" ]] && ls_body="$(jq -c --arg rid "$long_start_rule" '.[$rid]' <<<"$rules_json")"
  [[ -n "$long_end_rule" ]] && le_body="$(jq -c --arg rid "$long_end_rule" '.[$rid]' <<<"$rules_json")"

  # strip rocker writes from actions (keep only "real" actions)
  local strip='
    def isRockerWrite($rid):
      (.address == ("/sensors/"+($rid|tostring)+"/state"))
      and ((.method // "PUT") == "PUT")
      and (.body.status? != null);

    def cleaned($rid):
      . as $x
      | ($x // {})
      | .actions = [ (($x.actions // [])[]?) | select(isRockerWrite($rid) | not) ];
  '
   short_body="$(jq -c --argjson rid "$rocker_id" "$strip cleaned(\$rid)" <<<"$short_body" 2>/dev/null || echo "null")"
  ls_body="$(jq -c --argjson rid "$rocker_id" "$strip cleaned(\$rid)" <<<"$ls_body" 2>/dev/null || echo "null")"
  le_body="$(jq -c --argjson rid "$rocker_id" "$strip cleaned(\$rid)" <<<"$le_body" 2>/dev/null || echo "null")"

  # rocker_id may be empty; jq --argjson needs valid JSON
  local rocker_json="null"
  [[ -n "${rocker_id:-}" ]] && rocker_json="$rocker_id"

  # rl_id may be empty too (if you ever call with no RL); keep it safe
  local rlid_json="null"
  [[ -n "${rl_id:-}" ]] && rlid_json="$rl_id"
  local rlname_val="${rl_name:-}"
  # WRITE FILE
  # WRITE FILE
    echo "sensor \"$sid\" "
    echo "rocker \"$rocker_json\" "
    echo "button \"$btn\" "
    echo "press \"$press\" "
    echo "release \"$release\" "
    echo "threshold \"$threshold_ms\" "
    echo "short \"$short_body\" "
    echo "ls \"$ls_body\" "
    echo "le \"$le_body\" "
    echo "rlid \"$rlid_json\" "
    echo "rlname \"$rlname_val\""
exit
jq -n \
    --argjson sensor "$sid" \
    --argjson rocker "$rocker_json" \
    --arg button "$btn" \
    --argjson press "$press" \
    --argjson release "$release" \
    --argjson threshold "$threshold_ms" \
    --argjson short "$short_body" \
    --argjson ls "$ls_body" \
    --argjson le "$le_body" \
    --argjson rlid "$rlid_json" \
    --arg rlname "$rlname_val" '
    def acts($r): ($r.actions // []);
    {
      sensor: $sensor,
      rocker: $rocker,
      button: $button,
      resourcelink: $rlid,
      resourcelink_name: (if $rlname == "" then null else $rlname end),
      short: { name: ($short.name // ($button + " short")), actions: acts($short) },
      long: {
        threshold_ms: $threshold,
        start: { name: ($ls.name // ($button + " long start")), actions: acts($ls) },
        end:   { name: ($le.name // ($button + " long end")),   actions: acts($le) }
      }
    }
    | if ($short == null or $short == {}) then .short.actions=[] else . end
    | if ($ls == null or $ls == {}) then .long.start.actions=[] else . end
    | if ($le == null or $le == {}) then .long.end.actions=[] else . end
  ' | jq '.' >"$file"

  echo "Wrote $file from bridge (resourcelink=$rl_id name='$rl_name' rocker=$rocker_id)" >&2
  msg="  picked($btn):"
  [[ -n "$short_rule"      ]] && msg+=" short=$short_rule"
  [[ -n "$long_start_rule" ]] && msg+=" long_start=$long_start_rule(th=${threshold_ms}ms)"
  [[ -n "$long_end_rule"   ]] && msg+=" long_end=$long_end_rule"
  [[ "$msg" != "  picked($btn):" ]] && echo "$msg" >&2
}



# allow: <sid> all read
if [[ "${arg2,,}" == "all" ]]; then
  [[ "${3:-}" == "read" ]] || die "Usage: $0 <sensorId> all read"

  # Pull bridge state ONCE
  rules_json="$(tcl_get "/rules" | json_norm)"
  sensors_json="$(tcl_get "/sensors" | json_norm)"
  rl_json="$(tcl_get "/resourcelinks" | json_norm)"
  # Find RL that references /sensors/<sid>
  rl_ids="$(jq -r --arg sid "$sid" '
    to_entries[]
    | select((.value.links // []) | any(. == ("/sensors/" + $sid)))
    | .key
  ' <<<"$rl_json")"
  # Find RL that references /sensors/<sid>
  rl_ids="$(jq -r --arg sid "$sid" '
    to_entries[]
    | select((.value.links // []) | any(. == ("/sensors/" + $sid)))
    | .key
  ' <<<"$rl_json")"

  if [[ -z "$rl_ids" ]]; then
    echo "WARN: No resourcelink references /sensors/$sid (reading will produce empty files)" >&2
    rl_id=""
    rl_name=""
    rl_links="[]"
  else
    rl_id="$(
      jq -r --arg sid "$sid" '
        [ to_entries[]
          | select((.value.links // []) | any(. == ("/sensors/" + $sid)))
          | select((.value.classid // 0) == 10050)
          | .key
        ][0] // empty
      ' <<<"$rl_json"
    )"
    [[ -n "$rl_id" ]] || rl_id="$(echo "$rl_ids" | head -n1)"

    rl_name="$(jq -r --arg id "$rl_id" '.[$id].name // ""' <<<"$rl_json")"
    rl_links="$(jq -c --arg id "$rl_id" '.[$id].links // []' <<<"$rl_json")"

    # Dump RL ONCE (only if we actually have one)
    dump_resourcelink_once
  fi

  rl_id="$(
    jq -r --arg sid "$sid" '
      [ to_entries[]
        | select((.value.links // []) | any(. == ("/sensors/" + $sid)))
        | select((.value.classid // 0) == 10050)
        | .key
      ][0] // empty
    ' <<<"$rl_json"
  )"
  [[ -n "$rl_id" ]] || rl_id="$(echo "$rl_ids" | head -n1)"

  rl_name="$(jq -r --arg id "$rl_id" '.[$id].name // ""' <<<"$rl_json")"
  rl_links="$(jq -c --arg id "$rl_id" '.[$id].links // []' <<<"$rl_json")"

  # Dump RL ONCE
  dump_resourcelink_once

  # Now make all 6 button files in THIS process
  for b in $(all_buttons_for_sensor); do
    if read_one_button_from_bridge "$b" "$rl_id" "$rl_name" "$rl_links"; then
      : # ok
    else
      echo "WARN: read failed for ${sid}_${b} (continuing)" >&2
    fi
  done
  exit 0
fi

btn="$(canon_btn "$arg2")" || die "Bad button '$arg2' (allowed: tl tr bl br trl brl; order-insensitive for pairs)"
file="${sid}_${btn}.json"
# read config
if [[ "${3:-}" == "read" ]]; then
  rules_json="$(tcl_get "/rules" | json_norm)"
  sensors_json="$(tcl_get "/sensors" | json_norm)"
  rl_json="$(tcl_get "/resourcelinks" | json_norm)"

  # pick RL referencing sid (or accept optional forced id as before)
  forced_rl_id="${4:-}"
  # if forced_rl_id was provided, we expect it to exist
  if [[ -n "$forced_rl_id" ]]; then
    rl_id="$forced_rl_id"
    rl_name="$(jq -r --arg id "$rl_id" '.[$id].name // ""' <<<"$rl_json")"
    rl_links="$(jq -c --arg id "$rl_id" '.[$id].links // []' <<<"$rl_json")"
    dump_resourcelink_once
  else
    rl_id="$(
      jq -r --arg sid "$sid" '
        [ to_entries[]
          | select((.value.links // []) | any(. == ("/sensors/" + $sid)))
          | select((.value.classid // 0) == 10050)
          | .key
        ][0] // empty
      ' <<<"$rl_json"
    )"

    if [[ -z "$rl_id" ]]; then
      echo "WARN: No resourcelink references /sensors/$sid (reading will produce empty file for $btn)" >&2
      rl_id=""
      rl_name=""
      rl_links="[]"
    else
      rl_name="$(jq -r --arg id "$rl_id" '.[$id].name // ""' <<<"$rl_json")"
      rl_links="$(jq -c --arg id "$rl_id" '.[$id].links // []' <<<"$rl_json")"
      dump_resourcelink_once
    fi
  fi

  read_one_button_from_bridge "$btn" "$rl_id" "$rl_name" "$rl_links"
  exit 0
fi

if [[ ! -f "$file" ]]; then
  echo "❌ Config file not found: $file" >&2
  exit 1
fi

# read values from json
json_sid=$(jq -r '.sensor // empty' "$file")
json_btn=$(jq -r '.button // empty' "$file")

if [[ -z "$json_sid" || -z "$json_btn" ]]; then
  echo "❌ Invalid config: missing sensor or button in $file" >&2
  exit 1
fi

# normalize button order (trl == lrt == rtl)
norm() {
  echo "$1" | sed 's/./&\n/g' | sort | tr -d '\n'
}

want_btn="$(norm "$btn")"
have_btn="$(norm "$json_btn")"

# fix sensor id if wrong
if [[ "$json_sid" != "$sid" ]]; then
  echo "ℹ️  Fixing sensor id in $file: $json_sid → $sid"
  jq --arg sid "$sid" '.sensor = ($sid|tonumber)' "$file" > "$file.tmp" \
    && mv "$file.tmp" "$file"
fi

# fix button name if order differs
if [[ "$want_btn" != "$have_btn" ]]; then
  echo "❌ Button mismatch:"
  echo "    filename expects: $btn"
  echo "    json contains:    $json_btn"
  exit 1
fi

[[ -f "$file" ]] || die "Missing model file: $file"

read -r press release < <(press_release "$btn") || die "No mapping for button '$btn'"

# Patch model file basics (sensor/button/mapping)
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
jq --argjson sid "$sid" --arg btn "$btn" --arg press "$press" --arg release "$release" '
  .sensor = $sid
  | .button = $btn
  | .mapping.short.press = ($press|tonumber)
  | .mapping.short.release = ($release|tonumber)
  | .mapping.long.press = ($press|tonumber)
  | .mapping.long.release = ($release|tonumber)
  | .long.threshold_ms = (.long.threshold_ms // 700)
' "$file" >"$tmp"
mv "$tmp" "$file"

# Decide which rules should exist:
# - short exists if .short.actions length > 0
# - long exists if (.long.start.actions length > 0) OR (.long.end.actions length > 0)
want_short="$(jq -r '(.short.actions // []) | length > 0' "$file")"
want_long="$(jq -r '((.long.start.actions // [])|length > 0) or ((.long.end.actions // [])|length > 0)' "$file")"

if [[ "$want_short" != "true" && "$want_long" != "true" ]]; then
  echo "Nothing to apply: both short and long are empty."
  echo "Tip: if you want deletion, run: $0 $sid -delete"
  exit 0
fi


# Pull current bridge state
rules_json="$(tcl_get "/rules" | json_norm)"
sensors_json="$(tcl_get "/sensors" | json_norm)"
rl_json="$(tcl_get "/resourcelinks" | json_norm)"
# Ensure rocker sensor exists (id stored in model as .rocker if present)
rocker_id="$(jq -r '.rocker // empty' "$file")"
if [[ -z "$rocker_id" || "$rocker_id" == "null" ]]; then
  # Try to find an existing CLIPGenericStatus we previously created for this sensor/button
  # by name convention.
  rocker_name="FoH rocker ${sid}"
  found="$(jq -r --arg name "$rocker_name" '
    to_entries[]
    | select(.value.type=="CLIPGenericStatus" and (.value.name // "")==$name)
    | .key
    | first
  ' <<<"$sensors_json" 2>/dev/null || true)"

  if [[ -n "${found:-}" && "${found:-null}" != "null" ]]; then
    rocker_id="$found"
    echo "Found rocker sensor: $rocker_id ($rocker_name)"
  else
    echo "Creating rocker sensor (CLIPGenericStatus) ..."
    # Hue v1: POST /sensors expects object body (no id)
    # Keep it minimal.
    rocker_body="$(jq -c -n --arg name "$rocker_name" '
      {
        "name": $name,
        "type": "CLIPGenericStatus",
        "modelid": "FoHRocker",
        "manufacturername": "tcl-hue",
        "swversion": "1.0",
        "uniqueid": ("foh-rocker-" + ($name|tostring)),
        "recycle": false
      }
    ')"
    if (( $dry_run )); then
      # In dry-run, tcl_post prints non-JSON -> do NOT parse it with jq.
      rocker_id="DRY_ROCKER_NEW"
      echo "DRY-RUN: would POST /sensors with body:" >&2
      echo "$rocker_body" | jq '.' >&2
      echo "DRY-RUN: would create rocker sensor id: $rocker_id" >&2
    else
      resp="$(tcl_post "/sensors" "$rocker_body")"
      resp_json="$(printf '%s\n' "$resp" | json_norm)"
      rocker_id="$(jq -r '.[0].success.id // empty' <<<"$resp_json")"
      [[ -n "$rocker_id" ]] || die "Failed to create rocker sensor. Response: $resp"
      echo "Created rocker sensor id: $rocker_id"

      # Write it into file
      tmp="$(mktemp)"
      jq --argjson rid "$rocker_id" '.rocker = $rid' "$file" >"$tmp"
      mv "$tmp" "$file"
    fi
  fi
else
  # Validate rocker exists
  ok="$(jq -r --arg id "$rocker_id" 'has($id)' <<<"$sensors_json")"
  [[ "$ok" == "true" ]] || die "Model says rocker=$rocker_id but it does not exist on bridge"
fi

# Generate desired rules JSON (short/long_start/long_end) from model using your jq filter:

# Effective rocker id (use existing, else new/dry placeholder)
rocker_id_in_file="$(jq -r '.rocker // empty' "$file")"
if [[ -n "$rocker_id_in_file" && "$rocker_id_in_file" != "null" ]]; then
  rocker_effective="$rocker_id_in_file"
else
  rocker_effective="${rocker_id:-}"
fi

# dry-run / safety: jq --argjson needs JSON (number/null), not "DRY_ROCKER_NEW"
if [[ ! "${rocker_effective:-}" =~ ^[0-9]+$ ]]; then
  rocker_effective=99999
fi

desired_rules="$(
  jq --argjson rid "$rocker_effective" '.rocker = $rid' "$file" \
  | jq -f "$jq_filter"
)"

echo "--- implied rocker writes ---"
echo "$desired_rules" | jq -r --arg rid "$rocker_effective" '
  .long_start.actions[]?
  | select(type=="object")
  | select(.address == ("/sensors/"+($rid|tostring)+"/state"))
  | select(.body? and (.body.status? != null))
  | "long_start: \(.address) status=\(.body.status)"
'
echo "$desired_rules" | jq -r --arg rid "$rocker_effective" '
  .long_end.actions[]?
  | select(type=="object")
  | select(.address == ("/sensors/"+($rid|tostring)+"/state"))
  | select(.body? and (.body.status? != null))
  | "long_end:   \(.address) status=\(.body.status)"
'

# Apply/replace rules; track ids for resourcelink
rule_ids=()

apply_one_rule() {
  local key="$1"   # short|long_start|long_end
  local body name existing_id resp new_id

  body="$(jq -c --arg k "$key" '.[$k]' <<<"$desired_rules")"
  name="$(jq -r --arg k "$key" '.[$k].name' <<<"$desired_rules")"

  existing_id="$(find_rule_id_by_name_for_sid "$name" "$sid")"

  if [[ -n "$existing_id" && "$existing_id" != "null" ]]; then
    echo "Replacing rule $existing_id ($name)"
    if [[ "${dry_run:-0}" -eq 1 ]]; then
      echo "DRY-RUN: would PUT /rules/$existing_id with body:"; echo "$body" | jq .
    else
      tcl_put "/rules/$existing_id" "$body" >/dev/null || true
    fi
    rule_ids+=("$existing_id")
  else
    echo "Creating rule ($name)"
    if [[ "${dry_run:-0}" -eq 1 ]]; then
      echo "DRY-RUN: would POST /rules with body:"; echo "$body" | jq .
      new_id="DRY_RULE_${key}"
    else
      resp="$(tcl_post "/rules" "$body")"
      resp_json="$(printf '%s\n' "$resp" | json_norm)"
      new_id="$(jq -r '.[0].success.id // empty' <<<"$resp_json")"
      [[ -n "$new_id" ]] || die "Failed creating rule '$name'. Response: $resp"
    fi
    rule_ids+=("$new_id")
  fi
}
# Enforce exact set:
# - if only short wanted: create/replace short; delete long rules for this button (by name match)
# - if only long wanted: create/replace long_start+long_end; delete short
# - if both wanted: keep all three
#
# We detect "managed" rules for this model by matching the names that the filter produces.
short_name="$(jq -r '.short.name' <<<"$desired_rules")"
ls_name="$(jq -r '.long_start.name' <<<"$desired_rules")"
le_name="$(jq -r '.long_end.name' <<<"$desired_rules")"
delete_rule_by_name_if_exists() {
  local name="$1"
  local rid
  rid="$(find_rule_id_by_name_for_sid "$name" "$sid")"
  if [[ -n "$rid" && "$rid" != "null" ]]; then
    echo "Deleting rule $rid ($name)"
    tcl_del "/rules/$rid" >/dev/null || true
  fi
}
if [[ "$want_short" == "true" ]]; then
  apply_one_rule "short"
else
  delete_rule_by_name_if_exists "$short_name"
fi

if [[ "$want_long" == "true" ]]; then
  apply_one_rule "long_start"
  apply_one_rule "long_end"
else
  delete_rule_by_name_if_exists "$ls_name"
  delete_rule_by_name_if_exists "$le_name"
fi

# Ensure resourcelink exists and points to: sensor, rocker, and created rule ids
# Name convention: "FoH <sid> <btn>"
rl_name="FoH ${sid} ${btn}"
rl_desc="Resources for FoH ${sid} ${btn}"
# Build links array
links_json="$(jq -n --arg sid "$sid" --arg rid "$rocker_id" --argjson rules "$(printf '%s\n' "${rule_ids[@]}" | jq -R . | jq -s .)" '
  ([
    ("/sensors/" + $sid),
    ("/sensors/" + $rid)
  ] + ($rules | map("/rules/" + .)))
')"

# Find existing resourcelink by exact name
existing_rl_id="$(jq -r --arg name "$rl_name" '
  to_entries[]
  | select((.value.name // "") == $name)
  | .key
  | first
' <<<"$rl_json")"

rl_body="$(jq -n --arg name "$rl_name" --arg desc "$rl_desc" --argjson links "$links_json" '
  {
    "name": $name,
    "description": $desc,
    "type": "Link",
    "classid": 10050,
    "recycle": false,
    "links": $links
  }
')"
echo "--- resourcelink would be ---"
echo "$rl_body" | jq .

if [[ -n "$existing_rl_id" && "$existing_rl_id" != "null" ]]; then
  echo "Replacing resourcelink $existing_rl_id ($rl_name)"
  tcl_put "/resourcelinks/$existing_rl_id" "$rl_body" >/dev/null || true
else
  echo "Creating resourcelink ($rl_name)"
  resp="$(tcl_post "/resourcelinks" "$rl_body")"
  resp_clean="$(printf '%s' "$resp" | awk '
  {
    line = line $0 "\n"
  }
  END {
    # find last opening "[" for an array
    start = match(line, /\[[[:space:]\n]*\{/)
    if (start > 0) {
      # print from that bracket to end, trimming before it
      print substr(line, start)
    }
  }
  ')"

  new_id="$(jq -r '.[0].success.id // empty' <<<"$resp_clean")"
  [[ -n "$new_id" ]] || die "Failed creating resourcelink. Response: $resp"
fi

echo "OK applied $file"
echo "  rocker=$rocker_id rules=$(IFS=,; echo "${rule_ids[*]}") resourcelink-name='$rl_name'"
