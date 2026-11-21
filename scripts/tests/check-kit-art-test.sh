#!/bin/bash
# Tests for scripts/check-kit-art.sh (every kit picture is used; every asset is a picture or a rig frame).
set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/check-kit-art.sh"
PASS=0
FAIL=0

new_tree() {
  TREE="$(mktemp -d)"
  local catalog="$TREE/ios/KitArt/Resources/KitArt.xcassets"
  mkdir -p "$catalog/sun.imageset" "$catalog/teddy.imageset" "$catalog/rig-teddy-0.imageset" \
    "$catalog/KitRigs.dataset" "$TREE/ios/Features/Home/Tests" "$TREE/ios/DesignSystem/Gallery" "$TREE/scripts"
  printf 'public enum KitSlot: String {\n    case sun, teddy\n}\n' > "$TREE/ios/KitArt/KitSlot.swift"
  printf 'var isThing: Bool { switch self { case .sun, .teddy: true } }\n' > "$TREE/ios/KitArt/KitSlot+Things.swift"
  printf '{"teddy": [{"image": "rig-teddy-0"}]}\n' > "$catalog/KitRigs.dataset/rigs.json"
  printf 'KitIcon(.sun)\nlet picture = "teddy"\n' > "$TREE/ios/Features/Home/HomeView.swift"
}

run_check() { ERR="$(bash "$SCRIPT" "$TREE" 2>&1 >/dev/null)"; CODE=$?; }

assert() {
  if [ "$2" -eq 0 ]; then PASS=$((PASS + 1)); echo "PASS $1"; else FAIL=$((FAIL + 1)); echo "FAIL $1 (code=$CODE err=$ERR)"; fi
}

test_passes_when_every_picture_is_used() {
  new_tree
  run_check
  [ "$CODE" -eq 0 ]
  assert test_passes_when_every_picture_is_used $?
}

test_blocks_a_picture_only_kitart_tests_or_the_gallery_name() {
  new_tree
  printf 'KitIcon(.sun)\n' > "$TREE/ios/Features/Home/HomeView.swift"
  printf 'KitIcon(.teddy)\n' > "$TREE/ios/Features/Home/Tests/HomeTests.swift"
  printf 'KitIcon(.teddy)\n' > "$TREE/ios/DesignSystem/Gallery/ComponentGallery.swift"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"kit picture nothing uses: teddy"* ]]
  assert test_blocks_a_picture_only_kitart_tests_or_the_gallery_name $?
}

test_blocks_an_orphan_asset() {
  new_tree
  mkdir -p "$TREE/ios/KitArt/Resources/KitArt.xcassets/rig-teddy-1.imageset"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"no picture or rig names: rig-teddy-1.imageset"* ]] && [[ "$ERR" != *"rig-teddy-0"* ]]
  assert test_blocks_an_orphan_asset $?
}

test_pending_list_only_shrinks() {
  new_tree
  printf 'KitIcon(.sun)\n' > "$TREE/ios/Features/Home/HomeView.swift"
  printf '# waiting\nteddy\n' > "$TREE/scripts/kit-art-pending.txt"
  run_check
  [ "$CODE" -eq 0 ] || { assert test_pending_list_only_shrinks 1; return; }
  printf 'sun\nteddy\n' > "$TREE/scripts/kit-art-pending.txt"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"pending line for a used or missing picture: sun"* ]]
  assert test_pending_list_only_shrinks $?
}

test_passes_when_every_picture_is_used
test_blocks_a_picture_only_kitart_tests_or_the_gallery_name
test_blocks_an_orphan_asset
test_pending_list_only_shrinks

echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
