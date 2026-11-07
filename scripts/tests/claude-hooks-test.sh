#!/bin/bash
# Tests for the Claude Code privacy hooks in .claude/hooks. Each test feeds hook JSON on stdin
# inside a throwaway git repo whose .private-terms holds a fake term.
set -u

HOOKS="$(cd "$(dirname "$0")/../.." && pwd)/.claude/hooks"
TERM_TEXT="zebra stop 99999"
PASS=0
FAIL=0

new_repo() {
  REPO="$(mktemp -d)"
  git -C "$REPO" init -q
  printf 'Zebra Stop 99999\n' > "$REPO/.private-terms"
  printf 'docs/private/\n.private-terms\n' > "$REPO/.gitignore"
  mkdir -p "$REPO/docs/private" "$REPO/src"
}

run_hook() { # hook-name json ; sets CODE, ERR
  ERR="$(printf '%s' "$2" | (cd "$REPO" && CLAUDE_PROJECT_DIR="$REPO" bash "$HOOKS/$1" 2>&1 >/dev/null))"
  CODE=$?
}

assert() {
  if [ "$2" -eq 0 ]; then PASS=$((PASS + 1)); echo "PASS $1"; else FAIL=$((FAIL + 1)); echo "FAIL $1 (code=$CODE err=$ERR)"; fi
}

write_json() { jq -nc --arg f "$1" --arg c "$2" --arg cwd "$REPO" '{cwd:$cwd, tool_name:"Write", tool_input:{file_path:$f, content:$c}}'; }
edit_json() { jq -nc --arg f "$1" --arg n "$2" --arg cwd "$REPO" '{cwd:$cwd, tool_name:"Edit", tool_input:{file_path:$f, old_string:"x", new_string:$n}}'; }
bash_json() { jq -nc --arg c "$1" --arg cwd "$REPO" '{cwd:$cwd, tool_name:"Bash", tool_input:{command:$c}}'; }

test_write_guard_blocks_term_in_tracked_file() {
  new_repo
  run_hook privacy-write-guard.sh "$(write_json "$REPO/src/notes.md" "we meet at $TERM_TEXT")"
  [ "$CODE" -eq 2 ] && [[ "$ERR" == *"Zebra Stop 99999"* ]]
  assert test_write_guard_blocks_term_in_tracked_file $?
}

test_write_guard_allows_term_in_gitignored_file() {
  new_repo
  run_hook privacy-write-guard.sh "$(write_json "$REPO/docs/private/design.md" "we meet at $TERM_TEXT")"
  [ "$CODE" -eq 0 ]
  assert test_write_guard_allows_term_in_gitignored_file $?
}

test_write_guard_allows_clean_write() {
  new_repo
  run_hook privacy-write-guard.sh "$(write_json "$REPO/src/notes.md" "bus 12345 at Example Primary School")"
  [ "$CODE" -eq 0 ]
  assert test_write_guard_allows_clean_write $?
}

test_write_guard_blocks_term_in_edit() {
  new_repo
  run_hook privacy-write-guard.sh "$(edit_json "$REPO/src/a.swift" "let stop = \"$TERM_TEXT\"")"
  [ "$CODE" -eq 2 ]
  assert test_write_guard_blocks_term_in_edit $?
}

test_write_guard_ignores_files_outside_any_repo() {
  new_repo
  local OUT; OUT="$(mktemp -d)"
  run_hook privacy-write-guard.sh "$(write_json "$OUT/scratch.md" "we meet at $TERM_TEXT")"
  [ "$CODE" -eq 0 ]
  assert test_write_guard_ignores_files_outside_any_repo $?
}

test_public_text_guard_blocks_commit_message() {
  new_repo
  run_hook public-text-guard.sh "$(bash_json "git commit -m \"docs: route via $TERM_TEXT\"")"
  [ "$CODE" -eq 2 ] && [[ "$ERR" == *"Zebra Stop 99999"* ]]
  assert test_public_text_guard_blocks_commit_message $?
}

test_public_text_guard_blocks_pr_body_file() {
  new_repo
  printf 'Summary\nnear %s\n' "$TERM_TEXT" > "$REPO/pr-body.md"
  run_hook public-text-guard.sh "$(bash_json "gh pr create --base develop --title 'feat: x' --body-file pr-body.md")"
  [ "$CODE" -eq 2 ]
  assert test_public_text_guard_blocks_pr_body_file $?
}

test_public_text_guard_allows_clean_commit() {
  new_repo
  run_hook public-text-guard.sh "$(bash_json "git commit -m 'feat: add clock'")"
  [ "$CODE" -eq 0 ]
  assert test_public_text_guard_allows_clean_commit $?
}

test_public_text_guard_ignores_other_commands() {
  new_repo
  run_hook public-text-guard.sh "$(bash_json "grep -n '$TERM_TEXT' docs/private/design.md")"
  [ "$CODE" -eq 0 ]
  assert test_public_text_guard_ignores_other_commands $?
}

test_public_text_guard_blocks_gh_api_body() {
  new_repo
  run_hook public-text-guard.sh "$(bash_json "gh api repos/o/r/issues -f title=x -f body='near $TERM_TEXT'")"
  [ "$CODE" -eq 2 ]
  assert test_public_text_guard_blocks_gh_api_body $?
}

test_public_text_guard_blocks_gh_called_by_path() {
  new_repo
  run_hook public-text-guard.sh "$(bash_json "/opt/homebrew/bin/gh pr create --title x --body 'near $TERM_TEXT'")"
  [ "$CODE" -eq 2 ]
  assert test_public_text_guard_blocks_gh_called_by_path $?
}

test_public_text_guard_blocks_positional_gist_file() {
  new_repo
  printf 'near %s\n' "$TERM_TEXT" > "$REPO/notes.md"
  run_hook public-text-guard.sh "$(bash_json "gh gist create --public notes.md")"
  [ "$CODE" -eq 2 ]
  assert test_public_text_guard_blocks_positional_gist_file $?
}

test_public_text_guard_blocks_command_substitution() {
  new_repo
  run_hook public-text-guard.sh "$(bash_json 'gh pr create --title x --body "$(cat body.txt)"')"
  [ "$CODE" -eq 2 ] && [[ "$ERR" == *"--body-file"* ]]
  assert test_public_text_guard_blocks_command_substitution $?
}

test_public_text_guard_allows_heredoc_commit() {
  new_repo
  run_hook public-text-guard.sh "$(bash_json "$(printf 'git commit -m "$(cat <<%sEOF%s\nfeat: add clock\nEOF\n)"' "'" "'")")"
  [ "$CODE" -eq 0 ]
  assert test_public_text_guard_allows_heredoc_commit $?
}

test_public_text_guard_blocks_at_file_reference() {
  new_repo
  printf 'near %s\n' "$TERM_TEXT" > "$REPO/note.md"
  run_hook public-text-guard.sh "$(bash_json "gh api repos/o/r/issues -f title=x -F body=@note.md")"
  [ "$CODE" -eq 2 ]
  assert test_public_text_guard_blocks_at_file_reference $?
}

test_public_text_guard_blocks_variable_expansion() {
  new_repo
  run_hook public-text-guard.sh "$(bash_json 'gh pr create --title x --body "$BODY"')"
  [ "$CODE" -eq 2 ]
  assert test_public_text_guard_blocks_variable_expansion $?
}

test_public_text_guard_blocks_process_substitution() {
  new_repo
  run_hook public-text-guard.sh "$(bash_json 'gh pr create --title x --body-file <(make_body)')"
  [ "$CODE" -eq 2 ]
  assert test_public_text_guard_blocks_process_substitution $?
}

test_public_text_guard_blocks_piped_stdin_body() {
  new_repo
  run_hook public-text-guard.sh "$(bash_json 'make_body | gh pr create --title x --body-file -')"
  [ "$CODE" -eq 2 ]
  assert test_public_text_guard_blocks_piped_stdin_body $?
}

test_public_text_guard_allows_heredoc_stdin_body() {
  new_repo
  run_hook public-text-guard.sh "$(bash_json "$(printf 'gh pr create --title x --body-file - <<%sEOF%s\nSummary: add clock\nEOF' "'" "'")")"
  [ "$CODE" -eq 0 ]
  assert test_public_text_guard_allows_heredoc_stdin_body $?
}

test_public_text_guard_blocks_ansi_c_quoting() {
  new_repo
  run_hook public-text-guard.sh "$(bash_json "gh pr create --title x --body \$'line\\nmore'")"
  [ "$CODE" -eq 2 ]
  assert test_public_text_guard_blocks_ansi_c_quoting $?
}

test_public_text_guard_blocks_piped_body_even_with_heredoc_elsewhere() {
  new_repo
  run_hook public-text-guard.sh "$(bash_json "$(printf 'make_body | gh pr create --title x --body-file - && cat <<%sEOF%s\nunrelated\nEOF' "'" "'")")"
  [ "$CODE" -eq 2 ]
  assert test_public_text_guard_blocks_piped_body_even_with_heredoc_elsewhere $?
}

test_public_text_guard_blocks_positional_stdin() {
  new_repo
  run_hook public-text-guard.sh "$(bash_json "gh gist create --public - < body.md")"
  [ "$CODE" -eq 2 ]
  assert test_public_text_guard_blocks_positional_stdin $?
}

test_public_text_guard_allows_bulleted_commit_message() {
  new_repo
  run_hook public-text-guard.sh "$(bash_json "$(printf 'git commit -m "feat: add guards\n\n- first - item\n- second item"')")"
  [ "$CODE" -eq 0 ]
  assert test_public_text_guard_allows_bulleted_commit_message $?
}

test_write_guard_blocks_term_in_tracked_file
test_write_guard_allows_term_in_gitignored_file
test_public_text_guard_allows_bulleted_commit_message
test_public_text_guard_blocks_ansi_c_quoting
test_public_text_guard_blocks_piped_body_even_with_heredoc_elsewhere
test_public_text_guard_blocks_positional_stdin
test_public_text_guard_blocks_at_file_reference
test_public_text_guard_blocks_variable_expansion
test_public_text_guard_blocks_process_substitution
test_public_text_guard_blocks_piped_stdin_body
test_public_text_guard_allows_heredoc_stdin_body
test_public_text_guard_blocks_gh_api_body
test_public_text_guard_blocks_gh_called_by_path
test_public_text_guard_blocks_positional_gist_file
test_public_text_guard_blocks_command_substitution
test_public_text_guard_allows_heredoc_commit
test_write_guard_allows_clean_write
test_write_guard_blocks_term_in_edit
test_write_guard_ignores_files_outside_any_repo
test_public_text_guard_blocks_commit_message
test_public_text_guard_blocks_pr_body_file
test_public_text_guard_allows_clean_commit
test_public_text_guard_ignores_other_commands

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
