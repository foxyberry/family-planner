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
  printf 'public var days: [KidDay] = []\ncase clockHoldCompleted\n' > "$TREE/ios/Features/Home/HomeFeature.swift"
  cat > "$TREE/ios/Journeys/Tests/Driver/contract.json" <<'JSON'
{ "app": { "ios": { "file": "ios/AppCore/AppFeature.swift" },
           "fields": [ { "name": "relockCaption", "ios": "relockCaption" } ] },
  "screens": [ { "id": "home", "ios": { "file": "ios/Features/Home/HomeFeature.swift" },
                 "fields": [ { "name": "kids", "ios": "days" } ],
                 "actions": [ { "name": "clockHeld", "args": {}, "ios": "clockHoldCompleted" } ] } ] }
JSON
  journey '{ "do": "home.clockHeld" }' '{ "expect": { "screen": "home", "kids": ["Kid A"] } }'
}

journey() {
  local steps
  steps="$(printf '%s,' "$@")"
  printf '{ "steps": [ %s ] }\n' "${steps%,}" > "$TREE/ios/Journeys/Tests/Driver/journeys/a.json"
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
  printf 'public var dayList: [KidDay] = []\ncase holdDone\n' > "$TREE/ios/Features/Home/HomeFeature.swift"
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
    && [[ "$ERR" == *"step 2: home.clockHeld takes []"* ]] && [[ "$ERR" == *"step 3: weather is not a contract field"* ]] \
    && [[ "$ERR" == *"step 4: screen garden is not in the contract"* ]] && [[ "$ERR" == *"step 5: neither do nor expect"* ]]
  assert test_blocks_a_journey_outside_the_contract $?
}

test_ignores_comment_lines() {
  new_tree
  printf '// case clockHoldCompleted was here\npublic var days: [KidDay] = []\n' > "$TREE/ios/Features/Home/HomeFeature.swift"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"no case clockHoldCompleted"* ]]
  assert test_ignores_comment_lines $?
}

test_passes_on_a_true_contract
test_blocks_a_renamed_action_or_field
test_blocks_a_journey_outside_the_contract
test_ignores_comment_lines

echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
