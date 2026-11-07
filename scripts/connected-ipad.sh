#!/usr/bin/env bash
# Prints the hardware UDID of the first iPad connected to this Mac, or fails with a hint.
# Pick another one with DEVICE=<udid or name>.
set -euo pipefail

json=$(mktemp -t fp-devices)
trap 'rm -f "$json"' EXIT
xcrun devicectl list devices --json-output "$json" >/dev/null 2>&1 || true

python3 - "$json" "${DEVICE:-}" <<'PY'
import json, sys
path, wanted = sys.argv[1], sys.argv[2]
try:
    devices = json.load(open(path))["result"]["devices"]
except Exception:
    devices = []
for d in devices:
    hw, props = d.get("hardwareProperties", {}), d.get("deviceProperties", {})
    udid, name = hw.get("udid", ""), props.get("name", "")
    if wanted and wanted not in (udid, name):
        continue
    if not wanted and hw.get("deviceType") != "iPad":
        continue
    if d.get("connectionProperties", {}).get("pairingState") != "paired":
        continue
    print(udid)
    sys.exit(0)
print("connected-ipad: no paired iPad found. Connect it with a cable, unlock it, tap Trust,",
      "and turn on Settings > Privacy & Security > Developer Mode.", file=sys.stderr)
sys.exit(1)
PY
