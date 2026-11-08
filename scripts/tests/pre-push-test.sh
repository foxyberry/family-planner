#!/bin/bash
# Tests for .githooks/pre-push. Each test pushes from a throwaway repo to a throwaway bare
# remote. gitleaks and buildifier are stubs, so these run anywhere (CI included).
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$(cd "$HERE/../.." && pwd)"
PASS=0
FAIL=0
STUBS="$(mktemp -d)"
LOG="$STUBS/calls.log"

# Stubs log their arguments and exit with STUB_<NAME>_EXIT (default 0).
for tool in gitleaks buildifier; do
  upper="$(echo "$tool" | tr '[:lower:]' '[:upper:]')"
  cat > "$STUBS/$tool" <<EOF
#!/bin/bash
echo "$tool \$*" >> "$LOG"
exit "\${STUB_${upper}_EXIT:-0}"
EOF
  chmod +x "$STUBS/$tool"
done
export PATH="$STUBS:/usr/bin:/bin"

new_repo() {
  : > "$LOG"
  REMOTE="$(mktemp -d)"
  REPO="$(mktemp -d)"
  git -C "$REMOTE" init -q --bare
  git -C "$REPO" init -q -b develop
  git -C "$REPO" config user.email test@example.com
  git -C "$REPO" config user.name test
  git -C "$REPO" config core.hooksPath .githooks
  git -C "$REPO" remote add origin "$REMOTE"
  mkdir -p "$REPO/.githooks" "$REPO/scripts"
  cp "$SRC/.githooks/pre-push" "$REPO/.githooks/"
  cp "$SRC/scripts/check-private-terms.sh" "$REPO/scripts/"
  cp "$SRC/scripts/check-kid-screens.sh" "$REPO/scripts/"
  cp "$SRC/scripts/check-dependencies.sh" "$SRC/scripts/check-skills.sh" "$REPO/scripts/"
  cp "$SRC/Makefile" "$REPO/"
  printf 'Zebra Stop 99999\n' > "$REPO/.private-terms"
  printf '.private-terms\n' > "$REPO/.gitignore"
  git -C "$REPO" add -A && git -C "$REPO" commit -q -m base
}

commit_file() { # path, content, message
  mkdir -p "$(dirname "$REPO/$1")"
  printf '%s\n' "$2" > "$REPO/$1"
  git -C "$REPO" add -- "$1" && git -C "$REPO" commit -q -m "$3"
}

push() { # args to git push; sets CODE, ERR
  ERR="$(git -C "$REPO" push -q origin "$@" 2>&1)"
  CODE=$?
}

remote_has() { git -C "$REMOTE" rev-parse -q --verify "$1" >/dev/null; }

assert() { # name, condition result (0 = ok)
  if [ "$2" -eq 0 ]; then PASS=$((PASS + 1)); echo "PASS $1"; else FAIL=$((FAIL + 1)); echo "FAIL $1 (code=$CODE err=$ERR)"; fi
}

test_clean_push_passes_and_scans_new_commits() {
  new_repo
  commit_file notes.md clean clean
  local HEAD_SHA; HEAD_SHA="$(git -C "$REPO" rev-parse HEAD)"
  push develop
  [ "$CODE" -eq 0 ] && remote_has refs/heads/develop && grep -q "gitleaks git .*$HEAD_SHA" "$LOG"
  assert test_clean_push_passes_and_scans_new_commits $?
}

test_blocks_term_in_commit_message() {
  new_repo
  commit_file notes.md clean 'docs: near zebra stop 99999'
  push develop
  [ "$CODE" -ne 0 ] && ! remote_has refs/heads/develop && [[ "$ERR" == *"private term found"* ]]
  assert test_blocks_term_in_commit_message $?
}

test_blocks_term_added_then_removed() {
  new_repo
  commit_file notes.md 'zebra stop 99999' add
  commit_file notes.md 'clean again' remove
  push develop
  [ "$CODE" -ne 0 ] && ! remote_has refs/heads/develop
  assert test_blocks_term_added_then_removed $?
}

test_blocks_term_in_branch_name() {
  new_repo
  printf 'kidzebra\n' >> "$REPO/.private-terms"
  push 'develop:refs/heads/feature/kidzebra-day'
  [ "$CODE" -ne 0 ] && [[ "$ERR" == *"ref name"* ]]
  assert test_blocks_term_in_branch_name $?
}

test_checks_only_commits_new_to_the_remote() {
  new_repo
  commit_file notes.md 'old words' old
  push develop
  # A term added to the list later must not block pushes for commits already published.
  printf 'old words\n' >> "$REPO/.private-terms"
  commit_file other.md clean new
  push develop
  [ "$CODE" -eq 0 ]
  assert test_checks_only_commits_new_to_the_remote $?
}

test_new_branch_skips_commits_already_on_remote() {
  new_repo
  commit_file notes.md 'old words' old
  push develop
  printf 'old words\n' >> "$REPO/.private-terms"
  git -C "$REPO" switch -q -c feature/x
  commit_file other.md clean new
  push feature/x
  [ "$CODE" -eq 0 ]
  assert test_new_branch_skips_commits_already_on_remote $?
}

test_gitleaks_finding_blocks_push() {
  new_repo
  STUB_GITLEAKS_EXIT=1 push develop
  [ "$CODE" -ne 0 ] && ! remote_has refs/heads/develop
  assert test_gitleaks_finding_blocks_push $?
}

test_missing_gitleaks_blocks_push() {
  new_repo
  ERR="$(PATH=/usr/bin:/bin git -C "$REPO" push -q origin develop 2>&1)"; CODE=$?
  [ "$CODE" -ne 0 ] && [[ "$ERR" == *"gitleaks is not installed"* ]]
  assert test_missing_gitleaks_blocks_push $?
}

test_bazel_change_runs_lint_and_failure_blocks() {
  new_repo
  push develop
  commit_file ios/BUILD.bazel '# empty' build
  : > "$LOG"
  STUB_BUILDIFIER_EXIT=4 push develop
  [ "$CODE" -ne 0 ] && grep -q '^buildifier ' "$LOG"
  assert test_bazel_change_runs_lint_and_failure_blocks $?
}

test_other_change_skips_lint() {
  new_repo
  push develop
  commit_file ios/App.swift '// code' code
  : > "$LOG"
  push develop
  [ "$CODE" -eq 0 ] && ! grep -q '^buildifier ' "$LOG"
  assert test_other_change_skips_lint $?
}

test_scrolling_kid_screen_blocks_push() {
  new_repo
  push develop
  commit_file ios/Features/MorningView.swift 'KidScreen { } body: { _ in ScrollView { } }' scroll
  push develop
  [ "$CODE" -ne 0 ] && [[ "$ERR" == *"kid screen scrolls"* ]]
  assert test_scrolling_kid_screen_blocks_push $?
}

test_device_calendar_blocks_push() {
  new_repo
  push develop
  commit_file ios/Features/HomeModel.swift 'let calendar = Calendar.current' calendar
  push develop
  [ "$CODE" -ne 0 ] && [[ "$ERR" == *"global read"* ]]
  assert test_device_calendar_blocks_push $?
}

test_guard_change_runs_guard_tests_and_failure_blocks() {
  new_repo
  push develop
  commit_file scripts/tests/fake-test.sh 'echo ran >> "$0.ran"; exit 1' guard
  push develop
  [ "$CODE" -ne 0 ] && [ -f "$REPO/scripts/tests/fake-test.sh.ran" ]
  assert test_guard_change_runs_guard_tests_and_failure_blocks $?
}

test_blocks_term_in_tag_message() {
  new_repo
  push develop
  git -C "$REPO" tag -a v0.0.1 -m 'release near zebra stop 99999'
  push v0.0.1
  [ "$CODE" -ne 0 ] && ! remote_has refs/tags/v0.0.1
  assert test_blocks_term_in_tag_message $?
}

test_branch_delete_passes() {
  new_repo
  push develop
  push develop:refs/heads/feature/y
  push --delete feature/y
  [ "$CODE" -eq 0 ] && ! remote_has refs/heads/feature/y
  assert test_branch_delete_passes $?
}

test_clean_push_passes_and_scans_new_commits
test_blocks_term_in_commit_message
test_blocks_term_added_then_removed
test_blocks_term_in_branch_name
test_checks_only_commits_new_to_the_remote
test_new_branch_skips_commits_already_on_remote
test_gitleaks_finding_blocks_push
test_missing_gitleaks_blocks_push
test_bazel_change_runs_lint_and_failure_blocks
test_other_change_skips_lint
test_scrolling_kid_screen_blocks_push
test_device_calendar_blocks_push
test_guard_change_runs_guard_tests_and_failure_blocks
test_blocks_term_in_tag_message
test_branch_delete_passes

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
