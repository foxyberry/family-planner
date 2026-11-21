#!/bin/bash
# No public type name in ios/Domain is also a type in ios/DesignSystem (lesson 2026-11-21): features
# import both modules, so a shared name (Domain's `ClockKnob` beside the `ClockKnob` view) is
# "ambiguous for type lookup" in every feature. Give the Domain type a domain word (`DayKnob`).
# Only top-level types count (a nested `DayPlanner.Slot` never clashes); comment lines are ignored;
# tests are not checked.
#
# Usage: check-type-names.sh [repo root]   (default: this repository)
# Exit code: 0 = no shared names, 1 = a name both modules declare.
set -u

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"

types() {
  find "$ROOT/ios/$1" -name '*.swift' -not -path '*/Tests/*' -not -path '*/SnapshotTests/*' -print0 2>/dev/null |
    xargs -0 grep -hvE '^[[:space:]]*//' 2>/dev/null |
    grep -oE "^$2(final )?(struct|enum|class|protocol|actor|typealias)[[:space:]]+[A-Z][A-Za-z0-9_]*" |
    awk '{print $NF}' | sort -u
}

shared="$(comm -12 <(types Domain 'public ') <(types DesignSystem '((public|internal|fileprivate|private) )?'))"
if [ -n "$shared" ]; then
  printf '%s\n' "$shared" | while read -r name; do
    echo "type name in both Domain and DesignSystem: $name (give the Domain type a domain word)" >&2
  done
  exit 1
fi
exit 0
