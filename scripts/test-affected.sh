#!/bin/bash
# Runs only the test targets that a change can affect: the changed files under ios/, their reverse
# dependencies in Bazel (rdeps), kept to ios_unit_test targets outside the snapshot, ui and manual
# tags. Bazel's cache skips what didn't change, so this is `make test` for one change.
#
#   test-affected.sh [BASE [HEAD]]       BASE defaults to the merge base with origin/develop;
#                                        without HEAD the working tree counts (uncommitted too)
#   test-affected.sh --print …           list the targets, run nothing
#   test-affected.sh --skip-if-busy …    (pre-push) when another Bazel command is running, or HEAD
#                                        is not checked out here, say "tests needed in the PR" and
#                                        exit 0 instead of waiting (8 GB Mac: one Bazel at a time)
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
else
  # The working tree: committed and uncommitted changes, and new files not added yet.
  changed="$(git diff --name-only "$BASE"; git ls-files --others --exclude-standard)"
fi

if printf '%s\n' "$changed" | grep -Eq '^(MODULE\.bazel|Package\.(swift|resolved)|ios/BUILD\.bazel)$|\.bzl$'; then
  query='kind("ios_unit_test", //ios/...)'
else
  files=()
  while IFS= read -r f; do
    [ -f "$f" ] && files+=("$f")
  done < <(printf '%s\n' "$changed" | grep -E '^ios/' | grep -vE '/__Snapshots__/')
  [ "${#files[@]}" -gt 0 ] || { echo "test-affected: no change under ios/, nothing to test"; exit 0; }
  # A BUILD file stands for every rule of its package; other files are source labels.
  labels=()
  for f in "${files[@]}"; do
    case "$f" in
      */BUILD.bazel|*/BUILD) labels+=("//${f%/*}:all") ;;
      *) labels+=("$f") ;;
    esac
  done
  query="kind(\"ios_unit_test\", rdeps(//ios/..., set(${labels[*]})))"
fi
query="$query except attr(\"tags\", \"snapshot|ui|manual\", //ios/...)"

# 8 GB Mac: never start a second Bazel command, here or in another repository.
if [ "$SKIP_IF_BUSY" = 1 ] && pgrep -f "bazel(isk)? .*(build|test|run|query|coverage)" >/dev/null 2>&1; then
  later "another Bazel command is running"
fi

targets="$("${BAZEL[@]}" query --keep_going --noshow_progress "$query" 2>/dev/null | sort)"
if [ -z "$targets" ]; then
  echo "test-affected: no test target depends on the change"
  exit 0
fi
echo "test-affected: $(printf '%s\n' "$targets" | wc -l | tr -d ' ') target(s):"
printf '  %s\n' $targets
[ "$PRINT" = 1 ] && exit 0
exec make test-one TARGET="$(printf '%s ' $targets)"
