#!/bin/bash
# 
# Usage: progfile [-a -b -c -h]
# 
# Parameter:
#    -0 | --start  ...
#    -1 | --pair  ...
#    -2 | --quick  ...
#    -3 | --rules_tr  ...
#    -4 | --clone  ...
#    -h | --help   ... this help
# 
### 
# Created with /Users/ivo/bin/crea at 2025-12-28 10:10:20
#
PROGNAME="${BASH_SOURCE[0]:-${(%):-%N}}"    # script name (basename)
PROGDIR="$(dirname $PROGNAME)"
PROGNAME="$(basename $PROGNAME)"

Help() {   # Output Full header comments as documentation
  if [ -n "$1" ]; then
    echo "$1"
    exit 1
  fi
  sed >&2 -n "1d; /^###/q; /^#/!q; s/^#//; s/^ //; s/progfile/$PROGNAME/; p" \
          "$PROGDIR/$PROGNAME"
  exit 10
}
set -- "-3"
if [ -z "$1" ]; then
	  echo "No option is given!"
	  Help
fi
unset START;unset PAIR;unset QUICK;unset PARA3;unset CLONE
while [ $# -gt 0 ]; do
  case "$1" in

  --help) Help ;;                                # Basic help
  --start) START=1 ;;                            # Procedure A
  --pair) PAIR=1 ;;                              # Procedure B
  --quick) QUICK=1 ;;                            # Procedure C
  --rules_tr) PARA3=1 ;;                              # Procedure C
  --clone) CLONE=1 ;;                            # Procedure C

  --) shift; break ;;                            # forced end of user options
  --*) echo "Unknown option \"$1\"";Help;;       # unknown option
  -*) lines="$(echo "${1:1}" | sed -e "s/./&\n/g" | grep . )"
      while read -r c; do
        case "$c" in
          h) Help ;;                             # Basic help
          0) START=1 ;;                          # Procedure A
          1) PAIR=1 ;;                           # Procedure B
          2) QUICK=1 ;;                          # Procedure C
          3) PARA3=1 ;;                          # Procedure C
          4) CLONE=1 ;;                          # Procedure C
          *) echo "Unknown option \"$c\"";Help;; # unknown option
        esac
      done <<< "$lines";;
  *)  break ;;                                   # unforced  end of user options
  esac
  shift                                          # next option
done
cd "$PROGDIR"
# starting
if [ -n "$START" ]; then
  [[ -f hue_before.json && -f hue_after.json ]] || Help "hue_before.json or hue_after.json are missing!"
  jq -S -n \
    --slurpfile before "./hue_before.json" \
    --slurpfile after  "./hue_after.json" \
    '{before: $before[0], after: $after[0]}' > "./hue_pair.json"
fi
# pairing
if [ -n "$PAIR" ]; then
  [[ -f hue_pair.json ]] || Help "hue_pair.json is missing!"
jq -S '
def keys0: (keys_unsorted // []);
def objdiff($b; $a):
  # $b = before section object, $a = after section object
  # output: {added:{}, removed:{}, changed:{}}
  ( ($b|keys0) as $bk
  | ($a|keys0) as $ak
  | ($ak - $bk) as $addedKeys
  | ($bk - $ak) as $removedKeys
  | ($bk + $ak | unique) as $allKeys
  | {
      added:   (reduce $addedKeys[] as $k ({}; . + {($k): $a[$k]})),
      removed: (reduce $removedKeys[] as $k ({}; . + {($k): $b[$k]})),
      changed: (reduce $allKeys[] as $k ({};
                 if ($b[$k] != null and $a[$k] != null and $b[$k] != $a[$k])
                 then . + {($k): {before:$b[$k], after:$a[$k]}}
                 else . end))
    }
  );

{
  rules:         objdiff(.before.rules;         .after.rules),
  schedules:     objdiff(.before.schedules;     .after.schedules),
  resourcelinks: objdiff(.before.resourcelinks; .after.resourcelinks),
  sensors:       objdiff(.before.sensors;       .after.sensors),
  scenes:        objdiff(.before.scenes;        .after.scenes),
  groups:        objdiff(.before.groups;        .after.groups)
}
' hue_pair.json > hue_diff.json
fi
# quick
# 
if [ -n "$QUICK" ]; then
jq 'to_entries[] | {section:.key,
  added:(.value.added|length),
  removed:(.value.removed|length),
  changed:(.value.changed|length)
}' hue_diff.json
fi
#  sensor 33, create
if [ -n "$PARA3" ]; then
  jq -f foh_to_hue_rules.jq tl.json >| tl_rules.json
  jq -f foh_to_hue_rules.jq tr.json >| tr_rules.json
  jq -f foh_to_hue_rules.jq bl.json >| bl_rules.json
  jq -f foh_to_hue_rules.jq br.json >| br_rules.json
  jq -f foh_to_hue_rules.jq trl.json >| trl_rules.json
  jq -f foh_to_hue_rules.jq brl.json >| brl_rules.json
fi
if [ -n "$CLONE" ]; then
  jq --arg target tr -f clone_button.jq tl.json > tr.json
  jq --arg target bl -f clone_button.jq tl.json > bl.json
  jq --arg target br -f clone_button.jq tl.json > br.json
fi
if [ -n "$1" ]; then
	echo "$1"
fi
