#!/bin/bash
# Blocks private terms (home stops, school names, children's names) from reaching this public repo.
# Terms live in the git-ignored .private-terms file: one per line, case-insensitive substring match.
#
# Usage:
#   check-private-terms.sh --staged          check lines added in the staged diff (pre-commit)
#   check-private-terms.sh --stdin <label>   check text on stdin (commit messages, Claude hooks)
#   check-private-terms.sh <file>...         check whole files
# Exit code: 0 = clean, 1 = a private term was found, or .private-terms is missing or empty.
set -u

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TERMS_FILE="$ROOT/.private-terms"
# A linked git worktree has no git-ignored files of its own; fall back to the main checkout's list.
if [ ! -f "$TERMS_FILE" ]; then
  COMMON_DIR="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  if [ -n "$COMMON_DIR" ] && [ -f "$(dirname "$COMMON_DIR")/.private-terms" ]; then
    TERMS_FILE="$(dirname "$COMMON_DIR")/.private-terms"
  fi
fi

# Fail closed: a missing list must not silently let private words through.
if [ ! -f "$TERMS_FILE" ]; then
  echo "error: .private-terms not found. Create it from .private-terms.example (make setup does this)." >&2
  exit 1
fi

# Fail closed on a list with no active terms too (for example, a fresh copy of the example).
if ! grep -Evq '^[[:space:]]*(#|$)' "$TERMS_FILE"; then
  echo "error: .private-terms has no terms. Add your real private words (one per line)." >&2
  exit 1
fi

found=0

# check_text <label>: reads text on stdin, reports every term it contains.
check_text() {
  local label="$1" text term
  text="$(cat)"
  [ -z "$text" ] && return
  while IFS= read -r term || [ -n "$term" ]; do
    case "$term" in ''|\#*) continue ;; esac
    if printf '%s\n' "$text" | grep -qiF -- "$term"; then
      echo "private term found: $term in $label" >&2
      found=1
    fi
  done < "$TERMS_FILE"
}

if [ "${1:-}" = "--stdin" ]; then
  check_text "${2:-stdin}"
elif [ "${1:-}" = "--staged" ]; then
  # NUL-separated, unquoted paths so names with spaces, quotes or non-ASCII characters
  # reach the per-file diff exactly as staged.
  # --no-renames: a moved-and-edited file must show up as a plain add, not be skipped as "R".
  # Filter ACMRT: added, copied, modified, renamed, type-changed (symlink <-> file).
  while IFS= read -r -d '' file; do
    # File and folder names are published too.
    check_text "file name: $file" < <(printf '%s\n' "$file")
    # Keep only added lines that come after the first hunk header, minus their leading "+".
    # (Filtering on "^+++" would also drop real content lines that start with "++".)
    # Process substitution (not a pipe) so check_text runs in this shell and can set $found.
    check_text "$file" < <(git -c core.quotePath=false diff --cached -U0 --no-renames --diff-filter=ACMRT -- "$file" \
      | awk '/^@@/ { in_hunk = 1; next } in_hunk && /^\+/ { print substr($0, 2) }')
  done < <(git -c core.quotePath=false diff --cached -z --name-only --no-renames --diff-filter=ACMRT)
else
  for file in "$@"; do
    [ -f "$file" ] && check_text "$file" < "$file"
  done
fi

exit "$found"
