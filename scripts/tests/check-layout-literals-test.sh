#!/bin/bash
# Tests for scripts/check-layout-literals.sh (screens carry no layout numbers or offsets).
set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/check-layout-literals.sh"
PASS=0
FAIL=0

new_tree() {
  TREE="$(mktemp -d)"
  mkdir -p "$TREE/ios/Features/Home/Tests" "$TREE/ios/AppCore" "$TREE/scripts"
}

run_check() { ERR="$(bash "$SCRIPT" "$TREE" 2>&1 >/dev/null)"; CODE=$?; }

assert() {
  if [ "$2" -eq 0 ]; then PASS=$((PASS + 1)); echo "PASS $1"; else FAIL=$((FAIL + 1)); echo "FAIL $1 (code=$CODE err=$ERR)"; fi
}

test_blocks_offset() {
  new_tree
  printf 'Text("a")\n    .offset(x: 20, y: -20)\n' > "$TREE/ios/Features/Home/HomeView.swift"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"HomeView.swift:2"* ]]
  assert test_blocks_offset $?
}

test_blocks_number_in_frame_padding_spacing() {
  new_tree
  printf '.frame(width: 112)\n' > "$TREE/ios/Features/Home/AView.swift"
  printf '.padding(.leading, layout.inset + 8)\n' > "$TREE/ios/Features/Home/BView.swift"
  printf 'HStack(spacing: 12) {}\n' > "$TREE/ios/AppCore/CView.swift"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"AView.swift"* ]] && [[ "$ERR" == *"BView.swift"* ]] && [[ "$ERR" == *"CView.swift"* ]]
  assert test_blocks_number_in_frame_padding_spacing $?
}

test_passes_tokens() {
  new_tree
  printf '.frame(width: sizing.swatch2, height: layout.row)\n.padding(.top, Spacing.m)\nHStack(spacing: Spacing.sm) {}\n' \
    > "$TREE/ios/Features/Home/HomeView.swift"
  run_check
  [ "$CODE" -eq 0 ]
  assert test_passes_tokens $?
}

test_layouts_and_tests_are_exempt() {
  new_tree
  printf '.frame(width: 112)\n' > "$TREE/ios/Features/Home/HomeLayout.swift"
  printf '.frame(width: 112)\n' > "$TREE/ios/Features/Home/Tests/HomeView.swift"
  run_check
  [ "$CODE" -eq 0 ]
  assert test_layouts_and_tests_are_exempt $?
}

test_pending_allows_its_count_only() {
  new_tree
  printf '.frame(width: 112)\n.offset(x: 4)\n' > "$TREE/ios/Features/Home/HomeView.swift"
  printf '# header\nios/Features/Home/HomeView.swift 2\n' > "$TREE/scripts/layout-literals-pending.txt"
  run_check
  [ "$CODE" -eq 0 ] || { assert test_pending_allows_its_count_only 1; return; }
  printf '.frame(width: 112)\n.offset(x: 4)\n.padding(3)\n' > "$TREE/ios/Features/Home/HomeView.swift"
  run_check
  [ "$CODE" -eq 1 ]
  assert test_pending_allows_its_count_only $?
}

test_pending_must_shrink_with_the_file() {
  new_tree
  printf '.frame(width: 112)\n' > "$TREE/ios/Features/Home/HomeView.swift"
  printf 'ios/Features/Home/HomeView.swift 3\nios/Features/Home/GoneView.swift 1\n' > "$TREE/scripts/layout-literals-pending.txt"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"pending count too high"* ]] && [[ "$ERR" == *"missing file"* ]]
  assert test_pending_must_shrink_with_the_file $?
}

test_repo_passes() {
  ERR="$(bash "$SCRIPT" 2>&1 >/dev/null)"; CODE=$?
  [ "$CODE" -eq 0 ]
  assert test_repo_passes $?
}

test_blocks_offset
test_blocks_number_in_frame_padding_spacing
test_passes_tokens
test_layouts_and_tests_are_exempt
test_pending_allows_its_count_only
test_pending_must_shrink_with_the_file
test_repo_passes

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
