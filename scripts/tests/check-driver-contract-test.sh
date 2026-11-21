#!/bin/bash
# Tests for scripts/check-driver-contract.sh (the driver contract's names exist, and journey files
# use only the contract).
set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/check-driver-contract.sh"
PASS=0
FAIL=0

new_tree() {
  TREE="$(mktemp -d)"
  mkdir -p "$TREE/ios/AppCore" "$TREE/ios/Features/Home" "$TREE/ios/Journeys/Tests/Driver/journeys"
  printf 'public var relockCaption: String?\n' > "$TREE/ios/AppCore/AppFeature.swift"
  printf 'public var days: [KidDay] = []\npublic var weekday: Weekday?\npublic var name = ""\ncase clockHoldCompleted\ncase binding(BindingAction<State>)\n' \
    > "$TREE/ios/Features/Home/HomeFeature.swift"
  printf 'func testAHold() async {}\n' > "$TREE/ios/Journeys/Tests/LockJourneys.swift"
  cat > "$TREE/ios/Journeys/Tests/Driver/contract.json" <<'JSON'
{ "app": { "ios": { "file": "ios/AppCore/AppFeature.swift" },
           "fields": [ { "name": "relockCaption", "ios": "relockCaption" } ] },
  "screens": [ { "id": "home", "ios": { "file": "ios/Features/Home/HomeFeature.swift" },
                 "fields": [ { "name": "kids", "ios": "days" },
                             { "name": "weekday", "values": ["monday", "tuesday"], "ios": "weekday" } ],
                 "actions": [ { "name": "clockHeld", "args": {}, "ios": "clockHoldCompleted" },
                              { "name": "nameChanged", "args": { "text": "string" }, "ios": "binding:name" } ] },
               { "id": "settings", "ios": { "file": "ios/Features/Home/HomeFeature.swift" },
                 "fields": [ { "name": "family", "ios": "name" } ], "actions": [] } ] }
JSON
  journey '{ "do": "home.clockHeld" }' '{ "expect": { "screen": "home", "kids": ["Kid A"] } }'
}

journey() {
  local steps
  steps="$(printf '%s,' "$@")"
  printf '{ "same as": "LockJourneys.testAHold (walks there)", "steps": [ %s ] }\n' "${steps%,}" \
    > "$TREE/ios/Journeys/Tests/Driver/journeys/a.json"
}

run_check() { ERR="$(bash "$SCRIPT" "$TREE" 2>&1 >/dev/null)"; CODE=$?; }

assert() {
  if [ "$2" -eq 0 ]; then PASS=$((PASS + 1)); echo "PASS $1"; else FAIL=$((FAIL + 1)); echo "FAIL $1 (code=$CODE err=$ERR)"; fi
}

test_passes_on_a_true_contract() {
  new_tree
  run_check
  [ "$CODE" -eq 0 ]
  assert test_passes_on_a_true_contract $?
}

test_blocks_a_renamed_action_or_field() {
  new_tree
  printf 'public var dayList: [KidDay] = []\npublic var weekday: Weekday?\npublic var name = ""\ncase holdDone\ncase binding(BindingAction<State>)\n' \
    > "$TREE/ios/Features/Home/HomeFeature.swift"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"home.kids: no var or let days"* ]] && [[ "$ERR" == *"home.clockHeld: no case clockHoldCompleted"* ]]
  assert test_blocks_a_renamed_action_or_field $?
}

test_blocks_a_journey_outside_the_contract() {
  new_tree
  journey '{ "do": "home.pencilTapped" }' '{ "do": "home.clockHeld", "args": { "for": 2 } }' \
    '{ "expect": { "weather": "sunny" } }' '{ "expect": { "screen": "garden" } }' '{ "wait": 1 }'
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"step 1: home.pencilTapped is not in the contract"* ]] \
    && [[ "$ERR" == *"step 2: home.clockHeld takes []"* ]] && [[ "$ERR" == *"step 3: weather is expected before any screen is"* ]] \
    && [[ "$ERR" == *"step 4: screen garden is not in the contract"* ]] && [[ "$ERR" == *"step 5: neither do nor expect"* ]]
  assert test_blocks_a_journey_outside_the_contract $?
}

test_checks_a_binding_field() {
  new_tree
  sed -i '' 's/public var name = ""//' "$TREE/ios/Features/Home/HomeFeature.swift"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"home.nameChanged: no var or let name"* ]]
  assert test_checks_a_binding_field $?
}

test_checks_expect_against_the_current_screen() {
  new_tree
  journey '{ "expect": { "kids": [] } }' '{ "expect": { "screen": "home", "family": "x" } }' \
    '{ "expect": { "weekday": "friday" } }' '{ "expect": { "screen": "settings", "family": "x", "relockCaption": null } }'
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"step 1: kids is expected before any screen is"* ]] \
    && [[ "$ERR" == *"step 2: family is not a field of home"* ]] && [[ "$ERR" == *"step 3: home.weekday has no value friday"* ]] \
    && [[ "$ERR" != *"step 4"* ]]
  assert test_checks_expect_against_the_current_screen $?
}

test_checks_the_swift_journey_exists() {
  new_tree
  printf 'func testSomethingElse() async {}\n' > "$TREE/ios/Journeys/Tests/LockJourneys.swift"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"same as LockJourneys.testAHold: no such journey test"* ]]
  assert test_checks_the_swift_journey_exists $?
}

test_ignores_comment_lines() {
  new_tree
  printf '// case clockHoldCompleted was here\npublic var days: [KidDay] = []\npublic var weekday: Weekday?\npublic var name = ""\ncase binding(BindingAction<State>)\n' \
    > "$TREE/ios/Features/Home/HomeFeature.swift"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"no case clockHoldCompleted"* ]]
  assert test_ignores_comment_lines $?
}

test_passes_on_a_true_contract
test_blocks_a_renamed_action_or_field
test_blocks_a_journey_outside_the_contract
test_checks_a_binding_field
test_checks_the_swift_journey_exists
test_checks_expect_against_the_current_screen
test_ignores_comment_lines

echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
