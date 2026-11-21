#!/bin/bash
# Tests for scripts/check-layout-versions.sh: comments citing a board at an older layout version.
set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/check-layout-versions.sh"
PASS=0
FAIL=0

new_tree() {
  TREE="$(mktemp -d)"
  mkdir -p "$TREE/ios/Features/Setup" "$TREE/docs/superpowers/layout" "$TREE/scripts"
  printf '{"version": "60", "elements": []}\n' > "$TREE/docs/superpowers/layout/S2.json"
  printf '{"version": "57", "elements": []}\n' > "$TREE/docs/superpowers/layout/S3.json"
}

run_with() { # Swift comment line
  printf '%s\nstruct SetupView {}\n' "$1" > "$TREE/ios/Features/Setup/SetupView.swift"
  ERR="$(bash "$SCRIPT" "$TREE" 2>&1 >/dev/null)"; CODE=$?
}

assert() {
  if [ "$2" -eq 0 ]; then PASS=$((PASS + 1)); echo "PASS $1"; else FAIL=$((FAIL + 1)); echo "FAIL $1 (code=$CODE err=$ERR)"; fi
}

new_tree; run_with '/// Board S2 (layout v56): rows 24 apart.'
[ "$CODE" -eq 1 ] && [[ "$ERR" == *"board S2 cited at layout v56, S2.json is v60"* ]]; assert "an older version than the board's JSON blocks (the S2 case)" $?

new_tree; run_with '/// Board S2 (layout v60): rows 24 apart.'
[ "$CODE" -eq 0 ]; assert "the board's current version passes" $?

new_tree; run_with '/// Boards S2 and S3 (layout v57): kid tabs.'
[ "$CODE" -eq 1 ] && [[ "$ERR" == *"board S2"* ]] && [[ "$ERR" != *"board S3"* ]]; assert "each named board is checked on its own" $?

new_tree; run_with '/// Spec "Layout balance" (layout v12): rows 24 apart.'
[ "$CODE" -eq 0 ]; assert "a citation without a known board is skipped" $?

new_tree; run_with 'let s2 = "S2 layout v1" // no board before the version'
[ "$CODE" -eq 0 ]; assert "text outside the comment is ignored" $?

# --diff: only lines a push adds or changes; an old stale comment doesn't block someone else's push.
diff_tree() {
  new_tree
  git -C "$TREE" init -q
  git -C "$TREE" config user.email t@example.com
  git -C "$TREE" config user.name t
  printf '/// Board S2 (layout v56): an old comment.\nstruct SetupView {}\n' > "$TREE/ios/Features/Setup/SetupView.swift"
  snapshot base
}
snapshot() { git -C "$TREE" add -A && git -C "$TREE" commit -q -m "$1"; }
run_diff() { ERR="$(cd "$TREE" && bash "$SCRIPT" --diff HEAD~1 HEAD 2>&1 >/dev/null)"; CODE=$?; }

diff_tree; printf 'struct Other {}\n' > "$TREE/ios/Features/Setup/Other.swift"; snapshot other; run_diff
[ "$CODE" -eq 0 ]; assert "diff: an untouched old comment doesn't block" $?

diff_tree; printf '/// Board S3 (layout v40): new.\nstruct Other {}\n' > "$TREE/ios/Features/Setup/Other.swift"; snapshot other; run_diff
[ "$CODE" -eq 1 ] && [[ "$ERR" == *"Other.swift:1: board S3 cited at layout v40, S3.json is v57"* ]]
assert "diff: a new stale comment blocks" $?

diff_tree; printf '/// Board S2 (layout v58): edited.\nstruct SetupView {}\n' > "$TREE/ios/Features/Setup/SetupView.swift"; snapshot edit; run_diff
[ "$CODE" -eq 1 ] && [[ "$ERR" == *"board S2"* ]]; assert "diff: an edited comment must cite the current version" $?

diff_tree; printf '/// Board S2 (layout v60): edited.\nstruct SetupView {}\n' > "$TREE/ios/Features/Setup/SetupView.swift"; snapshot edit; run_diff
[ "$CODE" -eq 0 ]; assert "diff: an edit to the current version passes" $?

echo "check-layout-versions: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
