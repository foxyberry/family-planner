#!/bin/bash
# A Swift comment that places a part "as on board X (layout vN)" goes stale when board X is
# re-exported at a newer version, and the next session trusts the old numbers (2026-11-21: a new
# SetupView comment cited "Board S2 (layout v56)" after S2 had moved to v60). A comment names a
# board when one of the docs/superpowers/layout/<board>.json ids (S2, C3m, G6f, …) comes before
# "layout vN" in it.
#
#   check-layout-versions.sh --diff BASE HEAD   (pre-push, CI)
#       Only comment lines that BASE..HEAD adds or changes: each must cite a board's current
#       version (its JSON at HEAD). Older comments are left alone, so a board re-export never
#       turns another session's push red; they are caught when someone edits them.
#   check-layout-versions.sh [repo root]        (an audit on request)
#       Every comment in the working tree, as a report.
# Fix a finding by checking the board's current redlines and citing its version, or by dropping
# the version when the comment only records why a rule exists.
# Exit code: 0 = clean, 1 = a cited version is older than its board.
set -u

if [ "${1:-}" = "--diff" ]; then
  MODE=diff BASE="$2" HEAD="$3" ROOT="$(git rev-parse --show-toplevel)"
else
  MODE=all BASE="" HEAD="" ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
fi

python3 -I - "$MODE" "$ROOT" "$BASE" "$HEAD" <<'EOF'
import glob, json, os, re, subprocess, sys

mode, root, base, head = sys.argv[1:5]
LAYOUT = "docs/superpowers/layout"
CITE = re.compile(r"layout v(\d+)", re.I)
BOARD = re.compile(r"\b([A-Z][0-9][A-Za-z0-9-]*)\b")


def git(*args):
    return subprocess.run(["git", "-C", root, *args], capture_output=True, text=True).stdout


versions = {}
if mode == "diff":
    for path in git("ls-tree", "--name-only", head, LAYOUT + "/").split():
        if path.endswith(".json"):
            try:
                versions[os.path.basename(path)[:-5]] = int(json.loads(git("show", f"{head}:{path}")).get("version", 0))
            except (ValueError, TypeError):
                pass
else:
    for path in glob.glob(os.path.join(root, LAYOUT, "*.json")):
        try:
            versions[os.path.basename(path)[:-5]] = int(json.load(open(path)).get("version", 0))
        except (OSError, ValueError, TypeError):
            pass


def lines():
    """(file, line number, text) for the Swift lines to check."""
    if mode == "diff":
        diff = git("diff", "-U0", "--no-color", base, head, "--", "ios/")
        name, n = None, 0
        for raw in diff.splitlines():
            if raw.startswith("+++ "):
                name = raw[6:] if raw.startswith("+++ b/") else None
            elif raw.startswith("@@"):
                m = re.search(r"\+(\d+)", raw)
                n = int(m.group(1)) if m else 0
            elif raw.startswith("+") and name and name.endswith(".swift"):
                yield name, n, raw[1:]
                n += 1
    else:
        for path in sorted(glob.glob(os.path.join(root, "ios", "**", "*.swift"), recursive=True)):
            for n, text in enumerate(open(path, encoding="utf-8", errors="replace"), 1):
                yield os.path.relpath(path, root), n, text


found = 0
for name, n, text in lines():
    at = text.find("//")
    if at < 0:
        continue
    comment = text[at:]
    for m in CITE.finditer(comment):
        cited = int(m.group(1))
        for board in dict.fromkeys(BOARD.findall(comment[: m.start()])):
            if board in versions and versions[board] > cited:
                found += 1
                print(f"{name}:{n}: board {board} cited at layout v{cited}, {board}.json is v{versions[board]}",
                      file=sys.stderr)
if found:
    print(f"layout-versions: {found} comment(s) cite an older board version. Check the board's current "
          "redlines and cite its version, or drop the version.", file=sys.stderr)
sys.exit(1 if found else 0)
EOF
