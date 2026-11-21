#!/bin/bash
# Every screen has a journey (user, 2026-11-21): each reducer in ios/AppCore and ios/Features must be
# reached by a journey in ios/Journeys/Tests, so a new screen or flow arrives with one. A reducer
# `XFeature` counts as reached when journey code (comment lines aside) names the type `XFeature` or
# its case `.x` (`.home(...)`, `\.path[id: id].changeBuses...`): the case is how the root store
# reaches a pushed or scoped screen.
#
# Reducers no journey reaches yet are listed in scripts/journeys-pending.txt (one type per line).
# The list only shrinks: a listed reducer that a journey reaches fails until its line is removed,
# and a new reducer must be reached from the start.
#
# Usage: check-journeys.sh [repo root]   (default: this repository)
# Exit code: 0 = every reducer is reached, 1 = a reducer without a journey or a stale pending line.
set -u

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
PENDING="$ROOT/scripts/journeys-pending.txt"
JOURNEYS="$ROOT/ios/Journeys/Tests"
found=0

pending() { [ -f "$PENDING" ] && grep -vE '^[[:space:]]*(#|$)' "$PENDING" | sed 's/[[:space:]]*$//'; }

# `@Reducer` then `struct X` (same line or the next), outside tests.
reducers() {
  find "$ROOT/ios/AppCore" "$ROOT/ios/Features" -name '*.swift' -not -path '*/Tests/*' \
    -not -path '*/SnapshotTests/*' -print0 2>/dev/null |
    xargs -0 awk '
      /^[[:space:]]*\/\// { next }
      /@Reducer/ { want = 1 }
      want && match($0, /struct[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/) {
        name = substr($0, RSTART, RLENGTH); sub(/struct[[:space:]]+/, "", name)
        printf "%s %s\n", name, FILENAME; want = 0; next
      }
      want && !/@Reducer/ { want = 0 }
    ' 2>/dev/null | sort -u
}

code="$(find "$JOURNEYS" -name '*.swift' -print0 2>/dev/null | xargs -0 cat 2>/dev/null | grep -vE '^[[:space:]]*//')"

reached() {
  local type="$1" stem="${1%Feature}"
  stem="$(printf '%s' "${stem:0:1}" | tr '[:upper:]' '[:lower:]')${stem:1}"
  printf '%s\n' "$code" | grep -qE "(^|[^A-Za-z0-9_])$type([^A-Za-z0-9_]|$)|\\.$stem([^A-Za-z0-9_]|$)"
}

list="$(reducers)"
while read -r type file; do
  [ -n "$type" ] || continue
  rel="${file#"$ROOT"/}"
  if pending | grep -qxF "$type"; then
    if reached "$type"; then
      echo "pending line for a reducer a journey reaches: $type (remove it from scripts/journeys-pending.txt)" >&2
      found=1
    fi
  elif ! reached "$type"; then
    echo "no journey reaches $type ($rel): add or extend one in ios/Journeys/Tests (send its actions through the root store)" >&2
    found=1
  fi
done <<< "$list"

while read -r type; do
  [ -n "$type" ] || continue
  printf '%s\n' "$list" | grep -q "^$type " || { echo "pending line for a missing reducer: $type (remove it)" >&2; found=1; }
done < <(pending)

exit "$found"
