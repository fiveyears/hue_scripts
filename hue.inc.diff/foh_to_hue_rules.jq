# foh_to_hue_rules.jq
#
# Input: human model (button json)
# Output: object {short, long_start, long_end}
#   - long_end is null if long.mode == "oneshot"

def rule($name; $conds; $acts):
  {
    "name": $name,
    "status": "enabled",
    "recycle": false,
    "conditions": $conds,
    "actions": $acts
  };

def c_eq($addr; $val):
  { "address": $addr, "operator": "eq", "value": ($val|tostring) };

def c_dx($addr):
  { "address": $addr, "operator": "dx" };

def c_ddx($addr; $dur):
  { "address": $addr, "operator": "ddx", "value": $dur };

def a_put($addr; $body):
  { "address": $addr, "method": "PUT", "body": $body };

def normActions:
  ( . // [] )
  | map({
      address: .address,
      method: (.method // "PUT"),
      body: .body
    });

# ---------------------------------------
# Avoid duplicate rocker status writes
# ---------------------------------------
def hasRockerStatus($rid; $val):
  any(.[]?;
    (.address == ("/sensors/" + ($rid|tostring) + "/state"))
    and ((.method // "PUT") == "PUT")
    and ((.body.status? // null) == $val)
  );

def ensureRockerStatus($rid; $val):
  if hasRockerStatus($rid; $val)
  then .
  else . + [ a_put(("/sensors/" + ($rid|tostring) + "/state"); {"status": $val}) ]
  end;

# ---------------------------------------
# Duration: threshold_ms -> PT00:00:0.700
# ---------------------------------------
def durFromMs($ms):
  ($ms|tonumber) as $m
  | ($m / 1000.0) as $s
  | ("PT00:00:" + ($s|tostring));

. as $m
| ($m.sensor|tostring) as $sid
| ($m.rocker|tostring) as $rid
| ($m.mapping.short.press) as $short_press
| ($m.mapping.long.press) as $long_press
| ($m.mapping.long.release) as $long_release
| ($m.mapping.long.threshold_ms // 700) as $th
| (durFromMs($th)) as $dur
| ($m.long.mode // "hold") as $mode
| {
    short:
      rule(
        ($m.short.name // "short");
        [
          c_eq(("/sensors/" + $sid + "/state/buttonevent"); $short_press),
          c_dx(("/sensors/" + $sid + "/state/lastupdated"))
        ];
        ($m.short.actions | normActions)
      ),

    long_start:
      (
        if $mode == "oneshot" then
          # One-shot long press: no rocker gating, no ddx needed unless you want it.
          # If you *do* want long-only, keep ddx so it triggers only after threshold.
          rule(
            ($m.long.start.name // "long");
            [
              c_eq(("/sensors/" + $sid + "/state/buttonevent"); $long_press),
              c_ddx(("/sensors/" + $sid + "/state/lastupdated"); $dur),
              c_dx(("/sensors/" + $sid + "/state/lastupdated"))
            ];
            ($m.long.start.actions | normActions)
          )
        else
          # Hold-mode start: require rocker==0 and set rocker->1
          rule(
            ($m.long.start.name // "long start");
            [
              c_eq(("/sensors/" + $sid + "/state/buttonevent"); $long_press),
              c_ddx(("/sensors/" + $sid + "/state/lastupdated"); $dur),
              c_eq(("/sensors/" + $rid + "/state/status"); 0)
            ];
            (
              ($m.long.start.actions | normActions)
              | ensureRockerStatus($rid; 1)
            )
          )
        end
      ),

    long_end:
      (
        if $mode == "oneshot" then
          null
        else
          rule(
            ($m.long.end.name // "long end");
            [
              c_eq(("/sensors/" + $sid + "/state/buttonevent"); $long_release),
              c_dx(("/sensors/" + $sid + "/state/lastupdated")),
              c_eq(("/sensors/" + $rid + "/state/status"); 1)
            ];
            (
              ($m.long.end.actions | normActions)
              | ensureRockerStatus($rid; 0)
            )
          )
        end
      )
  }
  