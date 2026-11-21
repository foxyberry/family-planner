#!/bin/bash
# `make driver-check`: the platform-neutral journeys (ios/Journeys/Tests/Driver/journeys/*.json) on
# the connected iPad, through the agent driver. A light check when the driver, the contract or test
# mode changes; manual, never in CI or pre-push.
#   1. install: `make device` (debug build), unless SKIP_INSTALL=1;
#   2. for each journey: launch the app in that journey's world (test mode: -fpNow, -fpFamily,
#      -fpSkipFaceID, -fpDriver; the stored family is never read or changed), forward port 8790 over
#      USB, and run it with tools/driver/fp-driver.py;
#   3. relaunch the app without flags (normal mode) whatever happened.
# It names the step that failed: install, launch, connect or journey.
#
# Usage: scripts/driver-check.sh [journey name ...]   (default: every journey file)
# Exit code: 0 = every journey passed, 1 = a step failed.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
JOURNEYS="ios/Journeys/Tests/Driver/journeys"
BUNDLE_ID="io.github.foxyberry.familyplanner"

fail() { echo "driver-check: FAILED at $1" >&2; exit 1; }

UDID="$(scripts/connected-ipad.sh)" || fail "connect (no iPad on USB)"
names=("$@")
if [ "${#names[@]}" -eq 0 ]; then
  for f in "$JOURNEYS"/*.json; do names+=("$(basename "$f" .json)"); done
fi

if [ "${SKIP_INSTALL:-}" != "1" ]; then
  # 8 GB Mac: one Bazel command at a time.
  while pgrep -f "bazel(isk)? .*(build|test|run|query)" >/dev/null; do sleep 20; done
  echo "driver-check: installing the debug build"
  log="$(mktemp -t driver-check)"
  make device >"$log" 2>&1 || { grep -vE "warning" "$log" | tail -5 >&2; fail "install"; }
fi

pymobiledevice3 usbmux forward --serial "$UDID" 8790 8790 >/dev/null 2>&1 &
forward=$!
normal() {
  kill "$forward" 2>/dev/null && wait "$forward" 2>/dev/null
  xcrun devicectl device process launch --terminate-existing --device "$UDID" "$BUNDLE_ID" >/dev/null 2>&1
}
trap normal EXIT

passed=0
for name in "${names[@]}"; do
  file="$JOURNEYS/$name.json"
  [ -f "$file" ] || fail "journey ($file not found)"
  read -r now family skip < <(python3 -c 'import json, sys
w = json.load(open(sys.argv[1])).get("world", {})
print(w.get("now", "2026-11-10T07:30"), w.get("family", "empty"), "-fpSkipFaceID" if w.get("faceID", "success") == "success" else "")' "$file")
  echo "driver-check: $name (family $family, $now)"
  xcrun devicectl device process launch --terminate-existing --device "$UDID" "$BUNDLE_ID" \
    -- -fpNow "$now" -fpFamily "$family" $skip -fpDriver >/dev/null 2>&1 || fail "launch ($name)"
  python3 tools/driver/fp-driver.py run "$file" || fail "journey ($name)"
  passed=$((passed + 1))
done
echo "driver-check: ${passed} journey(s) passed on the iPad"
