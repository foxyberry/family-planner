#!/bin/bash
# Views hold no values (user, 2026-11-18): what a screen shows is exactly what State holds. A view
# or DesignSystem part never looks copy up, never falls back to a value of its own and never shows
# a placeholder number. Copy reaches State through the injected `\.localizer` dependency; parts get
# their strings from the caller. nil in State means a different UI (card closed, nothing picked),
# never "show X": a view branches on it with `if let` / `switch`, and every value it shows or binds
# is non-optional in State. This fails when view code has:
#   - a copy lookup: `L10n.tr(` or `.tr(` (resolve it in State: `strings.tr("key")`)
#   - a placeholder number: `placeholder: 450` (put the shown value in State)
# Any `??` and, in screens, a ternary on State or on nil are the SwiftLint rule view_values
# (tools/swiftlint, scripts/swiftlint.sh: pre-push and the required CI check), which reads Swift
# structure instead of lines.
# View code = a `*View.swift` file, a file that declares a `: View` type, and the DesignSystem part
# folders (Clock, Content, Controls, Screens). Other DesignSystem files (Layout, Tokens, Fonts) get
# the copy rule only. Exempt: ios/App, ios/DebugTools (debug only), ios/DesignSystem/Gallery,
# tests and snapshot tests. Comment lines are ignored.
#
# Files not migrated yet are listed in scripts/view-values-pending.txt (one path per line); this check
# skips them, and fails on a line for a missing file. The list only shrinks, but whether a listed
# file is clean needs both checks, so scripts/swiftlint.sh decides it (it asks this script for
# --hits).
#
# Usage: check-view-values.sh [repo root]           (default: this repository)
#        check-view-values.sh --hits [repo root]    print each view file with a hit, pending or not
# Exit code: 0 = clean, 1 = a value in view code or a pending line for a missing file.
set -u

HITS=0
if [ "${1:-}" = "--hits" ]; then HITS=1; shift; fi
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
PENDING="$ROOT/scripts/view-values-pending.txt"
COPY='\.tr\('
VALUES='placeholder:[[:space:]]*-?[0-9]'
found=0

is_pending() {
  [ -f "$PENDING" ] && grep -qxF "$1" <(grep -vE '^[[:space:]]*(#|$)' "$PENDING" | sed 's/[[:space:]]*$//')
}

while IFS= read -r -d '' file; do
  rel="${file#"$ROOT"/}"
  case "$rel" in
    ios/App/*|ios/DebugTools/*|ios/DesignSystem/Gallery/*|*/Tests/*|*/SnapshotTests/*) continue ;;
  esac
  code="$(grep -nvE '^[[:space:]]*//' "$file")"
  case "$rel" in
    ios/DesignSystem/Clock/*|ios/DesignSystem/Content/*|ios/DesignSystem/Controls/*|ios/DesignSystem/Screens/*)
       pattern="$COPY|$VALUES" ;;
    ios/DesignSystem/*) pattern="$COPY" ;;
    *View.swift) pattern="$COPY|$VALUES" ;;
    *) printf '%s\n' "$code" | grep -qE ':[[:space:]]*View[[:space:]]*[{,]' || continue
       pattern="$COPY|$VALUES" ;;
  esac
  hits="$(printf '%s\n' "$code" | grep -E "$pattern")"
  if [ "$HITS" = 1 ]; then
    [ -n "$hits" ] && echo "$rel"
    continue
  fi
  if is_pending "$rel"; then
    :  # scripts/swiftlint.sh decides whether a pending file is clean (it sees both checks)
  elif [ -n "$hits" ]; then
    printf '%s\n' "$hits" | sed "s|^|$rel:|" >&2
    echo "value in view code: $rel (put copy and shown values in State; parts take strings from the caller)" >&2
    found=1
  fi
done < <(find "$ROOT/ios" -name '*.swift' -print0 2>/dev/null)
[ "$HITS" = 1 ] && exit 0

if [ -f "$PENDING" ]; then
  while read -r rel _; do
    case "$rel" in ''|'#'*) continue ;; esac
    [ -f "$ROOT/$rel" ] || { echo "pending line for a missing file: $rel (remove it)" >&2; found=1; }
  done < "$PENDING"
fi

exit "$found"
