#!/bin/bash
# Local issues: work a session leaves for later, its own or another session's (not reviews or PR
# waits; the board shows those). One file per issue in the main checkout's .claude/issues/
# (git-ignored, so private detail is fine there); the board lists open ones by owner.
#
# Owner is the short name of the session that will do it: main, review, design or harness.
# Usage: scripts/issue.sh new <owner> <title> [area]   create one; prints its path
#        scripts/issue.sh list [owner]                 open issues (all, or one owner's)
#        scripts/issue.sh close <number>               mark it done (the file stays as a record)
# ISSUES_DIR overrides the folder (tests).
set -u
dir="${ISSUES_DIR:-$(cd "$(git rev-parse --git-common-dir)/.." && pwd)/.claude/issues}"
field() { sed -n "s/^$2: *//p" "$1" | head -1; }

case "${1:-}" in
  new)
    [ $# -ge 3 ] || { echo "usage: $0 new <owner> <title> [area]" >&2; exit 2; }
    mkdir -p "$dir"
    last="$(ls "$dir" 2>/dev/null | sed -n 's/^\([0-9][0-9]*\)-.*\.md$/\1/p' | sort -n | tail -1)"
    num="$(printf '%03d' $((10#${last:-0} + 1)))"
    slug="$(printf '%s' "$3" | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//' | cut -c1-40)"
    file="$dir/$num-${slug:-issue}.md"
    printf '# %s\n\nowner: %s\nstatus: open\nopened: %s\narea: %s\n\n## What is left\n\n## Done when\n' \
      "$3" "$2" "$(date +%Y-%m-%d)" "${4:-}" > "$file"
    echo "$file"
    ;;
  list)
    for f in "$dir"/*.md; do
      [ -e "$f" ] || continue
      status="$(field "$f" status)"
      case "$status" in done*|closed*) continue ;; esac
      owner="$(field "$f" owner)"
      [ -z "${2:-}" ] || case "$owner" in "$2"*) ;; *) continue ;; esac
      printf '%s  [%s]  %s\n' "$(basename "$f" .md)" "$owner" "$(sed -n 's/^# //p' "$f" | head -1)"
    done
    ;;
  close)
    [ $# -ge 2 ] || { echo "usage: $0 close <number>" >&2; exit 2; }
    file="$(ls "$dir"/"$(printf '%03d' "$((10#$2))")"-*.md 2>/dev/null | head -1)"
    [ -n "$file" ] || { echo "issue $2: not found in $dir" >&2; exit 1; }
    sed -i.bak "s/^status: .*/status: done $(date +%Y-%m-%d)/" "$file" && rm -f "$file.bak"
    echo "closed: $file"
    ;;
  *) sed -n '2,10p' "$0" >&2; exit 2 ;;
esac
