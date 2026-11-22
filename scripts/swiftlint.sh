#!/bin/bash
# This repo's SwiftLint native rules (tools/swiftlint) over ios/, through Bazel (`make swiftlint`).
# The first run builds SwiftLint and swift-syntax (about 12 min on this Mac); later runs reuse the
# cache and lint in seconds. Only our own rules run (.swiftlint.yml `only_rules`).
#
# A rule that replaces a regex guard keeps that guard's shrink-only pending list: files listed in
# scripts/view-values-pending.txt are left out of `view_values` until they are fixed.
#
# Usage: scripts/swiftlint.sh             lint ios/ (exit 1 on any violation)
#        scripts/swiftlint.sh --self-test lint tools/swiftlint/fixtures: every `bad` line must be
#                                         reported and no `good` file may be
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
B="bazel --bazelrc=.bazelrc --bazelrc=ios/.bazelrc"
config="$(mktemp -t swiftlint).yml"
errors="$(mktemp -t swiftlint-err)"
trap 'rm -f "$config" "$errors"' EXIT

{
  cat .swiftlint.yml
  echo "excluded:"
  for path in ios/DebugTools ios/DesignSystem/Gallery; do echo "  - $ROOT/$path"; done
  grep -vE '^[[:space:]]*(#|$)' scripts/view-values-pending.txt | sed "s|^|  - $ROOT/|"
} > "$config"

# Bazel's progress goes to stderr; a failed build (a rule that doesn't compile) stops here with its
# errors instead of passing as "no violations".
lint() {
  $B run -c opt @SwiftLint//:swiftlint -- lint --quiet --strict --config "$config" "$@" 2>"$errors"
  local code=$?
  if grep -q "Build did NOT complete\|Build failed" "$errors"; then
    grep -E "error:|ERROR:" "$errors" | head -10 >&2
    echo "swiftlint: SwiftLint or a rule in tools/swiftlint failed to build" >&2
    exit 1
  fi
  return "$code"
}

if [ "${1:-}" = "--self-test" ]; then
  fixtures="$ROOT/tools/swiftlint/fixtures"
  out="$(lint "$fixtures")"
  [ $? = 1 ] && exit 1  # did not build or could not run; the reason is on stderr
  status=0
  # Each line marked `// bad` in a fixture must be reported, and nothing else.
  while IFS=: read -r file line _; do
    if ! printf '%s\n' "$out" | grep -q "$file:$line:"; then
      echo "swiftlint self-test: not reported: ${file#"$ROOT"/}:$line" >&2; status=1
    fi
  done < <(grep -rn '// bad' "$fixtures" --include='*.swift')
  extra="$(printf '%s\n' "$out" | grep -E '\.swift:[0-9]+' | while IFS=: read -r file line _; do
    sed -n "${line}p" "$file" | grep -q '// bad' || echo "${file#"$ROOT"/}:$line"; done)"
  [ -z "$extra" ] || { echo "swiftlint self-test: reported a good line: $extra" >&2; status=1; }
  [ "$status" = 0 ] && echo "swiftlint self-test: every bad line reported, no good line"
  exit "$status"
fi

out="$(lint "$ROOT/ios")"
code=$?
printf '%s\n' "$out" | grep -E 'error:|warning:' | sed "s|$ROOT/||"
exit "$code"
