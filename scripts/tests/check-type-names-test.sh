#!/bin/bash
# Tests for scripts/check-type-names.sh (no public Domain type shares a name with a DesignSystem type).
set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/check-type-names.sh"
PASS=0
FAIL=0

new_tree() {
  TREE="$(mktemp -d)"
  mkdir -p "$TREE/ios/Domain/Tests" "$TREE/ios/DesignSystem/Clock"
  printf 'public struct DayKnob {}\n' > "$TREE/ios/Domain/Knobs.swift"
  printf 'public struct ClockKnob: View {}\nstruct Wobble {}\n' > "$TREE/ios/DesignSystem/Clock/ClockKnob.swift"
}

run_check() { ERR="$(bash "$SCRIPT" "$TREE" 2>&1 >/dev/null)"; CODE=$?; }

assert() {
  if [ "$2" -eq 0 ]; then PASS=$((PASS + 1)); echo "PASS $1"; else FAIL=$((FAIL + 1)); echo "FAIL $1 (code=$CODE err=$ERR)"; fi
}

test_passes_with_distinct_names() {
  new_tree
  run_check
  [ "$CODE" -eq 0 ]
  assert test_passes_with_distinct_names $?
}

test_blocks_a_shared_name() {
  new_tree
  printf 'public struct ClockKnob {}\npublic enum Wobble {}\n' > "$TREE/ios/Domain/Knobs.swift"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"both Domain and DesignSystem: ClockKnob"* ]] && [[ "$ERR" == *": Wobble"* ]]
  assert test_blocks_a_shared_name $?
}

test_ignores_internal_domain_types_comments_and_tests() {
  new_tree
  printf 'struct ClockKnob {}\n// public struct ClockKnob {}\npublic struct Day {\n    public struct ClockKnob {}\n}\n' > "$TREE/ios/Domain/Knobs.swift"
  printf 'public struct ClockKnob {}\n' > "$TREE/ios/Domain/Tests/Fixture.swift"
  run_check
  [ "$CODE" -eq 0 ]
  assert test_ignores_internal_domain_types_comments_and_tests $?
}

test_passes_with_distinct_names
test_blocks_a_shared_name
test_ignores_internal_domain_types_comments_and_tests

echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
