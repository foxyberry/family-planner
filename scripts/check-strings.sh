#!/bin/bash
# User-facing copy lives in one String Catalog (ios/Strings/Localizable.xcstrings) and reaches the
# screens only through `.tr("key")` (L10n, or the Localizer State keeps), so it can be translated and reviewed in one place.
# This fails when:
#   (a) a Swift file has a string literal that starts with an upper-case letter followed by a
#       lower-case one ("Hello there"): copy typed into code
#   (b) a key used as L10n.tr("key") or strings.tr("key") (an injected Localizer) is not in the catalog
#   (c) a catalog key is used nowhere in the app's Swift code
#   (d) a catalog key has no English value
#   (e) an L10n.tr("key", ...) call passes a different number of arguments than the key's English
#       value has placeholders (%@, %d, %1$@ ...): one key reused for two meanings. GlyphText's
#       format key counts its glyph as the one argument.
#   (f) a raw TextField / SecureField / TextEditor outside ios/DesignSystem: its placeholder takes
#       the window's colour scheme (white on paper at night, 2026-11-10); use CrayonField, which
#       colours the prompt.
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
  case "$rel" in
    ios/DesignSystem/*) ;;
    *)
      if hits="$(printf '%s\n' "$code" | grep -E '\b(TextField|SecureField|TextEditor)[[:space:]]*\(')"; then
        printf '%s\n' "$hits" | sed "s|^|$rel: |" >&2
        echo "raw text input in $rel: use CrayonField (DesignSystem colours its prompt)" >&2
        found=1
      fi
      ;;
  esac
done < <(find "$ROOT/ios" -name '*.swift' -print0 2>/dev/null)

python3 - "$ROOT" <<'PY' || found=1
import json
import os
import re
import sys

root = sys.argv[1]
catalog_path = os.path.join(root, "ios", "Strings", "Localizable.xcstrings")
catalog_rel = "ios/Strings/Localizable.xcstrings"
key_use = re.compile(r'\.tr\("([^"\\]+)"')  # L10n.tr("key") and strings.tr("key")

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

placeholder = re.compile(r'%(?:(\d+)\$)?[-+ 0#]*\d*(?:\.\d+)?(?:ll|l|h)?[@dDuUxXoOfeEgGcCsSp]')

def placeholders(value):
    value = value.replace("%%", "")
    found_args = placeholder.findall(value)
    positions = {int(p) for p in found_args if p}
    return max(len([p for p in found_args if not p]), max(positions, default=0))

def call_args(text, start):
    """Arguments after the key in a .tr( call whose key literal ends at `start`."""
    depth, commas, i = 1, 0, start
    while i < len(text) and depth:
        c = text[i]
        if c == '"':
            i += 1
            while i < len(text) and text[i] != '"':
                i += 2 if text[i] == "\\" else 1
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif c == "," and depth == 1:
            commas += 1
        i += 1
    return commas

call = re.compile(r'[\w.]+\.tr\("([^"\\]+)"')  # receiver included, for the GlyphText( check
for folder, dirs, files in os.walk(os.path.join(root, "ios")):
    dirs[:] = [d for d in dirs if d not in ("Tests", "SnapshotTests")]
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(folder, name)
        rel = os.path.relpath(path, root)
        with open(path, encoding="utf-8", errors="replace") as source:
            text = "".join("\n" if line.lstrip().startswith("//") else line for line in source)
        for match in call.finditer(text):
            key = match.group(1)
            if key not in strings:
                continue
            unit = strings[key].get("localizations", {}).get("en", {}).get("stringUnit", {})
            want = placeholders(str(unit.get("value", "")))
            got = call_args(text, match.end())
            # GlyphText(L10n.tr("key"), glyph: ...) draws the glyph into the key's one %@.
            if text[:match.start()].rstrip().endswith("GlyphText("):
                got += 1
            if got != want:
                number = text.count("\n", 0, match.start()) + 1
                print(f"{rel}:{number}: L10n.tr(\"{key}\") passes {got} argument(s) but its value has {want} "
                      f"placeholder(s): give a new meaning its own key", file=sys.stderr)
                found = 1
sys.exit(found)
PY

exit "$found"
