#!/bin/bash
# The public crayon kit catalog must contain exactly the KitSlot cases (an allowlist, so a
# private picture can never slip into the public catalog), and every picture must keep its
# vector data so large icons stay sharp. Picture rigs add run images `rig-<slot>-<n>` (parts of
# a slot's picture, not slots); each must belong to a KitSlot case, as must every rig in rigs.json.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CATALOG="$ROOT/ios/KitArt/Resources/KitArt.xcassets"
SLOTS="$ROOT/ios/KitArt/KitSlot.swift"
FAIL=0

catalog_names="$(find "$CATALOG" -maxdepth 1 -name '*.imageset' ! -name 'rig-*' -exec basename {} .imageset \; | sort)"
rig_slots="$(find "$CATALOG" -maxdepth 1 -name 'rig-*.imageset' -exec basename {} .imageset \; | sed 's/^rig-\(.*\)-[0-9]*$/\1/' | sort -u)"
slot_names="$(sed -n 's/^ *case \(.*\)$/\1/p' "$SLOTS" | tr ',' '\n' | tr -d ' ' | grep -v '^$' | sort)"

if [ "$catalog_names" = "$slot_names" ]; then
  echo "PASS catalog matches KitSlot ($(echo "$slot_names" | wc -l | tr -d ' ') slots)"
else
  echo "FAIL catalog and KitSlot differ:"
  diff <(echo "$slot_names") <(echo "$catalog_names")
  FAIL=1
fi

stray="$(comm -23 <(echo "$rig_slots" | grep -v '^$') <(echo "$slot_names"))"
if [ -n "$stray" ]; then
  echo "FAIL rig images for unknown slots: $stray"
  FAIL=1
fi
RIGS="$CATALOG/KitRigs.dataset/rigs.json"
if [ -f "$RIGS" ]; then
  rig_json_slots="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); r=d.get("rigs", d); print("\n".join(k for k in r if isinstance(r[k], dict)))' "$RIGS" | sort -u)"
  stray="$(comm -23 <(echo "$rig_json_slots" | grep -v '^$') <(echo "$slot_names"))"
  if [ -n "$stray" ]; then
    echo "FAIL rigs.json names unknown slots: $stray"
    FAIL=1
  else
    echo "PASS rigs belong to KitSlot cases ($(echo "$rig_slots" | grep -c .) rigged slots)"
  fi
fi

for set in "$CATALOG"/*.imageset; do
  if ! grep -q '"preserves-vector-representation" *: *true' "$set/Contents.json"; then
    echo "FAIL $(basename "$set") does not preserve vector data"
    FAIL=1
  fi
done
[ "$FAIL" -eq 0 ] && echo "PASS every imageset preserves vector data"
exit "$FAIL"
