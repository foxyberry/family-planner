#!/bin/bash
# Every kit picture is used, and every picture asset belongs to one (dead-code guard; review
# session, 2026-11-22). grep can prove both:
#   - a `KitSlot` case is used when its name appears in app code or data outside ios/KitArt (Swift,
#     JSON, the String Catalog; DebugTools counts, tests and the component gallery don't). KitArt
#     itself lists every case on purpose (`isThing`), so it never counts as a use;
#   - an image set in KitArt.xcassets is a `KitSlot` case, or a rig frame that KitRigs names.
# Pictures and assets not used yet are listed in scripts/kit-art-pending.txt (one name per line).
# The list only shrinks: a listed name that is now used (or gone) fails until its line is removed,
# and a new picture must be used from the start, or removed with `make art`.
#
# Usage: check-kit-art.sh [repo root]   (default: this repository)
# Exit code: 0 = every picture and asset is used, 1 = an unused one or a stale pending line.
set -u

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
[ -f "$ROOT/ios/KitArt/KitSlot.swift" ] || exit 0

python3 - "$ROOT" <<'EOF'
import json, pathlib, re, sys

root = pathlib.Path(sys.argv[1])
art = root / "ios/KitArt"
pending_file = root / "scripts/kit-art-pending.txt"
pending = set()
if pending_file.exists():
    pending = {line.strip() for line in pending_file.read_text().splitlines()
               if line.strip() and not line.lstrip().startswith("#")}

cases = []
for line in (art / "KitSlot.swift").read_text().splitlines():
    match = re.match(r"\s*case\s+([A-Za-z0-9_,\s]+)$", line)
    if match:
        cases += [name.strip() for name in match.group(1).split(",") if name.strip()]

def counts(path):
    text = str(path.relative_to(root))
    return (path.suffix in (".swift", ".json", ".xcstrings") and not text.startswith("ios/KitArt/")
            and "/Tests/" not in text and "/SnapshotTests/" not in text
            and not text.startswith("ios/DesignSystem/Gallery/"))

sources = [p.read_text(errors="ignore") for p in (root / "ios").rglob("*") if p.is_file() and counts(p)]
unused = {name for name in cases if not any(re.search(rf"\b{name}\b", text) for text in sources)}

catalog = art / "Resources/KitArt.xcassets"
rig_text = "".join(p.read_text() for p in catalog.rglob("*.json") if p.parent.name.endswith(".dataset"))
assets = {p.name[: -len(".imageset")] for p in catalog.rglob("*.imageset")}
orphans = {name for name in assets if name not in cases and f'"{name}"' not in rig_text}

problems = []
for name in sorted(unused - pending):
    problems.append(f"kit picture nothing uses: {name} (use it, or remove it with make art)")
for name in sorted(orphans - pending):
    problems.append(f"kit asset no picture or rig names: {name}.imageset (regenerate with make art)")
for name in sorted(pending - unused - orphans):
    problems.append(f"pending line for a used or missing picture: {name} (remove it from scripts/kit-art-pending.txt)")
for problem in problems:
    print(problem, file=sys.stderr)
sys.exit(1 if problems else 0)
EOF
