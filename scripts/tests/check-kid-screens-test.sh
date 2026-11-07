#!/bin/bash
# Tests for scripts/check-kid-screens.sh (board 0f: kid screens never scroll).
set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/check-kid-screens.sh"
PASS=0
FAIL=0

new_tree() { TREE="$(mktemp -d)"; mkdir -p "$TREE/ios/Features/Morning" "$TREE/ios/DesignSystem/Gallery"; }

run_check() { ERR="$(bash "$SCRIPT" "$TREE" 2>&1 >/dev/null)"; CODE=$?; }

assert() {
  if [ "$2" -eq 0 ]; then PASS=$((PASS + 1)); echo "PASS $1"; else FAIL=$((FAIL + 1)); echo "FAIL $1 (code=$CODE err=$ERR)"; fi
}

test_blocks_scroll_view_in_kid_screen() {
  new_tree
  printf 'KidScreen { Text("Hi") } body: { _ in ScrollView { Text("x") } }\n' > "$TREE/ios/Features/Morning/MorningView.swift"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"MorningView.swift"* ]]
  assert test_blocks_scroll_view_in_kid_screen $?
}

test_blocks_list_in_kid_screen() {
  new_tree
  printf 'KidScreen { Text("Hi") } body: { _ in List(items) { Text($0) } }\n' > "$TREE/ios/Features/Morning/MorningView.swift"
  run_check
  [ "$CODE" -eq 1 ]
  assert test_blocks_list_in_kid_screen $?
}

test_passes_clean_kid_screen() {
  new_tree
  printf 'KidScreen { Text("Hi") } body: { _ in VStack { Text("x") } }\n' > "$TREE/ios/Features/Morning/MorningView.swift"
  run_check
  [ "$CODE" -eq 0 ]
  assert test_passes_clean_kid_screen $?
}

test_grownup_screens_may_scroll() {
  new_tree
  printf 'GrownupScreen { Text("Hi") } content: { ScrollView { Text("x") } } primaryAction: { }\n' \
    > "$TREE/ios/Features/Morning/SettingsView.swift"
  run_check
  [ "$CODE" -eq 0 ]
  assert test_grownup_screens_may_scroll $?
}

test_gallery_is_exempt() {
  new_tree
  printf 'ScrollView { KidScreen { Text("Hi") } body: { _ in Text("x") } }\n' > "$TREE/ios/DesignSystem/Gallery/ComponentGallery.swift"
  run_check
  [ "$CODE" -eq 0 ]
  assert test_gallery_is_exempt $?
}

test_repo_passes() {
  ERR="$(bash "$SCRIPT" 2>&1 >/dev/null)"; CODE=$?
  [ "$CODE" -eq 0 ]
  assert test_repo_passes $?
}

test_blocks_scroll_view_in_kid_screen
test_blocks_list_in_kid_screen
test_passes_clean_kid_screen
test_grownup_screens_may_scroll
test_gallery_is_exempt
test_repo_passes

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
