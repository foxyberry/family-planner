#!/bin/bash
# Board 0f: a kid screen never scrolls; long lists are cut with `Capped`. SwiftUI cannot forbid a
# ScrollView inside KidScreen's content through types, so this check fails any Swift file under
# ios/ that builds a KidScreen and also scrolls. The debug component gallery is exempt (it is a
# scrolling showcase of every part, including a KidScreen sample).
#
# Usage: check-kid-screens.sh [repo root]   (default: this repository)
# Exit code: 0 = clean, 1 = a kid screen scrolls.
set -u

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
found=0

while IFS= read -r -d '' file; do
  case "$file" in
    */ios/DesignSystem/Gallery/*|*/ios/DesignSystem/Screens/KidScreen.swift) continue ;;
  esac
  grep -q 'KidScreen' "$file" || continue
  if grep -nE 'ScrollView|ScrollViewReader|\bList[[:space:]]*[({]|\.scrollable|\.scrollDisabled\(false\)' "$file" >&2; then
    echo "kid screen scrolls: ${file#"$ROOT"/} (cap the list with Capped instead)" >&2
    found=1
  fi
done < <(find "$ROOT/ios" -name '*.swift' -not -path '*/Tests/*' -not -path '*/SnapshotTests/*' -print0 2>/dev/null)

exit "$found"
