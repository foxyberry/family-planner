#!/bin/bash
# Tests for scripts/check-debug-boundary.sh (debug code stays in DebugTools and the app's entry).
set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/check-debug-boundary.sh"
PASS=0
FAIL=0

new_tree() {
  TREE="$(mktemp -d)"
  mkdir -p "$TREE/ios/Features/Grownup/Tests" "$TREE/ios/DebugTools" "$TREE/ios/App" "$TREE/ios/AppCore"
}

run_check() { ERR="$(bash "$SCRIPT" "$TREE" 2>&1 >/dev/null)"; CODE=$?; }

assert() {
  if [ "$2" -eq 0 ]; then PASS=$((PASS + 1)); echo "PASS $1"; else FAIL=$((FAIL + 1)); echo "FAIL $1 (code=$CODE err=$ERR)"; fi
}

test_blocks_if_debug_in_a_feature() {
  new_tree
  printf 'struct Editor {\n    #if DEBUG\n    var board = 1\n    #endif\n}\n' > "$TREE/ios/Features/Grownup/Editor.swift"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"Editor.swift:2"* ]]
  assert test_blocks_if_debug_in_a_feature $?
}

test_blocks_debug_model_in_a_feature() {
  new_tree
  printf 'let scale = DebugModel.installed?.rigScale\n' > "$TREE/ios/Features/Grownup/Clock.swift"
  run_check
  [ "$CODE" -eq 1 ]
  assert test_blocks_debug_model_in_a_feature $?
}

test_blocks_a_new_app_core_file() {
  new_tree
  printf '#if DEBUG\n#endif\n' > "$TREE/ios/AppCore/Links.swift"
  run_check
  [ "$CODE" -eq 1 ]
  assert test_blocks_a_new_app_core_file $?
}

test_allows_debug_tools_app_overlay_and_tests() {
  new_tree
  printf '#if DEBUG\nfinal class DebugModel {}\n#endif\n' > "$TREE/ios/DebugTools/DebugModel.swift"
  printf '#if DEBUG\nDebugModel.install(into: &dependencies)\n#endif\n' > "$TREE/ios/App/App.swift"
  printf '#if DEBUG\nimport DebugTools\n#endif\n' > "$TREE/ios/AppCore/AppView.swift"
  printf '#if DEBUG\n#endif\n' > "$TREE/ios/Features/Grownup/Tests/EditorTests.swift"
  run_check
  [ "$CODE" -eq 0 ]
  assert test_allows_debug_tools_app_overlay_and_tests $?
}

test_blocks_if_debug_in_a_feature
test_blocks_debug_model_in_a_feature
test_blocks_a_new_app_core_file
test_allows_debug_tools_app_overlay_and_tests

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
