#!/bin/bash
# The public crayon kit catalog must contain exactly the KitSlot cases (an allowlist, so a
# private picture can never slip into the public catalog), and every picture must keep its
# vector data so large icons stay sharp.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CATALOG="$ROOT/ios/KitArt/Resources/KitArt.xcassets"
SLOTS="$ROOT/ios/KitArt/KitSlot.swift"
FAIL=0

catalog_names="$(find "$CATALOG" -maxdepth 1 -name '*.imageset' -exec basename {} .imageset \; | sort)"
slot_names="$(sed -n 's/^ *case \(.*\)$/\1/p' "$SLOTS" | tr ',' '\n' | tr -d ' ' | grep -v '^$' | sort)"

if [ "$catalog_names" = "$slot_names" ]; then
  echo "PASS catalog matches KitSlot ($(echo "$slot_names" | wc -l | tr -d ' ') slots)"
else
  echo "FAIL catalog and KitSlot differ:"
  diff <(echo "$slot_names") <(echo "$catalog_names")
  FAIL=1
fi

for set in "$CATALOG"/*.imageset; do
  if ! grep -q '"preserves-vector-representation" *: *true' "$set/Contents.json"; then
    echo "FAIL $(basename "$set") does not preserve vector data"
    FAIL=1
  fi
done
[ "$FAIL" -eq 0 ] && echo "PASS every imageset preserves vector data"
exit "$FAIL"
