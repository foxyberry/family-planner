#!/bin/bash
set -euo pipefail

echo "=== Checking prerequisites ==="
fail=0

check() { # name, install hint, required(1/0)
  if command -v "$1" >/dev/null 2>&1; then
    printf "  ✓ %s\n" "$1"
  else
    printf "  %s %s: not found (%s)\n" "$([ "$3" = 1 ] && echo ✗ || echo ⚠)" "$1" "$2"
    [ "$3" = 1 ] && fail=1
  fi
  return 0
}

check brew "https://brew.sh" 1
if xcode-select -p >/dev/null 2>&1; then
  printf "  ✓ xcode: %s\n" "$(xcodebuild -version | head -1)"
else
  printf "  ✗ xcode: not installed\n"; fail=1
fi
check bazelisk "brew install bazelisk (setup-ios installs it)" 0
check buildifier "brew install buildifier (setup-ios installs it)" 0
check gitleaks "brew install gitleaks (setup-ios installs it)" 0

[ "$fail" -eq 0 ] || exit 1
