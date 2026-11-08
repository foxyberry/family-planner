#!/bin/bash
# Tests for scripts/check-skills.sh (project skills and the lessons inbox stay well-formed and short).
set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/check-skills.sh"
PASS=0
FAIL=0

new_tree() {
  TREE="$(mktemp -d)"
  mkdir -p "$TREE/.claude/skills/demo"
  printf -- '---\nname: demo\ndescription: Use when testing the checker.\nmetadata:\n  version: 0.1.0\n---\n\n# Demo\nShort body.\n' \
    > "$TREE/.claude/skills/demo/SKILL.md"
  printf '# Lessons inbox\n\n' > "$TREE/.claude/lessons.md"
  printf '# Rules\nShort.\n' > "$TREE/CLAUDE.md"
}

run_check() { OUT="$(bash "$SCRIPT" "$TREE" 2>&1)"; CODE=$?; }

assert() {
  if [ "$2" -eq 0 ]; then PASS=$((PASS + 1)); echo "PASS $1"; else FAIL=$((FAIL + 1)); echo "FAIL $1 (code=$CODE out=$OUT)"; fi
}

test_passes_clean_tree() {
  new_tree
  run_check
  [ "$CODE" -eq 0 ] && [[ "$OUT" == *"0 open lessons"* ]]
  assert test_passes_clean_tree $?
}

test_fails_name_not_matching_folder() {
  new_tree
  sed -i '' 's/^name: demo$/name: other/' "$TREE/.claude/skills/demo/SKILL.md"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$OUT" == *"demo"*"name"* ]]
  assert test_fails_name_not_matching_folder $?
}

test_fails_missing_version() {
  new_tree
  sed -i '' '/version:/d' "$TREE/.claude/skills/demo/SKILL.md"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$OUT" == *"version"* ]]
  assert test_fails_missing_version $?
}

test_fails_long_description() {
  new_tree
  long="$(printf 'x%.0s' $(seq 1 1100))"
  sed -i '' "s/^description: .*/description: Use when $long/" "$TREE/.claude/skills/demo/SKILL.md"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$OUT" == *"description"* ]]
  assert test_fails_long_description $?
}

test_fails_skill_over_word_limit() {
  new_tree
  for _ in $(seq 1 1600); do printf 'word ' >> "$TREE/.claude/skills/demo/SKILL.md"; done
  run_check
  [ "$CODE" -eq 1 ] && [[ "$OUT" == *"words"* ]]
  assert test_fails_skill_over_word_limit $?
}

test_counts_open_lessons() {
  new_tree
  printf -- '- 2026-11-08 · two simulators booted · tests timed out · boot one simulator only · bazel-ios\n' >> "$TREE/.claude/lessons.md"
  printf -- '- 2026-11-08 · stale spec · design changes not synced · diff the spec first · CLAUDE.md\n' >> "$TREE/.claude/lessons.md"
  run_check
  [ "$CODE" -eq 0 ] && [[ "$OUT" == *"2 open lessons"* ]]
  assert test_counts_open_lessons $?
}

test_fails_malformed_lesson() {
  new_tree
  printf -- '- something went wrong\n' >> "$TREE/.claude/lessons.md"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$OUT" == *"lesson"* ]]
  assert test_fails_malformed_lesson $?
}

test_passes_clean_tree
test_fails_name_not_matching_folder
test_fails_missing_version
test_fails_long_description
test_fails_skill_over_word_limit
test_counts_open_lessons
test_fails_malformed_lesson

echo "check-skills: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
