#!/bin/bash
# Tests for scripts/check-dependencies.sh (outside data comes through dependencies, never from globals).
set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/check-dependencies.sh"
PASS=0
FAIL=0

new_tree() {
  TREE="$(mktemp -d)"
  mkdir -p "$TREE/ios/Features/Home" "$TREE/ios/Clients/ClockLive" "$TREE/ios/App" "$TREE/ios/DebugTools" \
    "$TREE/ios/Features/Home/Tests" "$TREE/ios/Domain"
}

run_check() { ERR="$(bash "$SCRIPT" "$TREE" 2>&1 >/dev/null)"; CODE=$?; }

assert() {
  if [ "$2" -eq 0 ]; then PASS=$((PASS + 1)); echo "PASS $1"; else FAIL=$((FAIL + 1)); echo "FAIL $1 (code=$CODE err=$ERR)"; fi
}

blocks() {
  local name="$1" file="$2" line="$3"
  new_tree
  printf '%s\n' "$line" > "$TREE/$file"
  run_check
  [ "$CODE" -eq 1 ] && [[ "$ERR" == *"$(basename "$file")"* ]]
  assert "$name" $?
}

allows() {
  local name="$1" file="$2" line="$3"
  new_tree
  printf '%s\n' "$line" > "$TREE/$file"
  run_check
  [ "$CODE" -eq 0 ]
  assert "$name" $?
}

blocks test_blocks_device_calendar_in_feature ios/Features/Home/HomeModel.swift 'let c = Calendar.current'
blocks test_blocks_device_time_zone ios/Domain/Day.swift 'let z = TimeZone.current'
blocks test_blocks_date_now ios/Features/Home/HomeFeature.swift 'let now = Date()'
blocks test_blocks_date_dot_now ios/Features/Home/HomeFeature.swift 'let now = Date.now'
blocks test_blocks_locale ios/Features/Home/HomeFeature.swift 'let l = Locale.current'
blocks test_blocks_device_info ios/Features/Home/HomeFeature.swift 'let d = UIDevice.current.model'
blocks test_blocks_main_bundle ios/Features/Home/HomeFeature.swift 'let b = Bundle.main'
blocks test_blocks_user_defaults ios/Features/Home/HomeFeature.swift 'UserDefaults.standard.set(1, forKey: "k")'
blocks test_blocks_process_info ios/Features/Home/HomeFeature.swift 'let a = ProcessInfo.processInfo.arguments'
blocks test_blocks_dependency_in_view ios/Features/Home/HomeView.swift '    @Dependency(\.calendar) private var calendar'
blocks test_blocks_dependency_in_view_type ios/Features/Home/Panel.swift 'struct Panel: View { @Dependency(\.date) var date }'

allows test_allows_dependency_in_reducer ios/Features/Home/HomeFeature.swift '    @Dependency(\.calendar) var calendar'
allows test_allows_live_module ios/Clients/ClockLive/ClockLive.swift 'let now = Date()'
allows test_allows_app_bootstrap ios/App/FamilyPlannerApp.swift 'let args = ProcessInfo.processInfo.arguments'
allows test_allows_debug_tools ios/DebugTools/DebugMenu.swift 'let id = Bundle.main.bundleIdentifier'
allows test_allows_tests ios/Features/Home/Tests/HomeTests.swift 'let c = Calendar.current'
allows test_allows_comments ios/Features/Home/HomeModel.swift '/// Never use `Calendar.current` here.'
allows test_allows_fixed_dates ios/Domain/Day.swift 'let d = Date(timeIntervalSince1970: 0)'

echo "check-dependencies: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
