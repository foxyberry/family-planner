#!/bin/bash
# The agent driver's parity contract stays true (ios/Journeys/Tests/Driver/PROTOCOL.md):
#   - every `ios` binding in contract.json names something in its screen's file: an action's
#     `case <name>` and a field's `var|let <name>`, so a renamed action or field fails here;
#   - every journey file in Driver/journeys uses only the contract: `do` names `<screen>.<action>`
#     with exactly the contract's argument names, and `expect` names `screen`, a field of some
#     screen, or an app field.
#
# Usage: check-driver-contract.sh [repo root]   (default: this repository)
# Exit code: 0 = the contract and the journey files hold, 1 = a broken name.
set -u

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
DRIVER="$ROOT/ios/Journeys/Tests/Driver"
[ -f "$DRIVER/contract.json" ] || exit 0

python3 - "$ROOT" "$DRIVER" <<'EOF'
import json, os, re, sys

root, driver = sys.argv[1], sys.argv[2]
problems = []

def code_of(path):
    full = os.path.join(root, path)
    if not os.path.isfile(full):
        problems.append(f"contract.json: {path} does not exist")
        return ""
    return "\n".join(l for l in open(full, encoding="utf-8") if not l.lstrip().startswith("//"))

contract = json.load(open(os.path.join(driver, "contract.json"), encoding="utf-8"))
fields_by_screen, actions = {}, {}
app_fields = set()

def check_bindings(owner, entry, kind_fields, kind_actions):
    code = code_of(entry["ios"]["file"])
    for f in entry.get("fields", []):
        if code and not re.search(rf"\b(var|let)\s+{re.escape(f['ios'])}\b", code):
            problems.append(f"contract.json: {owner}.{f['name']}: no var or let {f['ios']} in {entry['ios']['file']}")
        kind_fields.add(f["name"])
    for a in entry.get("actions", []):
        if code and not re.search(rf"\bcase\s+{re.escape(a['ios'])}\b", code):
            problems.append(f"contract.json: {owner}.{a['name']}: no case {a['ios']} in {entry['ios']['file']}")
        kind_actions[f"{owner}.{a['name']}"] = set(a.get("args", {}))

check_bindings("app", contract["app"], app_fields, {})
screen_ids = set()
for screen in contract["screens"]:
    screen_ids.add(screen["id"])
    fields_by_screen[screen["id"]] = set()
    check_bindings(screen["id"], screen, fields_by_screen[screen["id"]], actions)
all_fields = set().union(*fields_by_screen.values()) | app_fields | {"screen"}

journeys = os.path.join(driver, "journeys")
for name in sorted(os.listdir(journeys)) if os.path.isdir(journeys) else []:
    if not name.endswith(".json"):
        continue
    rel = f"journeys/{name}"
    try:
        journey = json.load(open(os.path.join(journeys, name), encoding="utf-8"))
    except ValueError as error:
        problems.append(f"{rel}: not JSON ({error})")
        continue
    for i, step in enumerate(journey.get("steps", []), 1):
        if "do" in step:
            want = actions.get(step["do"])
            if want is None:
                problems.append(f"{rel} step {i}: {step['do']} is not in the contract")
            elif set(step.get("args", {})) != want:
                problems.append(f"{rel} step {i}: {step['do']} takes {sorted(want)}, got {sorted(step.get('args', {}))}")
        elif "expect" in step:
            for key, value in step["expect"].items():
                if key not in all_fields:
                    problems.append(f"{rel} step {i}: {key} is not a contract field")
                if key == "screen" and value not in screen_ids:
                    problems.append(f"{rel} step {i}: screen {value} is not in the contract")
        else:
            problems.append(f"{rel} step {i}: neither do nor expect")

for p in problems:
    print(p, file=sys.stderr)
sys.exit(1 if problems else 0)
EOF
