#!/bin/bash
# Tests for scripts/check-strings.sh (user-facing copy only through L10n.tr and the String Catalog).
set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/check-strings.sh"
PASS=0
FAIL=0

# A catalog entry in Xcode's layout: key, English value.
entry() {
  printf '"%s" : { "extractionState" : "manual", "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "%s" } } } }' "$1" "$2"
}

# A tree whose catalog has one key, used once.
new_tree() {
  TREE="$(mktemp -d)"
  mkdir -p "$TREE/ios/Features/Home/Tests" "$TREE/ios/Features/Grownup" "$TREE/ios/DesignSystem/Content" \
    "$TREE/ios/DesignSystem/Gallery" "$TREE/ios/DesignSystem/Fonts" "$TREE/ios/DesignSystem/SnapshotTests" \
    "$TREE/ios/Domain" "$TREE/ios/App" "$TREE/ios/DebugTools" "$TREE/ios/Strings"
  write_catalog "$(entry home.next Next)"
  printf '%s\n' 'Text(L10n.tr("home.next"))' > "$TREE/ios/Features/Home/NextList.swift"
}

write_catalog() { # entries, comma-separated
  printf '{ "sourceLanguage" : "en", "strings" : { %s }, "version" : "1.0" }\n' "$1" > "$TREE/ios/Strings/Localizable.xcstrings"
}

run_check() { ERR="$(bash "$SCRIPT" "$TREE" 2>&1 >/dev/null)"; CODE=$?; }

assert() {
  if [ "$2" -eq 0 ]; then PASS=$((PASS + 1)); echo "PASS $1"; else FAIL=$((FAIL + 1)); echo "FAIL $1 (code=$CODE err=$ERR)"; fi
}

blocks() { # name, file, line, message part
  local name="$1" file="$2" line="$3" message="$4"
  new_tree
  printf '%s\n' "$line" > "$TREE/$file"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"$message"* ]] && [[ "$ERR" == *"$(basename "$file")"* ]]
  assert "$name" $?
}

allows() { # name, file, line
  local name="$1" file="$2" line="$3"
  new_tree
  printf '%s\n' "$line" > "$TREE/$file"
  run_check
  [ "$CODE" -eq 0 ]
  assert "$name" $?
}

blocks test_blocks_text_literal ios/Features/Home/HomeView.swift '    Text("Hello there")' 'hard-coded copy'
blocks test_blocks_copy_in_model ios/Features/Grownup/HubModel.swift 'let about = HubSection(title: "About", rows: [])' 'hard-coded copy'
blocks test_blocks_copy_in_part ios/DesignSystem/Content/NowRow.swift '.accessibilityValue(isDone ? "Done" : "Not done")' 'hard-coded copy'
blocks test_blocks_copy_in_domain ios/Domain/Formatting.swift 'if days == Weekday.schoolDays { return "Every school day" }' 'hard-coded copy'
blocks test_blocks_copy_ok_without_reason ios/Features/Home/HomeView.swift 'Text("Hello there") // copy-ok:' 'hard-coded copy'
blocks test_blocks_key_missing_from_catalog ios/Features/Home/HomeView.swift 'Text(L10n.tr("home.missing"))' 'home.missing'

allows test_allows_catalog_key ios/Features/Home/HomeView.swift 'Text(L10n.tr("home.next"))'
allows test_allows_identifiers ios/Features/Home/HomeView.swift 'Image(systemName: "chevron.left"); KitIcon(.actPlay); let id = "actPlay"'
allows test_allows_all_capitals ios/Features/Home/HomeView.swift 'let tag = "NOW"'
allows test_allows_comments ios/Features/Home/HomeView.swift '    /// "Grown-ups only" on the right.'
allows test_allows_copy_ok ios/Features/Home/HomeView.swift 'let bundle = named("KitArtResources") // copy-ok: bundle name'
allows test_allows_app ios/App/AppDelegate.swift 'let title = "Family Planner"'
allows test_allows_debug_tools ios/DebugTools/DebugMenu.swift 'Text("Time machine")'
allows test_allows_gallery ios/DesignSystem/Gallery/ComponentGallery.swift 'Text("Buttons")'
allows test_allows_fonts ios/DesignSystem/Fonts/FontRegistrar.swift 'static let familyName = "Playpen Sans"'
allows test_allows_tests ios/Features/Home/Tests/HomeTests.swift 'XCTAssertEqual(title, "Free time")'
allows test_allows_snapshot_tests ios/DesignSystem/SnapshotTests/PartTests.swift 'Text("Swimming")'
allows test_allows_seed_data ios/Domain/SeedData.swift 'let kid = Kid(name: "Kid A")'

test_blocks_unused_catalog_key() {
  new_tree
  write_catalog "$(entry home.next Next), $(entry home.gone Gone)"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"unused catalog key: home.gone"* ]]
  assert test_blocks_unused_catalog_key $?
}

test_blocks_key_without_english_value() {
  new_tree
  write_catalog "$(entry home.next '')"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"no English value: home.next"* ]]
  assert test_blocks_key_without_english_value $?
}

test_allows_tree_without_catalog() {
  new_tree
  rm -r "$TREE/ios/Strings" "$TREE/ios/Features/Home/NextList.swift"
  printf '%s\n' 'let calendar = Calendar.current' > "$TREE/ios/Features/Home/HomeModel.swift"
  run_check
  [ "$CODE" -eq 0 ]
  assert test_allows_tree_without_catalog $?
}

test_blocks_unused_catalog_key
test_blocks_key_without_english_value
test_allows_tree_without_catalog

echo "check-strings: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
