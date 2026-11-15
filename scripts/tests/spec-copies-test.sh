#!/bin/bash
# Tests for the .gitignore rule on docs/superpowers/specs: a wildcard copy from the design session
# must not stage the private design doc, while the two tracked spec copies stay visible.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

assert() {
  if [ "$2" -eq 0 ]; then PASS=$((PASS + 1)); echo "PASS $1"; else FAIL=$((FAIL + 1)); echo "FAIL $1"; fi
}

git -C "$ROOT" check-ignore -q --no-index docs/superpowers/specs/2026-11-07-family-planner-design.md
assert test_ignores_the_design_doc $?
git -C "$ROOT" check-ignore -q --no-index docs/superpowers/specs/notes.md
assert test_ignores_any_new_file $?
! git -C "$ROOT" check-ignore -q --no-index docs/superpowers/specs/2026-11-07-m2-screens-spec.md
assert test_keeps_the_screens_spec $?
! git -C "$ROOT" check-ignore -q --no-index docs/superpowers/specs/2026-11-08-product-backlog.md
assert test_keeps_the_backlog $?

echo "spec-copies: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
