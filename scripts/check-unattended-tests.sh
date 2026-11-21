#!/bin/bash
# Every test runs with nobody there (user, 2026-11-21): no test may wait for a person. Face ID is
# the step a person would have to pass, so:
#   - test code never reaches the real Face ID: no `LAContext`, `evaluatePolicy` or a live
#     `parentAuth` (journeys fake it through `WorldData.faceID`, unit tests through the client);
#   - UI tests start the app only through `TestApp.launch` (ios/Journeys/Tests/UI/App.swift), and
#     that launch passes `-fpSkipFaceID`, so the 2 s hold alone opens the grown-up screens.
# Test code = files under a `Tests/` or `SnapshotTests/` folder in ios/. Comment lines are ignored.
#
# Usage: check-unattended-tests.sh [repo root]   (default: this repository)
# Exit code: 0 = every test runs unattended, 1 = a test can wait for a person.
set -u

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
UI="ios/Journeys/Tests/UI"
LAUNCHER="$UI/App.swift"
found=0

while IFS= read -r -d '' file; do
  rel="${file#"$ROOT"/}"
  code="$(grep -nvE '^[[:space:]]*//' "$file")"
  hits="$(printf '%s\n' "$code" | grep -E 'LAContext|evaluatePolicy|parentAuth[[:space:]]*=[[:space:]]*\.live|ParentAuthClient\.live')"
  if [ -n "$hits" ]; then
    printf '%s\n' "$hits" | sed "s|^|$rel:|" >&2
    echo "real Face ID in a test: $rel (fake the answer: WorldData.faceID or the parentAuth client)" >&2
    found=1
  fi
  case "$rel" in
    "$UI"/*)
      if [ "$rel" != "$LAUNCHER" ] && printf '%s\n' "$code" | grep -qE 'XCUIApplication\(|\.launch\(\)'; then
        echo "UI test starts the app itself: $rel (use TestApp.launch, which skips Face ID)" >&2
        found=1
      fi ;;
  esac
done < <(find "$ROOT/ios" \( -path '*/Tests/*' -o -path '*/SnapshotTests/*' \) -name '*.swift' -print0 2>/dev/null)

if [ -d "$ROOT/$UI" ]; then
  if [ ! -f "$ROOT/$LAUNCHER" ] || ! grep -vE '^[[:space:]]*//' "$ROOT/$LAUNCHER" | grep -q '"-fpSkipFaceID"'; then
    echo "TestApp.launch must pass -fpSkipFaceID ($LAUNCHER)" >&2
    found=1
  fi
fi

exit "$found"
