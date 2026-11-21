#!/bin/bash
# Spec "Layout model": screens fill layout slots with parts and rows; they carry no numbers and no
# offsets. This counts, per screen file (ios/Features and ios/AppCore *View.swift), the lines with
# `.offset(` or a non-zero number literal inside `.frame(`, `.padding(` or `spacing:`, or passed as a
# size argument to a part (`height:`, `width:`, `minHeight:`, `labelHeight:` …: 2026-11-21, `SetupRow(height:
# 72)` kept the 13" height while its parts scaled). Use the parts' scaled sizes (`sizing.fieldHeight`,
# `sizing.tabHeight()`, `MinutesStepper.rowHeight(sizing)`). Files that still have
# some are listed with their count in scripts/layout-literals-pending.txt; the list only shrinks:
#   - a file not on the list must have 0;
#   - a listed file must have exactly its count (lower the count when you remove some; delete the
#     line at 0). Move the number into a token, a part or a layout instead.
#
# Usage: check-layout-literals.sh [repo root]   (default: this repository)
# Exit code: 0 = clean, 1 = a screen has more (or fewer) literals than its pending count.
set -u

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
PENDING="$ROOT/scripts/layout-literals-pending.txt"
PATTERN='\.offset\(|(\.frame|\.padding|spacing:)[^"]*[^A-Za-z0-9_.]([1-9][0-9]*(\.[0-9]+)?|0\.[0-9]+)\b|\b(height|width|minHeight|maxHeight|minWidth|maxWidth|labelHeight):[[:space:]]*[1-9][0-9]*'
found=0

pending_count() {
  [ -f "$PENDING" ] || { echo 0; return; }
  awk -v f="$1" '$1 == f { print $2; found = 1 } END { if (!found) print 0 }' "$PENDING"
}

while IFS= read -r -d '' file; do
  rel="${file#"$ROOT"/}"
  count="$(grep -cE "$PATTERN" "$file")"
  allowed="$(pending_count "$rel")"
  if [ "$count" -gt "$allowed" ]; then
    grep -nE "$PATTERN" "$file" | sed "s|^|$rel:|" >&2
    echo "layout literal in a screen: $rel has $count, pending allows $allowed (use a token, part or layout; no offsets)" >&2
    found=1
  elif [ "$count" -lt "$allowed" ]; then
    echo "pending count too high: $rel has $count, scripts/layout-literals-pending.txt says $allowed (lower it; delete the line at 0)" >&2
    found=1
  fi
done < <(find "$ROOT/ios/Features" "$ROOT/ios/AppCore" -name '*View.swift' -not -path '*/Tests/*' -print0 2>/dev/null)

if [ -f "$PENDING" ]; then
  while read -r rel _; do
    case "$rel" in ''|'#'*) continue ;; esac
    [ -f "$ROOT/$rel" ] || { echo "pending entry for a missing file: $rel (delete the line)" >&2; found=1; }
  done < "$PENDING"
fi

exit "$found"
