#!/bin/bash
# Runs only the test targets that a change can affect: the changed files under ios/, their reverse
# dependencies in Bazel (rdeps), kept to ios_unit_test targets outside the snapshot, ui and manual
# tags. Bazel's cache skips what didn't change, so this is `make test` for one change.
#
#   test-affected.sh [BASE [HEAD]]       BASE defaults to the merge base with origin/develop;
#                                        without HEAD the working tree counts (uncommitted too)
#   test-affected.sh --print …           list the targets, run nothing
#   test-affected.sh --skip-if-busy …    (pre-push) say "tests needed in the PR" and exit 0 instead
#                                        of testing when another Bazel command runs (8 GB Mac), a
#                                        dev simulator is booted (make test-one would shut it down
#                                        under the user's app), the pushed commit isn't checked out
#                                        here, or ios/ has uncommitted changes (Bazel tests those)
# A change to MODULE.bazel, Package.*, ios/BUILD.bazel or a .bzl file runs every test target.
set -u
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
PRINT=0 SKIP_IF_BUSY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --print) PRINT=1 ;;
    --skip-if-busy) SKIP_IF_BUSY=1 ;;
    *) break ;;
  esac
  shift
done
BASE="${1:-$(git merge-base origin/develop HEAD 2>/dev/null)}"
HEAD_REV="${2:-}"
BAZEL=(bazel --bazelrc=.bazelrc --bazelrc=ios/.bazelrc)

later() { echo "test-affected: $1. Tests needed in the PR: run 'make test-affected' when Bazel is free." >&2; exit 0; }

[ -n "$BASE" ] || { echo "test-affected: no base (fetch origin/develop, or pass BASE)" >&2; exit 2; }
if [ -n "$HEAD_REV" ]; then
  if [ "$PRINT" = 0 ] && [ "$(git rev-parse "$HEAD_REV^{commit}")" != "$(git rev-parse HEAD)" ]; then
    [ "$SKIP_IF_BUSY" = 1 ] && later "$HEAD_REV is not the checked-out commit"
    echo "test-affected: check out $HEAD_REV first (Bazel tests the working tree)" >&2; exit 2
  fi
  changed="$(git diff --name-only "$BASE" "$HEAD_REV")"
  if [ "$SKIP_IF_BUSY" = 1 ] && [ -n "$(git status --porcelain -- ios/)" ]; then
    later "ios/ has uncommitted changes, and Bazel would test those instead of $HEAD_REV"
  fi
else
  # The working tree: committed and uncommitted changes, and new files not added yet.
  changed="$(git diff --name-only "$BASE"; git ls-files --others --exclude-standard)"
fi

if printf '%s\n' "$changed" | grep -Eq '^(MODULE\.bazel|Package\.(swift|resolved)|ios/BUILD\.bazel)$|\.bzl$'; then
  query='kind("ios_unit_test", //ios/...)'
else
  # A BUILD file, or a deleted file, stands for every rule of its package (the nearest folder
  # with a BUILD file); other files are source labels.
  labels=()
  while IFS= read -r f; do
    if [ -f "$f" ] && [[ "$f" != */BUILD.bazel && "$f" != */BUILD ]]; then
      labels+=("$f")
      continue
    fi
    dir="${f%/*}"
    while [ "$dir" != "ios" ] && [ ! -f "$dir/BUILD.bazel" ] && [ ! -f "$dir/BUILD" ]; do dir="${dir%/*}"; done
    [ "$dir" != "ios" ] && labels+=("//$dir:all")
  done < <(printf '%s\n' "$changed" | grep -E '^ios/.' | grep -vE '/__Snapshots__/' | sort -u)
  [ "${#labels[@]}" -gt 0 ] || { echo "test-affected: no change under ios/, nothing to test"; exit 0; }
  labels=($(printf '%s\n' "${labels[@]}" | sort -u))
  query="kind(\"ios_unit_test\", rdeps(//ios/..., set(${labels[*]})))"
fi
query="$query except attr(\"tags\", \"snapshot|ui|manual\", //ios/...)"

# 8 GB Mac: never start a second Bazel command, here or in another repository, and never shut
# down a simulator someone is using (make test-one stops every booted non-test simulator).
if [ "$SKIP_IF_BUSY" = 1 ]; then
  if pgrep -f "bazel(isk)? .*(build|test|run|query|coverage)" >/dev/null 2>&1; then
    later "another Bazel command is running"
  fi
  dev_sims="$(xcrun simctl list devices booted -j 2>/dev/null | python3 -c 'import json, sys
try:
    devs = json.load(sys.stdin).get("devices", {})
except ValueError:
    devs = {}
print(", ".join(d["name"] for ds in devs.values() for d in ds if not d["name"].startswith("BAZEL_TEST_")))' 2>/dev/null)"
  [ -n "$dev_sims" ] && later "a dev simulator is in use ($dev_sims)"
fi

targets="$("${BAZEL[@]}" query --keep_going --noshow_progress "$query" 2>/dev/null | sort)"
if [ -z "$targets" ]; then
  echo "test-affected: no test target depends on the change"
  exit 0
fi
echo "test-affected: $(printf '%s\n' "$targets" | wc -l | tr -d ' ') target(s):"
printf '  %s\n' $targets
[ "$PRINT" = 1 ] && exit 0
start=$SECONDS
make test-one TARGET="$(printf '%s ' $targets)"
code=$?
echo "test-affected: finished in $((SECONDS - start)) s"
exit "$code"
