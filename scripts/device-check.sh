#!/usr/bin/env bash
# After `make device` launches the app: waits a few seconds, fails if the iPad wrote a crash
# report for the app since the launch (printing the crashing frames and whether the crashed
# binary is the one just built), and saves a screenshot to bazel-device/screen.png.
# Needs pymobiledevice3 (`uv tool install pymobiledevice3`) and works best over a cable.
# Usage: scripts/device-check.sh <app name> <path to the built executable>
set -euo pipefail

app="$1"
binary="$2"
out="$(dirname "$0")/../bazel-device"
since=$(date -v-20S +%Y-%m-%d-%H%M%S)

if ! command -v pymobiledevice3 >/dev/null 2>&1; then
    echo "device-check: pymobiledevice3 not installed; look at the iPad yourself" \
         "(uv tool install pymobiledevice3)." >&2
    exit 0
fi

sleep 6
# Over Wi-Fi alone pymobiledevice3 usually cannot reach the iPad: say "not checked", never "no crash".
if ! listing=$(pymobiledevice3 crash ls 2>&1) || grep -q "ERROR" <<<"$listing"; then
    echo "device-check: NOT CHECKED - pymobiledevice3 cannot reach the iPad (Wi-Fi only?)." \
         "Plug in the cable and run: scripts/device-check.sh $app $binary" >&2
    exit 0
fi
crashes=$(grep -o "/${app}-[0-9-]*\.ips" <<<"$listing" | sort || true)
new=$(printf '%s\n' "$crashes" | awk -v app="/${app}-" -v since="$since" \
    'length($0) { stamp = substr($0, length(app) + 1, 17); if (stamp >= since) print }' | tail -1)

if [[ -n "$new" ]]; then
    dir=$(mktemp -d -t fp-crash)
    pymobiledevice3 crash pull "$dir" "$new" >/dev/null 2>&1 || true
    report=$(find "$dir" -name '*.ips' | head -1)
    built=$(dwarfdump --uuid "$binary" | awk '{print tolower($2)}')
    echo "device-check: the app crashed after launch ($new)." >&2
    if [[ -n "$report" ]]; then
        python3 - "$report" "$app" "$built" <<'PY' >&2
import json, sys
report, app, built = sys.argv[1:]
data = json.loads(open(report).read().split("\n", 1)[1])
image = next((i for i in data["usedImages"] if i.get("name") == app), {})
crashed = image.get("uuid", "?")
print(f"  exception: {data.get('exception', {}).get('type')}")
print(f"  crashed binary {crashed}; built binary {built}"
      + ("" if crashed == built else "  <- NOT the new build: the install did not replace it"))
thread = next(t for t in data["threads"] if t.get("triggered"))
for frame in thread["frames"][:8]:
    print(f"  {data['usedImages'][frame['imageIndex']].get('name')}  {frame.get('symbol', '?')}")
PY
    fi
    exit 1
fi

if pymobiledevice3 developer dvt screenshot "$out/screen.png" >/dev/null 2>&1; then
    echo "device-check: no crash; screenshot in bazel-device/screen.png"
else
    echo "device-check: no crash; screenshot failed (Wi-Fi only? plug in the cable)." >&2
fi
