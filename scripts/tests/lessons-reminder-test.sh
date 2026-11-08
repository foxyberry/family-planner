#!/bin/bash
# Tests for .claude/hooks/lessons-reminder.sh (SessionStart note when lessons wait for a skill retro).
set -u

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/.claude/hooks/lessons-reminder.sh"
PASS=0
FAIL=0

new_tree() {
  TREE="$(mktemp -d)"
  mkdir -p "$TREE/.claude/skills" "$TREE/scripts"
  cp "$(cd "$(dirname "$0")/.." && pwd)/check-skills.sh" "$TREE/scripts/"
  printf '# Lessons inbox\n\n' > "$TREE/.claude/lessons.md"
}

add_lessons() {
  for i in $(seq 1 "$1"); do
    printf -- '- 2026-11-08 · symptom %s · cause · rule · drop\n' "$i" >> "$TREE/.claude/lessons.md"
  done
}

run_hook() { OUT="$(CLAUDE_PROJECT_DIR="$TREE" bash "$HOOK" 2>&1)"; CODE=$?; }

assert() {
  if [ "$2" -eq 0 ]; then PASS=$((PASS + 1)); echo "PASS $1"; else FAIL=$((FAIL + 1)); echo "FAIL $1 (code=$CODE out=$OUT)"; fi
}

test_quiet_below_five() {
  new_tree; add_lessons 4; run_hook
  [ "$CODE" -eq 0 ] && [ -z "$OUT" ]
  assert test_quiet_below_five $?
}

test_reminds_at_five() {
  new_tree; add_lessons 5; run_hook
  [ "$CODE" -eq 0 ] && [[ "$OUT" == *"5 open lessons"* ]] && [[ "$OUT" == *"skill-retro"* ]]
  assert test_reminds_at_five $?
}

test_reports_broken_harness() {
  new_tree; printf -- '- not a lesson\n' >> "$TREE/.claude/lessons.md"; run_hook
  [ "$CODE" -eq 0 ] && [[ "$OUT" == *"check-skills"* ]]
  assert test_reports_broken_harness $?
}

test_quiet_below_five
test_reminds_at_five
test_reports_broken_harness

echo "lessons-reminder: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
