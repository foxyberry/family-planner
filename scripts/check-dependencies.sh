#!/bin/bash
# Outside data (time, calendar, time zone, locale, device, bundle, settings, launch arguments) reaches
# the app only through TCA dependencies, so the app's reference time zone and the developer time
# machine apply everywhere and tests can pin them. This fails when:
#   - Swift code outside the allowed places reads such a global (Date(), Calendar.current, ...)
#   - a SwiftUI view reads @Dependency (a view gets the default value, not the store's)
# Allowed: ios/App (bootstrap), ios/Clients/*Live (implementations), ios/DebugTools (debug only),
# tests and snapshot tests. Comment lines are ignored.
#
# Usage: check-dependencies.sh [repo root]   (default: this repository)
# Exit code: 0 = clean, 1 = a global read or a view dependency.
set -u

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
GLOBALS='Date\(\)|Date\.now|(Calendar|TimeZone|Locale)\.(current|autoupdatingCurrent)|UIDevice\.current|Bundle\.main|UserDefaults\.standard|ProcessInfo\.processInfo'
found=0

while IFS= read -r -d '' file; do
  rel="${file#"$ROOT"/}"
  case "$rel" in
    ios/App/*|ios/Clients/*Live/*|ios/DebugTools/*|*/Tests/*|*/SnapshotTests/*) continue ;;
  esac
  code="$(grep -nvE '^[[:space:]]*//' "$file")"
  if hits="$(printf '%s\n' "$code" | grep -E "$GLOBALS")"; then
    printf '%s\n' "$hits" | sed "s|^|$rel: |" >&2
    echo "global read in $rel: take it from a dependency (\\.date, \\.calendar, ...) in the reducer" >&2
    found=1
  fi
  if [[ "$rel" == *View.swift ]] || printf '%s\n' "$code" | grep -qE ':[[:space:]]*View[[:space:]]*[{,]'; then
    if hits="$(printf '%s\n' "$code" | grep -E '@Dependency')"; then
      printf '%s\n' "$hits" | sed "s|^|$rel: |" >&2
      echo "view reads @Dependency in $rel: put the value in State instead" >&2
      found=1
    fi
  fi
done < <(find "$ROOT/ios" -name '*.swift' -print0 2>/dev/null)

exit "$found"
