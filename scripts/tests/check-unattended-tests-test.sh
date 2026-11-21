#!/bin/bash
# Tests for scripts/check-unattended-tests.sh (no test waits for a person: no real Face ID, UI tests
# launch only through TestApp with -fpSkipFaceID).
set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/check-unattended-tests.sh"
PASS=0
FAIL=0

new_tree() {
  TREE="$(mktemp -d)"
  mkdir -p "$TREE/ios/Journeys/Tests/UI" "$TREE/ios/Features/Home/Tests" "$TREE/ios/Clients/ParentAuthClientLive"
  printf 'let app = XCUIApplication()\napp.launchArguments = ["-fpNow", now, "-fpSkipFaceID"]\napp.launch()\n' \
    > "$TREE/ios/Journeys/Tests/UI/App.swift"
  printf 'let app = TestApp.launch(family: "sample")\n' > "$TREE/ios/Journeys/Tests/UI/LockUITests.swift"
  # Live code may use LAContext; only tests may not.
  printf 'let context = LAContext()\n' > "$TREE/ios/Clients/ParentAuthClientLive/ParentAuthClientLive.swift"
}

run_check() { ERR="$(bash "$SCRIPT" "$TREE" 2>&1 >/dev/null)"; CODE=$?; }

assert() {
  if [ "$2" -eq 0 ]; then PASS=$((PASS + 1)); echo "PASS $1"; else FAIL=$((FAIL + 1)); echo "FAIL $1 (code=$CODE err=$ERR)"; fi
}

test_passes_on_a_clean_tree() {
  new_tree
  run_check
  [ "$CODE" -eq 0 ]
  assert test_passes_on_a_clean_tree $?
}

test_blocks_real_face_id_in_a_test() {
  new_tree
  printf 'let context = LAContext()\n' > "$TREE/ios/Features/Home/Tests/ATests.swift"
  printf '$0.parentAuth = .live\n' > "$TREE/ios/Features/Home/Tests/BTests.swift"
  printf '// LAContext is faked here\nlet a = 1\n' > "$TREE/ios/Features/Home/Tests/CTests.swift"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"ATests.swift"* ]] && [[ "$ERR" == *"BTests.swift"* ]] && [[ "$ERR" != *"CTests.swift"* ]]
  assert test_blocks_real_face_id_in_a_test $?
}

test_blocks_a_ui_test_that_launches_itself() {
  new_tree
  printf 'let app = XCUIApplication()\napp.launch()\n' > "$TREE/ios/Journeys/Tests/UI/SetupUITests.swift"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"UI test starts the app itself: ios/Journeys/Tests/UI/SetupUITests.swift"* ]]
  assert test_blocks_a_ui_test_that_launches_itself $?
}

test_blocks_a_launcher_without_the_skip_flag() {
  new_tree
  printf 'let app = XCUIApplication()\napp.launchArguments = ["-fpNow", now]\napp.launch()\n' \
    > "$TREE/ios/Journeys/Tests/UI/App.swift"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"must pass -fpSkipFaceID"* ]]
  assert test_blocks_a_launcher_without_the_skip_flag $?
}

test_passes_on_a_clean_tree
test_blocks_real_face_id_in_a_test
test_blocks_a_ui_test_that_launches_itself
test_blocks_a_launcher_without_the_skip_flag

echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
