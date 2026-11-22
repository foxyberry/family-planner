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
# scripts/view-values-pending.txt are left out of `view_values` until they are fixed, and a listed
# file that is clean (no view_values hit, no check-view-values.sh hit) fails until its line goes.
# Where the rule looks (which paths count as view code) is in the rule itself.
#
# Usage: scripts/swiftlint.sh             lint ios/: exit 0 clean, 2 on a violation or a pending
#                                         line for a clean file, 1 if it could not run (build,
#                                         config or crash; the reason is printed)
#        scripts/swiftlint.sh --self-test lint tools/swiftlint/fixtures: every `// bad` line must be
#                                         reported and no other line
#        scripts/swiftlint.sh --binary    print the cached binary's path (building it if needed)
# SWIFTLINT_CACHE overrides where binaries are kept (default ~/.cache/family-planner/swiftlint).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
# CI on Linux passes SWIFTLINT_BAZEL=bazel: ios/.bazelrc holds iOS flags a Linux host doesn't need.
B="${SWIFTLINT_BAZEL:-bazel --bazelrc=.bazelrc --bazelrc=ios/.bazelrc}"
# Temporary files in one folder (portable: GNU mktemp needs X's in a template).
work="$(mktemp -d "${TMPDIR:-/tmp}/swiftlint.XXXXXX")"
errors="$work/errors"
trap 'rm -rf "$work"' EXIT

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

# Configs: every rule (.swiftlint.yml, for the self-test); view_values alone, without and with the
# view-values pending files left out; every other rule, which the pending list never excuses.
values="$work/values.yml"
values_pending="$work/values-pending.yml"
rest="$work/rest.yml"
printf 'only_rules:\n  - view_values\n' > "$values"
{
  cat "$values"
  echo "excluded:"
  grep -vE '^[[:space:]]*(#|$)' scripts/view-values-pending.txt | sed "s|^|  - $ROOT/|"
} > "$values_pending"
sed '/^  - view_values$/d; /^  - layout_literals$/d' .swiftlint.yml > "$rest"
layout="$work/layout.yml"
printf 'only_rules:\n  - layout_literals\n' > "$layout"

# lint <config> <path>…: SwiftLint's report; 0 clean, 2 violations; anything else (bad config,
# crash) shows its own message and stops. Paths print relative to the repo (SwiftLint may print
# /tmp for /private/tmp).
lint() {
  local config="$1"
  shift
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
  out="$(lint .swiftlint.yml "$ROOT/tools/swiftlint/fixtures")"
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

out="$(lint "$values_pending" "$ROOT/ios")"
code=$?
printf '%s\n' "$out" | grep -E 'error:|warning:'
[ "$code" = 2 ] && echo "swiftlint: value in view code (put copy and shown values in State; tca-feature \"When a guard blocks\")" >&2
if grep -q '^  - ' "$rest"; then
  out="$(lint "$rest" "$ROOT/ios")"
  other=$?
  printf '%s\n' "$out" | grep -E 'error:|warning:'
  [ "$other" = 2 ] && code=2
fi

# layout_literals counts per screen file against scripts/layout-literals-pending.txt: one count per
# line with a hit, as the old regex guard counted. A file not listed must have 0; a listed file must
# have exactly its count (lower it when some go; delete the line at 0); a line for a missing file goes.
out="$(lint "$layout" "$ROOT/ios")"
[ $? = 1 ] && exit 1  # could not run; the reason is on stderr
hits="$(printf '%s\n' "$out" | grep -E '\.swift:[0-9]+:')"
counts="$(printf '%s\n' "$hits" | grep . | cut -d: -f1,2 | sort -u | cut -d: -f1 | sort | uniq -c | awk '{ print $2, $1 }')"
listed="$(grep -vE '^[[:space:]]*(#|$)' scripts/layout-literals-pending.txt)"
for rel in $( { printf '%s\n' "$counts" | cut -d' ' -f1; printf '%s\n' "$listed" | cut -d' ' -f1; } | grep . | sort -u); do
  have="$(printf '%s\n' "$counts" | awk -v f="$rel" '$1 == f { print $2 }')"
  allowed="$(printf '%s\n' "$listed" | awk -v f="$rel" '$1 == f { print $2 }')"
  have="${have:-0}"; allowed="${allowed:-0}"
  if [ ! -f "$rel" ]; then
    echo "swiftlint: pending entry for a missing file: $rel (delete it from scripts/layout-literals-pending.txt)" >&2
    code=2
  elif [ "$have" -gt "$allowed" ]; then
    printf '%s\n' "$hits" | grep -F "$rel:"
    echo "swiftlint: layout literal in a screen: $rel has $have, pending allows $allowed (use a token, part or layout; no offsets)" >&2
    code=2
  elif [ "$have" -lt "$allowed" ]; then
    echo "swiftlint: pending count too high: $rel has $have, scripts/layout-literals-pending.txt says $allowed (lower it; delete the line at 0)" >&2
    code=2
  fi
done

# The pending list only shrinks: a listed file with no view_values hit and no hit of
# check-view-values.sh (copy lookups, placeholder numbers) is clean, and its line must go.
pending="$(grep -vE '^[[:space:]]*(#|$)' scripts/view-values-pending.txt | sed 's/[[:space:]]*$//')"
if [ -n "$pending" ]; then
  files=()
  while IFS= read -r rel; do [ -f "$rel" ] && files+=("$ROOT/$rel"); done <<< "$pending"
  listed=""
  if [ ${#files[@]} -gt 0 ]; then  # bash 3.2 with set -u stops on an empty "${files[@]}"
    listed="$(lint "$values" "${files[@]}")"  # view_values on the pending files themselves
    [ $? = 1 ] && exit 1  # could not run; the reason is on stderr
  fi
  native="$(printf '%s\n' "$listed" | grep -E '\.swift:[0-9]+' | cut -d: -f1 | sort -u)"
  regex="$(bash scripts/check-view-values.sh --hits "$ROOT")"
  while IFS= read -r rel; do
    [ -f "$rel" ] || continue  # check-view-values.sh reports a missing file
    if ! printf '%s\n' "$native" "$regex" | grep -qxF "$rel"; then
      echo "swiftlint: pending line for a clean file: $rel (remove it from scripts/view-values-pending.txt)" >&2
      code=2  # a finding, like a violation (1 means it could not run)
    fi
  done <<< "$pending"
fi
exit "$code"
