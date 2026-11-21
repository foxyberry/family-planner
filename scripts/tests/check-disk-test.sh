#!/bin/bash
# Tests for scripts/check-disk.sh: it passes with room to spare, stops with a hint when the volume is
# nearly full, and never runs on CI.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/../check-disk.sh"
fail=0

env -u CI bash "$CHECK" 0 >/dev/null 2>&1 || { echo "FAIL: room to spare should pass"; fail=1; }

out=$(env -u CI bash "$CHECK" 1000000 2>&1); code=$?
[[ "$code" == 1 ]] || { echo "FAIL: nearly full should stop (exit $code)"; fail=1; }
[[ "$out" == *"bazel-disk"* ]] || { echo "FAIL: the stop names the disk cache to clear: $out"; fail=1; }

env CI=1 bash "$CHECK" 1000000 >/dev/null 2>&1 || { echo "FAIL: CI skips the check"; fail=1; }

if (( fail )); then exit 1; fi
echo "check-disk-test: ok"
