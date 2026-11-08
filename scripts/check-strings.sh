#!/bin/bash
# User-facing copy lives in one String Catalog (ios/Strings/Localizable.xcstrings) and reaches the
# screens only through L10n.tr("key"), so it can be translated and reviewed in one place.
# This fails when:
#   (a) a Swift file has a string literal that starts with an upper-case letter followed by a
#       lower-case one ("Hello there"): copy typed into code
#   (b) a key used as L10n.tr("key") is not in the catalog
#   (c) a catalog key is used nowhere in the app's Swift code
#   (d) a catalog key has no English value
# Exempt from (a): ios/App, ios/DebugTools (debug only), ios/DesignSystem/Gallery,
# ios/DesignSystem/Fonts (font names), ios/Domain/SeedData.swift (fake data), tests and snapshot
# tests. Comment lines are ignored. A line ending with `// copy-ok: <reason>` is allowed, for the
# rare literal that is not copy (a bundle or table name). Tests are not scanned for keys.
#
# Usage: check-strings.sh [repo root]   (default: this repository)
# Exit code: 0 = clean, 1 = hard-coded copy or a catalog mismatch.
set -u

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
found=0

while IFS= read -r -d '' file; do
  rel="${file#"$ROOT"/}"
  case "$rel" in
    ios/App/*|ios/DebugTools/*|ios/DesignSystem/Gallery/*|ios/DesignSystem/Fonts/*|ios/Domain/SeedData.swift) continue ;;
    */Tests/*|*/SnapshotTests/*) continue ;;
  esac
  code="$(grep -nvE '^[[:space:]]*//' "$file" | grep -vE '//[[:space:]]*copy-ok:[[:space:]]*[^[:space:]].*$')"
  if hits="$(printf '%s\n' "$code" | grep -E '"[A-Z][a-z]')"; then
    printf '%s\n' "$hits" | sed "s|^|$rel: |" >&2
    echo "hard-coded copy in $rel: add a key to ios/Strings/Localizable.xcstrings and use L10n.tr(\"key\")" >&2
    found=1
  fi
done < <(find "$ROOT/ios" -name '*.swift' -print0 2>/dev/null)

python3 - "$ROOT" <<'PY' || found=1
import json
import os
import re
import sys

root = sys.argv[1]
catalog_path = os.path.join(root, "ios", "Strings", "Localizable.xcstrings")
catalog_rel = "ios/Strings/Localizable.xcstrings"
key_use = re.compile(r'L10n\.tr\("([^"\\]+)"')

used = {}  # key -> first "file:line" that uses it
for folder, dirs, files in os.walk(os.path.join(root, "ios")):
    dirs[:] = [d for d in dirs if d not in ("Tests", "SnapshotTests")]
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(folder, name)
        rel = os.path.relpath(path, root)
        with open(path, encoding="utf-8", errors="replace") as source:
            for number, line in enumerate(source, 1):
                if line.lstrip().startswith("//"):
                    continue
                for key in key_use.findall(line):
                    used.setdefault(key, f"{rel}:{number}")

strings = {}
if os.path.exists(catalog_path):
    with open(catalog_path, encoding="utf-8") as catalog:
        strings = json.load(catalog).get("strings", {})

found = 0
for key in sorted(used):
    if key not in strings:
        print(f"{used[key]}: key not in the catalog: {key} (add it to {catalog_rel})", file=sys.stderr)
        found = 1
for key in sorted(strings):
    if key not in used:
        print(f"unused catalog key: {key} (use it with L10n.tr or remove it from {catalog_rel})", file=sys.stderr)
        found = 1
    unit = strings[key].get("localizations", {}).get("en", {}).get("stringUnit", {})
    if not str(unit.get("value", "")).strip():
        print(f"catalog key has no English value: {key} (in {catalog_rel})", file=sys.stderr)
        found = 1
sys.exit(found)
PY

exit "$found"
