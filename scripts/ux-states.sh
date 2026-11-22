#!/bin/bash
# The UX review's state inventory (skill ux-review): each case of an enum marked `ux-states: <screen>`,
# with the boards its doc comment names, checked against docs/superpowers/layout/<board>.json. A state
# with no board, or a board that doesn't exist, is a finding for the design session: nobody drew how
# that state looks. Read by the SwiftLint rule ux_states (tools/swiftlint), with the cached binary.
#
# Usage: scripts/ux-states.sh [path…]      inventory of ios/ (or the paths), one tab-separated line
#                                           per state: screen, state, boards, verdict; exit 0, or 1
#                                           if SwiftLint could not run (its message is printed)
#        scripts/ux-states.sh --self-test   the fixtures in tools/swiftlint/ux-fixtures give expected.txt
#        scripts/ux-states.sh --check       fail (exit 1) on a state with no board or an unknown board,
#                                           unless scripts/ux-states-pending.txt lists it (make ux-states,
#                                           pre-push). The list only shrinks: a listed state that now has a
#                                           board, or that no longer exists, fails until its line goes.
# UX_STATES_INVENTORY=<file> checks that inventory instead of running SwiftLint (tests, CI without it).
set -u
ROOT="${UX_STATES_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
cd "$ROOT"
PENDING="$ROOT/scripts/ux-states-pending.txt"

# The pending list against an inventory (screen, state, boards, verdict per line).
check() {
  local inventory="$1" status=0 pending
  pending="$(grep -vE '^[[:space:]]*(#|$)' "$PENDING" 2>/dev/null | sed 's/[[:space:]]*$//')"
  while IFS=$'\t' read -r screen state boards verdict; do
    [ -n "$state" ] || continue
    [ "$verdict" = ok ] && continue
    if ! printf '%s\n' "$pending" | grep -qxF "$state"; then
      echo "ux-states: $state ($screen) has $verdict: draw its board and name it at the start of the case's doc comment (skill ux-review)" >&2
      status=1
    fi
  done < "$inventory"
  while IFS= read -r state; do
    [ -n "$state" ] || continue
    line="$(awk -F'\t' -v s="$state" '$2 == s' "$inventory")"
    if [ -z "$line" ]; then
      echo "ux-states: pending line for a state that no longer exists: $state (remove it from scripts/ux-states-pending.txt)" >&2
      status=1
    elif [ "$(printf '%s' "$line" | cut -f4)" = ok ]; then
      echo "ux-states: pending line for a state that has its board now: $state (remove it from scripts/ux-states-pending.txt)" >&2
      status=1
    fi
  done <<< "$pending"
  [ "$status" = 0 ] && echo "ux-states: every state has a board, or is pending"
  return "$status"
}

if [ "${1:-}" = "--check" ] && [ -n "${UX_STATES_INVENTORY:-}" ]; then
  check "$UX_STATES_INVENTORY"
  exit $?
fi

binary="$(bash scripts/swiftlint.sh --binary)" || exit 1
work="$(mktemp -d "${TMPDIR:-/tmp}/ux-states.XXXXXX")"
errors="$work/errors"
trap 'rm -rf "$work"' EXIT

# SwiftLint's report, or exit 1 with its own message: a run that couldn't lint (bad config, crash)
# must not read as "no states".
report() {
  local out code
  out="$("$binary" lint --quiet --config tools/swiftlint/ux-states.yml "$@" 2>"$errors")"
  code=$?
  if [ "$code" != 0 ] && [ "$code" != 2 ]; then
    tail -15 "$errors" >&2
    echo "ux-states: SwiftLint exited $code without listing" >&2
    return 1
  fi
  printf '%s\n' "$out"
}

inventory() {
  local out
  out="$(report "$@")" || exit 1
  printf '%s\n' "$out" \
    | sed -n 's/.*ux-states \(.*\) (ux_states)$/\1/p' \
    | while IFS='|' read -r screen state boards; do
        screen="$(echo "$screen" | xargs)"; state="$(echo "$state" | xargs)"; boards="$(echo "$boards" | xargs)"
        verdict=ok
        if [ -z "$boards" ]; then
          verdict="NO BOARD"
        else
          for board in $(echo "$boards" | tr ',' ' '); do
            [ -f "docs/superpowers/layout/$board.json" ] || verdict="UNKNOWN BOARD $board"
          done
        fi
        printf '%s\t%s\t%s\t%s\n' "$screen" "$state" "${boards:--}" "$verdict"
      done
}

if [ "${1:-}" = "--self-test" ]; then
  got="$(inventory "$ROOT/tools/swiftlint/ux-fixtures")" || exit 1
  if [ "$got" = "$(cat tools/swiftlint/ux-fixtures/expected.txt)" ]; then
    echo "ux-states self-test: the fixture inventory matches expected.txt"
    exit 0
  fi
  echo "ux-states self-test: the fixture inventory differs from expected.txt:" >&2
  diff <(printf '%s\n' "$got") tools/swiftlint/ux-fixtures/expected.txt >&2
  exit 1
fi

if [ "${1:-}" = "--check" ]; then
  list="$(inventory "$ROOT/ios")" || exit 1
  printf '%s\n' "$list" > "$work/inventory.tsv"
  check "$work/inventory.tsv"
  exit $?
fi

if [ $# -eq 0 ]; then set -- "$ROOT/ios"; fi
list="$(inventory "$@")" || exit 1
printf '%s\n' "$list"
