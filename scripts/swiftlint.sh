#!/bin/bash
# This repo's SwiftLint native rules (tools/swiftlint) over ios/ (`make swiftlint`, and pre-push when
# Swift under ios/ or the rules change). Only our own rules run (.swiftlint.yml `only_rules`).
#
# SwiftLint with our rules is built once with Bazel and the binary is kept outside the worktree,
# keyed on the rules and the SwiftLint version, so later runs (every worktree, every push) start no
# Bazel server. A new key builds again: about 12 min on this Mac with an empty Bazel cache, about
# 2 min from the shared disk cache.
#
# A rule that replaces a regex guard keeps that guard's shrink-only pending list: files listed in
# scripts/view-values-pending.txt are left out of `view_values` until they are fixed. Where the rule
# looks (which paths count as view code) is in the rule itself.
#
# Usage: scripts/swiftlint.sh             lint ios/: exit 0 clean, 2 on a violation, 1 if it
#                                         could not run (build, config or crash; the reason is printed)
#        scripts/swiftlint.sh --self-test lint tools/swiftlint/fixtures: every `// bad` line must be
#                                         reported and no other line
#        scripts/swiftlint.sh --binary    print the cached binary's path (building it if needed)
# SWIFTLINT_CACHE overrides where binaries are kept (default ~/.cache/family-planner/swiftlint).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
B="bazel --bazelrc=.bazelrc --bazelrc=ios/.bazelrc"
config="$(mktemp -t swiftlint).yml"
errors="$(mktemp -t swiftlint-err)"
trap 'rm -f "$config" "$errors"' EXIT

# The binary changes only with our rules, their BUILD file and the SwiftLint version.
key="$( { cat tools/swiftlint/*.swift tools/swiftlint/BUILD.bazel; grep -E 'swiftlint|extra_rules' MODULE.bazel; } \
  | shasum -a 256 | cut -c1-16)"
cache="${SWIFTLINT_CACHE:-$HOME/.cache/family-planner/swiftlint}"
binary="$cache/$key/swiftlint"

if [ ! -x "$binary" ]; then
  echo "swiftlint: building SwiftLint with tools/swiftlint (key $key; once per rule change)" >&2
  bash scripts/check-disk.sh || exit 1
  if ! $B build -c opt @SwiftLint//:swiftlint 2>"$errors"; then
    grep -E "error:|ERROR:" "$errors" | head -10 >&2
    echo "swiftlint: SwiftLint or a rule in tools/swiftlint failed to build" >&2
    exit 1
  fi
  built="$($B cquery -c opt --output=files @SwiftLint//:swiftlint 2>/dev/null | head -1)"
  [ -n "$built" ] && [ -f "$built" ] || { echo "swiftlint: built, but the binary was not found" >&2; exit 1; }
  mkdir -p "$cache/$key"
  cp "$built" "$binary.$$" && chmod +x "$binary.$$" && mv "$binary.$$" "$binary"
  # Binaries for rules no branch has used in two weeks go.
  find "$cache" -mindepth 1 -maxdepth 1 -type d -mtime +14 -exec rm -rf {} + 2>/dev/null
fi
touch "$cache/$key"  # in use: keeps this key out of the prune
[ "${1:-}" = "--binary" ] && { echo "$binary"; exit 0; }

{
  cat .swiftlint.yml
  echo "excluded:"
  grep -vE '^[[:space:]]*(#|$)' scripts/view-values-pending.txt | sed "s|^|  - $ROOT/|"
} > "$config"

# SwiftLint: 0 clean, 2 violations; anything else (bad config, crash) shows its own message.
# Paths print relative to the repo (SwiftLint may print /tmp for /private/tmp).
lint() {
  "$binary" lint --quiet --strict --config "$config" "$@" 2>"$errors" | sed -e "s|^$ROOT/||" -e "s|^${ROOT#/private}/||"
  local code="${PIPESTATUS[0]}"
  if [ "$code" != 0 ] && [ "$code" != 2 ]; then
    tail -15 "$errors" >&2
    echo "swiftlint: SwiftLint exited $code without linting" >&2
    exit 1
  fi
  return "$code"
}

if [ "${1:-}" = "--self-test" ]; then
  out="$(lint "$ROOT/tools/swiftlint/fixtures")"
  [ $? = 1 ] && exit 1  # could not run; the reason is on stderr
  status=0
  # Each line marked `// bad` in a fixture must be reported, and nothing else.
  while IFS=: read -r file line _; do
    printf '%s\n' "$out" | grep -qF "$file:$line:" || { echo "swiftlint self-test: not reported: $file:$line" >&2; status=1; }
  done < <(grep -rn '// bad' tools/swiftlint/fixtures --include='*.swift')
  extra="$(printf '%s\n' "$out" | grep -E '\.swift:[0-9]+' | while IFS=: read -r file line _; do
    sed -n "${line}p" "$file" | grep -q '// bad' || echo "$file:$line"; done)"
  [ -z "$extra" ] || { echo "swiftlint self-test: reported a good line: $extra" >&2; status=1; }
  [ "$status" = 0 ] && echo "swiftlint self-test: every bad line reported, no good line"
  exit "$status"
fi

out="$(lint "$ROOT/ios")"
code=$?
printf '%s\n' "$out" | grep -E 'error:|warning:'
[ "$code" = 2 ] && echo "swiftlint: value in view code (put copy and shown values in State; tca-feature \"When a guard blocks\")" >&2
exit "$code"
