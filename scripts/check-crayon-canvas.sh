#!/bin/bash
# Crayon outlines wobble past the frame they are drawn for, and a SwiftUI Canvas clips what it
# draws to its bounds, so a crayon or marker shape in a frame-sized Canvas comes out cut flat at
# the edges (2026-11-09: every part looked cut off). CrayonSurface draws in a canvas with a bleed
# margin. Any other Canvas must say on its line why it is safe or how it bleeds:
#   Canvas { context, _ in  // bleed-ok: <reason>
#
# Usage: check-crayon-canvas.sh [repo root]   (default: this repository)
# Exit code: 0 = clean, 1 = a Canvas without a bleed note.
set -u

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
found=0

while IFS= read -r -d '' file; do
  case "$file" in
    */ios/CrayonKit/CrayonSurface.swift) continue ;;
  esac
  if hits="$(grep -nE '\bCanvas[[:space:]]*[({]' "$file" | grep -v 'bleed-ok:')"; then
    printf '%s\n' "$hits" | sed "s|^|${file#"$ROOT"/}:|" >&2
    echo "canvas without a bleed note: ${file#"$ROOT"/} (draw with a bleed margin like CrayonSurface, or add '// bleed-ok: <reason>')" >&2
    found=1
  fi
done < <(find "$ROOT/ios" -name '*.swift' -not -path '*/Tests/*' -not -path '*/SnapshotTests/*' -print0 2>/dev/null)

exit "$found"
