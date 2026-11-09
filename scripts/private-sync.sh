#!/bin/bash
# `make private`: copy the school and preschool data from the sibling private repo
# (foxyberry/family-planner-private, checked out at ../family-planner-private; cloned with gh
# when missing) into the git-ignored ios/Clients/SchoolDirectoryLive/Private/.
#
# Private means "not in git", never "left out of the build": every installable build bundles
# these files, and the Bazel check in ios/Clients/SchoolDirectoryLive fails the build with
# "School data missing: run make private" when one is absent. Only CI and public clones build
# without them, on purpose, with --config=public (make ... PUBLIC_BUILD=1).
#
# Only data files are copied (REQUIRED below). The private repo holds no family information.
# Without the private repo (no access, offline) this script prints a notice and exits 0, so
# `make setup` works on a public clone; the build itself then fails unless PUBLIC_BUILD=1.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# In a linked worktree, the sibling folder sits next to the main checkout.
COMMON_DIR="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || echo "$ROOT/.git")"
MAIN="$(dirname "$COMMON_DIR")"
PRIVATE_DIR="${PRIVATE_DIR:-$(dirname "$MAIN")/family-planner-private}"
PRIVATE_REPO="${PRIVATE_REPO:-foxyberry/family-planner-private}"
DEST="$ROOT/ios/Clients/SchoolDirectoryLive/Private"
REQUIRED=(international-schools-sg.json preschools-sg.json preschool-calendar-rules.json)

skip() {
  echo "private: $1. Skipping." >&2
  echo "  App builds need this data and will stop with \"School data missing\"; CI and public clones: PUBLIC_BUILD=1." >&2
  exit 0
}

if [ ! -d "$PRIVATE_DIR/.git" ]; then
  command -v gh >/dev/null 2>&1 || skip "$PRIVATE_DIR not found and gh is not installed"
  gh auth status >/dev/null 2>&1 || skip "$PRIVATE_DIR not found and gh is not logged in"
  echo "private: cloning $PRIVATE_REPO into $PRIVATE_DIR"
  gh repo clone "$PRIVATE_REPO" "$PRIVATE_DIR" -- --quiet 2>/dev/null || skip "no access to $PRIVATE_REPO"
else
  git -C "$PRIVATE_DIR" pull --ff-only --quiet 2>/dev/null || echo "private: could not update $PRIVATE_DIR (offline or local commits); using it as it is"
fi

SRC="$PRIVATE_DIR/data/school-data"
[ -f "$SRC/validate.py" ] || skip "$SRC has no school data"
python3 -I "$SRC/validate.py" >/dev/null || { echo "private: $SRC does not validate; nothing copied" >&2; exit 1; }
missing=()
for f in "${REQUIRED[@]}"; do [ -f "$SRC/$f" ] || missing+=("$f"); done
[ ${#missing[@]} -eq 0 ] || { echo "private: $SRC lacks ${missing[*]}; nothing copied" >&2; exit 1; }
mkdir -p "$DEST"
copied=0
for f in "${REQUIRED[@]}"; do
  if ! cmp -s "$SRC/$f" "$DEST/$f"; then cp "$SRC/$f" "$DEST/$f"; copied=$((copied + 1)); fi
done
echo "private: $copied of ${#REQUIRED[@]} data file(s) updated from $(git -C "$PRIVATE_DIR" rev-parse --short HEAD 2>/dev/null || echo "$PRIVATE_DIR") -> ${DEST#"$ROOT"/}"
