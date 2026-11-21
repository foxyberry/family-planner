#!/bin/bash
# Tests for scripts/check-view-values.sh (views hold no values: no copy lookups, fallbacks or
# placeholder numbers in view code).
set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/check-view-values.sh"
PASS=0
FAIL=0

new_tree() {
  TREE="$(mktemp -d)"
  mkdir -p "$TREE/ios/Features/Home/Tests" "$TREE/ios/DesignSystem/Controls" "$TREE/ios/DesignSystem/Gallery" \
    "$TREE/ios/DebugTools" "$TREE/scripts"
}

run_check() { ERR="$(bash "$SCRIPT" "$TREE" 2>&1 >/dev/null)"; CODE=$?; }

assert() {
  if [ "$2" -eq 0 ]; then PASS=$((PASS + 1)); echo "PASS $1"; else FAIL=$((FAIL + 1)); echo "FAIL $1 (code=$CODE err=$ERR)"; fi
}

test_blocks_copy_lookup_in_a_view() {
  new_tree
  printf 'Text(L10n.tr("day.save"))\n' > "$TREE/ios/Features/Home/AView.swift"
  printf 'Text(store.strings.tr("day.save"))\n' > "$TREE/ios/Features/Home/BView.swift"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"AView.swift:1"* ]] && [[ "$ERR" == *"BView.swift:1"* ]]
  assert test_blocks_copy_lookup_in_a_view $?
}

test_blocks_fallbacks_and_placeholders() {
  new_tree
  printf 'KidNowNext(now: now ?? "actPlay")\n' > "$TREE/ios/Features/Home/AView.swift"
  printf 'timeLeft(minutes: store.minutes ?? 0)\n' > "$TREE/ios/Features/Home/BView.swift"
  printf 'time(store.dropOff, placeholder: 450)\n' > "$TREE/ios/Features/Home/CView.swift"
  printf 'Text(store.label ?? "")\n' > "$TREE/ios/Features/Home/DView.swift"
  printf 'let slots = firstDay?.slots ?? []\n' > "$TREE/ios/Features/Home/EView.swift"
  printf 'KitIcon(KitSlot(rawValue: name) ?? .actPlay)\n' > "$TREE/ios/Features/Home/FView.swift"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"AView.swift"* ]] && [[ "$ERR" == *"BView.swift"* ]] \
    && [[ "$ERR" == *"CView.swift"* ]] && [[ "$ERR" == *"DView.swift"* ]] \
    && [[ "$ERR" == *"EView.swift"* ]] && [[ "$ERR" == *"FView.swift"* ]]
  assert test_blocks_fallbacks_and_placeholders $?
}

test_finds_views_outside_view_files() {
  new_tree
  printf 'struct Row: View {\n    var body: some View { Text(L10n.tr("a.b")) }\n}\n' > "$TREE/ios/Features/Home/Rows.swift"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"Rows.swift:2"* ]]
  assert test_finds_views_outside_view_files $?
}

test_blocks_state_ternaries_in_screens() {
  new_tree
  printf 'Row().padding(.bottom, store.thenCaption == nil ? -inset : 0)\n' > "$TREE/ios/Features/Home/AView.swift"
  printf 'Button("x").opacity(store.canUndo ? 1 : 0.45)\n' > "$TREE/ios/Features/Home/BView.swift"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"AView.swift:1"* ]] && [[ "$ERR" == *"BView.swift:1"* ]]
  assert test_blocks_state_ternaries_in_screens $?
}

test_parts_may_branch_on_their_own_options() {
  new_tree
  mkdir -p "$TREE/ios/DesignSystem/Content"
  printf 'HStack(spacing: width == nil ? Spacing.m : 0) {}\n' > "$TREE/ios/DesignSystem/Content/Row.swift"
  printf 'Text(store.title).foregroundStyle(store.item?.tint)\n' > "$TREE/ios/Features/Home/HomeView.swift"
  run_check
  [ "$CODE" -eq 0 ]
  assert test_parts_may_branch_on_their_own_options $?
}

test_state_and_models_may_look_copy_up() {
  new_tree
  printf 'extension HomeFeature.State {\n    var title: String { strings.tr("home.title") }\n    var n: Int { x ?? 0 }\n}\n' \
    > "$TREE/ios/Features/Home/HomeCopy.swift"
  run_check
  [ "$CODE" -eq 0 ]
  assert test_state_and_models_may_look_copy_up $?
}

test_parts_get_every_rule_layout_the_copy_rule() {
  new_tree
  mkdir -p "$TREE/ios/DesignSystem/Layout"
  printf 'let width = labels.max() ?? 0\n' > "$TREE/ios/DesignSystem/Layout/FormLayout.swift"
  run_check
  [ "$CODE" -eq 0 ] || { assert test_parts_get_every_rule_layout_the_copy_rule 1; return; }
  printf '.frame(width: width ?? 200)\n' > "$TREE/ios/DesignSystem/Controls/Field.swift"
  printf '.accessibilityLabel(L10n.tr("check.done"))\n' > "$TREE/ios/DesignSystem/Controls/Check.swift"
  printf 'Text(L10n.tr("a.b"))\n' > "$TREE/ios/DesignSystem/Layout/Grid.swift"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"Field.swift:1"* ]] && [[ "$ERR" == *"Check.swift:1"* ]] && [[ "$ERR" == *"Grid.swift:1"* ]]
  assert test_parts_get_every_rule_layout_the_copy_rule $?
}

test_exempt_places_and_comments() {
  new_tree
  printf 'Text(L10n.tr("a.b"))\n' > "$TREE/ios/DesignSystem/Gallery/ComponentGallery.swift"
  printf 'Text(L10n.tr("a.b"))\n' > "$TREE/ios/DebugTools/DebugView.swift"
  printf 'Text(L10n.tr("a.b"))\n' > "$TREE/ios/Features/Home/Tests/HomeView.swift"
  printf '// was Text(L10n.tr("a.b")) ?? 0\nText(store.title)\n' > "$TREE/ios/Features/Home/HomeView.swift"
  run_check
  [ "$CODE" -eq 0 ]
  assert test_exempt_places_and_comments $?
}

test_pending_file_is_allowed() {
  new_tree
  printf 'Text(L10n.tr("a.b"))\n' > "$TREE/ios/Features/Home/HomeView.swift"
  printf '# header\nios/Features/Home/HomeView.swift\n' > "$TREE/scripts/view-values-pending.txt"
  run_check
  [ "$CODE" -eq 0 ]
  assert test_pending_file_is_allowed $?
}

test_pending_only_shrinks() {
  new_tree
  printf 'Text(store.title)\n' > "$TREE/ios/Features/Home/HomeView.swift"
  printf 'ios/Features/Home/HomeView.swift\nios/Features/Home/GoneView.swift\n' > "$TREE/scripts/view-values-pending.txt"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"clean file: ios/Features/Home/HomeView.swift"* ]] \
    && [[ "$ERR" == *"missing file: ios/Features/Home/GoneView.swift"* ]]
  assert test_pending_only_shrinks $?
}

test_blocks_copy_lookup_in_a_view
test_blocks_fallbacks_and_placeholders
test_finds_views_outside_view_files
test_blocks_state_ternaries_in_screens
test_parts_may_branch_on_their_own_options
test_state_and_models_may_look_copy_up
test_parts_get_every_rule_layout_the_copy_rule
test_exempt_places_and_comments
test_pending_file_is_allowed
test_pending_only_shrinks

echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
