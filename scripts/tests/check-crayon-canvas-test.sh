#!/bin/bash
# Tests for scripts/check-crayon-canvas.sh (a Canvas clips crayon wobble at its bounds).
set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/check-crayon-canvas.sh"
PASS=0
FAIL=0

new_tree() { TREE="$(mktemp -d)"; mkdir -p "$TREE/ios/DesignSystem/Controls" "$TREE/ios/CrayonKit" "$TREE/ios/DesignSystem/Tests"; }

run_check() { ERR="$(bash "$SCRIPT" "$TREE" 2>&1 >/dev/null)"; CODE=$?; }

assert() {
  if [ "$2" -eq 0 ]; then PASS=$((PASS + 1)); echo "PASS $1"; else FAIL=$((FAIL + 1)); echo "FAIL $1 (code=$CODE err=$ERR)"; fi
}

test_blocks_canvas_without_note() {
  new_tree
  printf 'var body: some View {\n    Canvas { context, _ in }\n}\n' > "$TREE/ios/DesignSystem/Controls/Badge.swift"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"Badge.swift:2"* ]]
  assert test_blocks_canvas_without_note $?
}

test_blocks_canvas_initialiser_form() {
  new_tree
  printf 'Canvas(opaque: false) { context, _ in }\n' > "$TREE/ios/DesignSystem/Controls/Badge.swift"
  run_check
  [ "$CODE" -eq 1 ]
  assert test_blocks_canvas_initialiser_form $?
}

test_passes_canvas_with_note() {
  new_tree
  printf 'Canvas { context, _ in  // bleed-ok: straight ticks inside the frame\n}\n' > "$TREE/ios/DesignSystem/Controls/Badge.swift"
  run_check
  [ "$CODE" -eq 0 ]
  assert test_passes_canvas_with_note $?
}

test_crayon_surface_and_tests_are_exempt() {
  new_tree
  printf 'Canvas { context, size in }\n' > "$TREE/ios/CrayonKit/CrayonSurface.swift"
  printf 'Canvas { context, size in }\n' > "$TREE/ios/DesignSystem/Tests/BadgeTests.swift"
  run_check
  [ "$CODE" -eq 0 ]
  assert test_crayon_surface_and_tests_are_exempt $?
}

test_ignores_names_containing_canvas() {
  new_tree
  printf 'let canvasSize = CGSize.zero\nstruct CanvasBox {}\n' > "$TREE/ios/DesignSystem/Controls/Badge.swift"
  run_check
  [ "$CODE" -eq 0 ]
  assert test_ignores_names_containing_canvas $?
}

test_repo_passes() {
  ERR="$(bash "$SCRIPT" 2>&1 >/dev/null)"; CODE=$?
  [ "$CODE" -eq 0 ]
  assert test_repo_passes $?
}

test_blocks_canvas_without_note
test_blocks_canvas_initialiser_form
test_passes_canvas_with_note
test_crayon_surface_and_tests_are_exempt
test_ignores_names_containing_canvas
test_repo_passes

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
