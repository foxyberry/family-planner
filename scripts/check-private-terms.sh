#!/bin/bash
# Blocks private terms (home stops, school names, children's names) from reaching this public repo.
# Terms live in the git-ignored .private-terms file: one per line, case-insensitive substring match.
#
# Usage:
#   check-private-terms.sh --staged     check lines added in the staged diff (pre-commit)
#   check-private-terms.sh <file>...    check whole files
# Exit code: 0 = clean, 1 = a private term was found.
set -u

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TERMS_FILE="$ROOT/.private-terms"

if [ ! -f "$TERMS_FILE" ]; then
  echo "warning: .private-terms not found; skipping private-term check" >&2
  exit 0
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

if [ "${1:-}" = "--staged" ]; then
  while IFS= read -r file; do
    # Process substitution (not a pipe) so check_text runs in this shell and can set $found.
    check_text "$file" < <(git diff --cached -U0 --diff-filter=ACM -- "$file" | grep '^+' | grep -v '^+++')
  done < <(git diff --cached --name-only --diff-filter=ACM)
else
  for file in "$@"; do
    [ -f "$file" ] && check_text "$file" < "$file"
  done
fi

exit "$found"
