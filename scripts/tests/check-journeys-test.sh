#!/bin/bash
# Tests for scripts/check-journeys.sh (every reducer is reached by a journey).
set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/check-journeys.sh"
PASS=0
FAIL=0

new_tree() {
  TREE="$(mktemp -d)"
  mkdir -p "$TREE/ios/AppCore" "$TREE/ios/Features/Home/Tests" "$TREE/ios/Features/Grownup" \
    "$TREE/ios/Journeys/Tests" "$TREE/scripts"
  printf '@Reducer\npublic struct AppFeature {\n    @Reducer\n    public enum Path {\n        case changeBuses(ChangeBusesFeature)\n    }\n}\n' \
    > "$TREE/ios/AppCore/AppFeature.swift"
  printf '@Reducer\npublic struct HomeFeature {}\n' > "$TREE/ios/Features/Home/HomeFeature.swift"
  printf '@Reducer public struct ChangeBusesFeature {}\n' > "$TREE/ios/Features/Grownup/ChangeBusesFeature.swift"
}

run_check() { ERR="$(bash "$SCRIPT" "$TREE" 2>&1 >/dev/null)"; CODE=$?; }

assert() {
  if [ "$2" -eq 0 ]; then PASS=$((PASS + 1)); echo "PASS $1"; else FAIL=$((FAIL + 1)); echo "FAIL $1 (code=$CODE err=$ERR)"; fi
}

journey() { printf '%s\n' "$@" > "$TREE/ios/Journeys/Tests/AJourneys.swift"; }

test_passes_when_type_or_case_is_named() {
  new_tree
  journey 'let store = TestStoreOf<AppFeature>()' 'await store.send(.home(.task))' \
    'await store.receive(\.path[id: id].changeBuses.loaded)'
  run_check
  [ "$CODE" -eq 0 ]
  assert test_passes_when_type_or_case_is_named $?
}

test_blocks_a_reducer_no_journey_reaches() {
  new_tree
  journey 'let store = TestStoreOf<AppFeature>()' 'await store.send(.home(.task))'
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"no journey reaches ChangeBusesFeature"* ]] && [[ "$ERR" != *"HomeFeature"* ]]
  assert test_blocks_a_reducer_no_journey_reaches $?
}

test_comments_and_longer_names_do_not_count() {
  new_tree
  journey 'let store = TestStoreOf<AppFeature>()' '// await store.send(.home(.task))' \
    'await store.send(.homeTapped)' 'let s = ChangeBusesFeatureX()'
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"HomeFeature"* ]] && [[ "$ERR" == *"ChangeBusesFeature"* ]]
  assert test_comments_and_longer_names_do_not_count $?
}

test_property_reads_do_not_count() {
  new_tree
  journey 'let store = TestStoreOf<AppFeature>()' 'XCTAssertEqual(store.state.home.weekday, .tuesday)' \
    'let plan = world.changeBuses.value'
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"HomeFeature"* ]] && [[ "$ERR" == *"ChangeBusesFeature"* ]]
  assert test_property_reads_do_not_count $?
}

test_key_paths_count() {
  new_tree
  journey 'TestStoreOf<AppFeature>' 'await store.receive(\.home.loaded)' \
    'await store.receive(\.path[id: id].changeBuses.delegate.saved)'
  run_check
  [ "$CODE" -eq 0 ]
  assert test_key_paths_count $?
}

test_pending_list_only_shrinks() {
  new_tree
  journey 'let store = TestStoreOf<AppFeature>()' 'await store.send(.home(.task))'
  printf '# not yet\nChangeBusesFeature\n' > "$TREE/scripts/journeys-pending.txt"
  run_check
  [ "$CODE" -eq 0 ] || { assert test_pending_list_only_shrinks 1; return; }
  printf 'HomeFeature\nChangeBusesFeature\n' > "$TREE/scripts/journeys-pending.txt"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"reducer a journey reaches: HomeFeature"* ]]
  assert test_pending_list_only_shrinks $?
}

test_blocks_a_pending_line_for_a_missing_reducer() {
  new_tree
  journey 'TestStoreOf<AppFeature>' '.home(.task)' '.changeBuses(.task)'
  printf 'GoneFeature\n' > "$TREE/scripts/journeys-pending.txt"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"missing reducer: GoneFeature"* ]]
  assert test_blocks_a_pending_line_for_a_missing_reducer $?
}

test_subfolders_are_not_journeys() {
  new_tree
  journey 'TestStoreOf<AppFeature>' '.home(.task)'
  mkdir -p "$TREE/ios/Journeys/Tests/Screens"
  printf 'await store.send(.changeBuses(.task))\n' > "$TREE/ios/Journeys/Tests/Screens/ScreenSnapshotTests.swift"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"no journey reaches ChangeBusesFeature"* ]]
  assert test_subfolders_are_not_journeys $?
}

test_ignores_test_reducers() {
  new_tree
  journey 'TestStoreOf<AppFeature>' '.home(.task)' '.changeBuses(.task)'
  printf '@Reducer\nstruct FakeFeature {}\n' > "$TREE/ios/Features/Home/Tests/FakeFeature.swift"
  run_check
  [ "$CODE" -eq 0 ]
  assert test_ignores_test_reducers $?
}

test_passes_when_type_or_case_is_named
test_blocks_a_reducer_no_journey_reaches
test_comments_and_longer_names_do_not_count
test_property_reads_do_not_count
test_key_paths_count
test_pending_list_only_shrinks
test_blocks_a_pending_line_for_a_missing_reducer
test_subfolders_are_not_journeys
test_ignores_test_reducers

echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
