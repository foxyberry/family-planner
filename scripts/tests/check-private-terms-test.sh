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
  printf '# comment\n\n' > "$REPO/.private-terms"
  printf 'anything at all\n' > "$REPO/notes.md"
  git -C "$REPO" add notes.md
  run_check --staged
  [ "$CODE" -eq 0 ]
  assert test_ignores_comments_and_blank_lines $?
}

test_missing_terms_file_warns() {
  new_repo
  printf 'hello\n' > "$REPO/notes.md"
  git -C "$REPO" add notes.md
  run_check --staged
  [ "$CODE" -eq 0 ] && [[ "$ERR" == *".private-terms not found"* ]]
  assert test_missing_terms_file_warns $?
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

test_blocks_staged_term
test_passes_clean_change
test_ignores_comments_and_blank_lines
test_missing_terms_file_warns
test_checks_named_files

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
