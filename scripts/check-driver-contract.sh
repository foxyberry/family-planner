#!/bin/bash
# The agent driver's parity contract stays true (ios/Journeys/Tests/Driver/PROTOCOL.md):
#   - every `ios` binding in contract.json names something in its screen's file: an action's
#     `case <name>` (`binding:<field>` needs `case binding` and that field's var), and a field's
#     `var|let <name>`, so a renamed action or field fails here;
#   - every journey file in Driver/journeys uses only the contract: `do` names `<screen>.<action>`
#     with exactly the contract's argument names; `expect` names `screen`, an app field, or a field
#     of the screen the journey last expected (with one of its listed values); and `same as` names
#     a Swift journey test that exists.
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
fields_by_screen, actions, values = {}, {}, {}
app_fields = set()

def check_bindings(owner, entry, kind_fields, kind_actions):
    code = code_of(entry["ios"]["file"])
    for f in entry.get("fields", []):
        if code and not re.search(rf"\b(var|let)\s+{re.escape(f['ios'])}\b", code):
            problems.append(f"contract.json: {owner}.{f['name']}: no var or let {f['ios']} in {entry['ios']['file']}")
        kind_fields.add(f["name"])
        if "values" in f:
            values[(owner, f["name"])] = f["values"]
    for a in entry.get("actions", []):
        case, _, field = a["ios"].partition(":")
        if code and not re.search(rf"\bcase\s+{re.escape(case)}\b", code):
            problems.append(f"contract.json: {owner}.{a['name']}: no case {case} in {entry['ios']['file']}")
        if code and field and not re.search(rf"\b(var|let)\s+{re.escape(field)}\b", code):
            problems.append(f"contract.json: {owner}.{a['name']}: no var or let {field} in {entry['ios']['file']}")
        kind_actions[f"{owner}.{a['name']}"] = set(a.get("args", {}))

check_bindings("app", contract["app"], app_fields, {})
screen_ids = set()
for screen in contract["screens"]:
    screen_ids.add(screen["id"])
    fields_by_screen[screen["id"]] = set()
    check_bindings(screen["id"], screen, fields_by_screen[screen["id"]], actions)
tests_dir = os.path.join(root, "ios/Journeys/Tests")

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
    same = journey.get("same as", "").split(" ")[0]
    cls, _, test = same.partition(".")
    swift = os.path.join(tests_dir, f"{cls}.swift")
    if not test or not os.path.isfile(swift) or not re.search(rf"\bfunc\s+{re.escape(test)}\b", open(swift, encoding="utf-8").read()):
        problems.append(f"{rel}: same as {same or '(none)'}: no such journey test")
    current = None
    for i, step in enumerate(journey.get("steps", []), 1):
        if "do" in step:
            want = actions.get(step["do"])
            if want is None:
                problems.append(f"{rel} step {i}: {step['do']} is not in the contract")
            elif set(step.get("args", {})) != want:
                problems.append(f"{rel} step {i}: {step['do']} takes {sorted(want)}, got {sorted(step.get('args', {}))}")
        elif "expect" in step:
            expect = step["expect"]
            if "screen" in expect:
                current = expect["screen"]
                if current not in screen_ids:
                    problems.append(f"{rel} step {i}: screen {current} is not in the contract")
            for key, value in expect.items():
                if key == "screen" or key in app_fields:
                    continue
                if current is None:
                    problems.append(f"{rel} step {i}: {key} is expected before any screen is")
                elif key not in fields_by_screen.get(current, set()):
                    problems.append(f"{rel} step {i}: {key} is not a field of {current}")
                elif (current, key) in values and value not in values[(current, key)]:
                    problems.append(f"{rel} step {i}: {current}.{key} has no value {value}")
        else:
            problems.append(f"{rel} step {i}: neither do nor expect")

for p in problems:
    print(p, file=sys.stderr)
sys.exit(1 if problems else 0)
EOF
