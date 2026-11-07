#!/bin/bash
# Tests for scripts/check-private-terms.sh. Each test runs in a throwaway git repo.
set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/check-private-terms.sh"
PASS=0
FAIL=0

new_repo() {
  REPO="$(mktemp -d)"
  git -C "$REPO" init -q
  git -C "$REPO" config user.email test@example.com
  git -C "$REPO" config user.name test
}

run_check() { # args passed to the script; sets CODE, ERR
  ERR="$(cd "$REPO" && bash "$SCRIPT" "$@" 2>&1 >/dev/null)"
  CODE=$?
}

assert() { # name, condition result (0 = ok)
  if [ "$2" -eq 0 ]; then PASS=$((PASS + 1)); echo "PASS $1"; else FAIL=$((FAIL + 1)); echo "FAIL $1 (code=$CODE err=$ERR)"; fi
}

test_worktree_uses_main_checkout_terms() {
  new_repo
  printf 'Zebra Stop 99999\n' > "$REPO/.private-terms"
  printf 'base\n' > "$REPO/README.md"
  git -C "$REPO" add README.md && git -C "$REPO" commit -q -m base
  local WT="$REPO-wt"
  git -C "$REPO" worktree add -q "$WT" -b wt-test
  printf 'zebra stop 99999\n' > "$WT/notes.md"
  git -C "$WT" add notes.md
  ERR="$(cd "$WT" && bash "$SCRIPT" --staged 2>&1 >/dev/null)"; CODE=$?
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"private term found: Zebra Stop 99999"* ]]
  assert test_worktree_uses_main_checkout_terms $?
}

test_stdin_blocks_term() {
  new_repo
  printf 'Zebra Stop 99999\n' > "$REPO/.private-terms"
  ERR="$(cd "$REPO" && printf 'title\nmeet at ZEBRA stop 99999\n' | bash "$SCRIPT" --stdin "commit message" 2>&1 >/dev/null)"; CODE=$?
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"private term found: Zebra Stop 99999 in commit message"* ]]
  assert test_stdin_blocks_term $?
}

test_stdin_passes_clean_text() {
  new_repo
  printf 'Zebra Stop 99999\n' > "$REPO/.private-terms"
  ERR="$(cd "$REPO" && printf 'feat: add clock\n' | bash "$SCRIPT" --stdin "commit message" 2>&1 >/dev/null)"; CODE=$?
  [ "$CODE" -eq 0 ]
  assert test_stdin_passes_clean_text $?
}

test_blocks_staged_term() {
  new_repo
  printf 'Zebra Stop 99999\n' > "$REPO/.private-terms"
  printf 'meet at zebra stop 99999\n' > "$REPO/notes.md"
  git -C "$REPO" add notes.md
  run_check --staged
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"private term found: Zebra Stop 99999"* ]]
  assert test_blocks_staged_term $?
}

test_passes_clean_change() {
  new_repo
  printf 'Zebra Stop 99999\n' > "$REPO/.private-terms"
  printf 'hello\n' > "$REPO/notes.md"
  git -C "$REPO" add notes.md
  run_check --staged
  [ "$CODE" -eq 0 ]
  assert test_passes_clean_change $?
}

test_ignores_comments_and_blank_lines() {
  new_repo
  printf '# comment\n\nZebra Stop 99999\n' > "$REPO/.private-terms"
  printf 'comment and blank lines are not terms\n' > "$REPO/notes.md"
  git -C "$REPO" add notes.md
  run_check --staged
  [ "$CODE" -eq 0 ]
  assert test_ignores_comments_and_blank_lines $?
}

test_list_without_terms_fails_closed() {
  new_repo
  printf '# comment\n\n' > "$REPO/.private-terms"
  printf 'anything at all\n' > "$REPO/notes.md"
  git -C "$REPO" add notes.md
  run_check --staged
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"no terms"* ]]
  assert test_list_without_terms_fails_closed $?
}

test_blocks_term_in_renamed_file() {
  new_repo
  printf 'Zebra Stop 99999\n' > "$REPO/.private-terms"
  printf 'line one\nline two\nline three\nline four\n' > "$REPO/notes.md"
  git -C "$REPO" add notes.md && git -C "$REPO" commit -q -m base
  git -C "$REPO" mv notes.md renamed.md
  printf 'zebra stop 99999\n' >> "$REPO/renamed.md"
  git -C "$REPO" add renamed.md
  run_check --staged
  [ "$CODE" -eq 1 ]
  assert test_blocks_term_in_renamed_file $?
}

test_blocks_term_in_file_name() {
  new_repo
  printf 'Zebra Stop 99999\n' > "$REPO/.private-terms"
  mkdir -p "$REPO/routes"
  printf 'clean content\n' > "$REPO/routes/zebra stop 99999.md"
  git -C "$REPO" add routes
  run_check --staged
  [ "$CODE" -eq 1 ]
  assert test_blocks_term_in_file_name $?
}

test_example_list_has_no_active_terms() {
  ! grep -Ev '^[[:space:]]*(#|$)' "$(dirname "$SCRIPT")/../.private-terms.example" >/dev/null
  CODE=$?; ERR="example has active terms"
  assert test_example_list_has_no_active_terms $CODE
}

test_missing_terms_file_fails_closed() {
  new_repo
  printf 'hello\n' > "$REPO/notes.md"
  git -C "$REPO" add notes.md
  run_check --staged
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *".private-terms not found"* ]] && [[ "$ERR" == *".private-terms.example"* ]]
  assert test_missing_terms_file_fails_closed $?
}

test_blocks_term_in_unusual_filename() {
  new_repo
  printf 'Zebra Stop 99999\n' > "$REPO/.private-terms"
  printf 'zebra stop 99999\n' > "$REPO/my notes \"ü\".md"
  git -C "$REPO" add -- "my notes \"ü\".md"
  run_check --staged
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"private term found: Zebra Stop 99999"* ]]
  assert test_blocks_term_in_unusual_filename $?
}

test_blocks_term_on_line_starting_with_plus() {
  new_repo
  printf 'Zebra Stop 99999\n' > "$REPO/.private-terms"
  printf '++ zebra stop 99999\n' > "$REPO/notes.md"
  git -C "$REPO" add notes.md
  run_check --staged
  [ "$CODE" -eq 1 ]
  assert test_blocks_term_on_line_starting_with_plus $?
}

test_checks_named_files() {
  new_repo
  printf 'Zebra Stop 99999\n' > "$REPO/.private-terms"
  printf 'nothing here\n' > "$REPO/clean.md"
  printf 'see ZEBRA STOP 99999 later\n' > "$REPO/dirty.md"
  run_check clean.md dirty.md
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"private term found: Zebra Stop 99999 in dirty.md"* ]] && [[ "$ERR" != *"in clean.md"* ]]
  assert test_checks_named_files $?
}

test_worktree_uses_main_checkout_terms
test_stdin_blocks_term
test_stdin_passes_clean_text
test_blocks_staged_term
test_passes_clean_change
test_ignores_comments_and_blank_lines
test_list_without_terms_fails_closed
test_blocks_term_in_renamed_file
test_blocks_term_in_file_name
test_example_list_has_no_active_terms
test_missing_terms_file_fails_closed
test_blocks_term_in_unusual_filename
test_blocks_term_on_line_starting_with_plus
test_checks_named_files

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
