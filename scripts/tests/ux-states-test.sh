#!/bin/bash
# Tests for scripts/ux-states.sh --check (every marked screen state has a board, or is pending). The
# inventory comes from a file (UX_STATES_INVENTORY), so this runs without SwiftLint (CI included).
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/ux-states.sh"
PASS=0
FAIL=0

new_tree() {
  TREE="$(mktemp -d)"
  mkdir -p "$TREE/scripts"
  INVENTORY="$TREE/inventory.tsv"
}

inventory() { printf '%s\n' "$@" | tr '|' '\t' > "$INVENTORY"; }
pending() { printf '%s\n' "$@" > "$TREE/scripts/ux-states-pending.txt"; }
run_check() { ERR="$(UX_STATES_ROOT="$TREE" UX_STATES_INVENTORY="$INVENTORY" bash "$SCRIPT" --check 2>&1 >/dev/null)"; CODE=$?; }
assert() {
  if [ "$2" -eq 0 ]; then PASS=$((PASS + 1)); echo "PASS $1"; else FAIL=$((FAIL + 1)); echo "FAIL $1 (code=$CODE err=$ERR)"; fi
}

test_every_state_drawn_passes() {
  new_tree
  inventory "home|Block.leave|A1, E1|ok" "home|Block.next|E3|ok"
  pending "# none"
  run_check
  [ "$CODE" -eq 0 ]
  assert test_every_state_drawn_passes $?
}

test_a_state_with_no_board_fails() {
  new_tree
  inventory "home|Block.leave|A1|ok" "home|Block.nothing|-|NO BOARD"
  pending "# none"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"Block.nothing (home) has NO BOARD"* ]]
  assert test_a_state_with_no_board_fails $?
}

test_an_unknown_board_fails() {
  new_tree
  inventory "home|Block.leave|A9|UNKNOWN BOARD A9"
  pending "# none"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"UNKNOWN BOARD A9"* ]]
  assert test_an_unknown_board_fails $?
}

test_a_pending_state_passes() {
  new_tree
  inventory "home|Block.leave|A1|ok" "home|Block.nothing|-|NO BOARD"
  pending "# header" "Block.nothing"
  run_check
  [ "$CODE" -eq 0 ]
  assert test_a_pending_state_passes $?
}

test_pending_only_shrinks() {
  new_tree
  inventory "home|Block.leave|A1|ok" "home|Block.nothing|A1z|ok"
  pending "Block.nothing" "Block.gone"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"has its board now: Block.nothing"* ]] \
    && [[ "$ERR" == *"no longer exists: Block.gone"* ]]
  assert test_pending_only_shrinks $?
}

test_every_state_drawn_passes
test_a_state_with_no_board_fails
test_an_unknown_board_fails
test_a_pending_state_passes
test_pending_only_shrinks
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
