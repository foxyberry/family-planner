#!/bin/bash
set -euo pipefail

APP_TARGET="${1:?Usage: setup-ios.sh <app_target>}"

echo "=== Setting up iOS ==="
brew install bazelisk buildifier gitleaks
swift package resolve

if xcrun simctl list runtimes | grep -q "iOS 26"; then
  printf "  ✓ iOS 26 simulator runtime available\n"
else
  printf "  ⚠ No iOS 26 simulator runtime. Xcode → Settings → Components → install iOS 26.\n"
fi

echo "  Fetching Bazel external deps..."
if bazel fetch "$APP_TARGET" >/dev/null 2>&1; then
  printf "  ✓ Bazel fetch succeeded\n"
else
  printf "  ⚠ Bazel fetch failed — run 'bazel build %s' to see errors\n" "$APP_TARGET"
fi
