#!/bin/bash
# The UX review's state inventory (skill ux-review): each case of an enum marked `ux-states: <screen>`,
# with the boards its doc comment names, checked against docs/superpowers/layout/<board>.json. A state
# with no board, or a board that doesn't exist, is a finding for the design session: nobody drew how
# that state looks. Read by the SwiftLint rule ux_states (tools/swiftlint), with the cached binary.
#
# Usage: scripts/ux-states.sh [path…]      inventory of ios/ (or the paths), one tab-separated line
#                                           per state: screen, state, boards, verdict; exit 0
#        scripts/ux-states.sh --self-test   the fixtures in tools/swiftlint/ux-fixtures give expected.txt
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
binary="$(bash scripts/swiftlint.sh --binary)" || exit 1

inventory() {
  "$binary" lint --quiet --config tools/swiftlint/ux-states.yml "$@" 2>/dev/null \
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
  got="$(inventory "$ROOT/tools/swiftlint/ux-fixtures")"
  if [ "$got" = "$(cat tools/swiftlint/ux-fixtures/expected.txt)" ]; then
    echo "ux-states self-test: the fixture inventory matches expected.txt"
    exit 0
  fi
  echo "ux-states self-test: the fixture inventory differs from expected.txt:" >&2
  diff <(printf '%s\n' "$got") tools/swiftlint/ux-fixtures/expected.txt >&2
  exit 1
fi

if [ $# -eq 0 ]; then set -- "$ROOT/ios"; fi
inventory "$@"
