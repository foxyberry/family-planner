#!/bin/bash
# Debug-only code stays out of product code (CLAUDE.md "ios/DebugTools"). Debug values reach the app
# only as dependencies that DebugModel.install swaps in ios/App's bootstrap (time machine, Skip Face
# ID); debug screens only through the one overlay at AppView's root. A `#if DEBUG`, `DebugModel` or
# `import DebugTools` anywhere else is the anti-pattern this blocks (2026-11-10: board setup code
# for debug links sat inside the item editor's reducer).
#
# Allowed: ios/DebugTools/**, ios/App/**, ios/AppCore/AppView.swift (the overlay), the debug-only
# ComponentGallery (ios/DesignSystem/Gallery, opened from the debug menu), and the files in
# PENDING below, which still hold debug links and fixtures and are being moved into DebugTools.
# Never add to PENDING; move the code instead.
#
# Usage: check-debug-boundary.sh [repo root]   (default: this repository)
# Exit code: 0 = clean, 1 = debug code outside the boundary.
set -u

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
PENDING=(
  "ios/AppCore/ScreenLink.swift"
  "ios/AppCore/AppFeature.swift"
  "ios/Features/Setup/SetupSample.swift"
)
found=0

while IFS= read -r -d '' file; do
  rel="${file#"$ROOT"/}"
  case "$rel" in
    ios/DebugTools/*|ios/App/*|ios/AppCore/AppView.swift|ios/DesignSystem/Gallery/*) continue ;;
    */Tests/*|*/SnapshotTests/*) continue ;;
  esac
  for pending in "${PENDING[@]}"; do [ "$rel" = "$pending" ] && continue 2; done
  if hits="$(grep -nE '#if DEBUG|\bDebugModel\b|import DebugTools' "$file")"; then
    printf '%s\n' "$hits" | sed "s|^|$rel:|" >&2
    echo "debug code outside DebugTools: $rel (give the value through a dependency DebugModel swaps, or move the code into ios/DebugTools)" >&2
    found=1
  fi
done < <(find "$ROOT/ios" -name '*.swift' -print0 2>/dev/null)

exit "$found"
