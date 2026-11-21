#!/bin/bash
# Stops a local build or test before it starts when the data volume is nearly full. A Bazel run that
# hits ENOSPC halfway leaves a broken output tree and cannot push (lessons 2026-11-21: twice in one
# day; the shared disk cache passes its cap between collections, and each worktree adds a 3-5 GB
# output base).
#
# Usage: bash scripts/check-disk.sh [min-gb]
#   min-gb: free space needed, default FP_MIN_FREE_GB or 5. FP_DISK_PATH picks the volume (default
#   $HOME). CI skips the check.
set -euo pipefail

[[ -n "${CI:-}" ]] && exit 0

min="${1:-${FP_MIN_FREE_GB:-5}}"
path="${FP_DISK_PATH:-$HOME}"
free_kb=$(df -Pk "$path" | awk 'NR == 2 { print $4 }')
free_gb=$(( free_kb / 1024 / 1024 ))

if (( free_gb < min )); then
  echo "check-disk: only ${free_gb} GB free on ${path} (a build needs ${min})." >&2
  echo "  First check that no Bazel build is running (it writes to the cache). Then free space:" >&2
  echo "  the shared Bazel disk cache's cas and ac folders under ~/.cache/bazel-disk can be deleted" >&2
  echo "  (a cache; builds refill it), and worktrees whose work is merged can run bazel clean." >&2
  exit 1
fi
