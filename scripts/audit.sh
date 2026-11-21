#!/bin/bash
# The mechanical part of a develop audit (`architecture-audit` skill), run on request only, in the
# auditor's own worktree checked out at origin/develop. Prints a Markdown report skeleton:
#   - the range: the last audited SHA (audit-last in the git common dir, shared by every worktree of
#     this clone and never committed) to HEAD, and what changed;
#   - every repo guard over the whole tree (audit mode), with its first findings;
#   - the shrink-only pending lists: their size now and at the last audit;
#   - dead-code candidates from the changed Swift files (grep): declarations whose name appears
#     nowhere else in ios/, or only in tests or DebugTools. Candidates, not verdicts: a protocol
#     requirement, an override or a SwiftUI entry point can look unused;
#   - comments that quote a board's numbers without a layout version, to re-check against the board.
#
# Usage: scripts/audit.sh [--since SHA] [--mark]
#   --since SHA  audit from SHA instead of the last audited one (first run: 50 commits back)
#   --mark       after the report, record HEAD as the last audited SHA
set -u
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
LAST_FILE="$(git rev-parse --path-format=absolute --git-common-dir)/audit-last"
since="" mark=0
while [ $# -gt 0 ]; do
  case "$1" in
    --since) since="$2"; shift 2 ;;
    --mark) mark=1; shift ;;
    *) echo "usage: scripts/audit.sh [--since SHA] [--mark]" >&2; exit 2 ;;
  esac
done
[ -n "$since" ] || since="$(cat "$LAST_FILE" 2>/dev/null || git rev-parse HEAD~50)"
head="$(git rev-parse HEAD)"

echo "# develop audit ${head:0:7}"
echo
echo "Range: ${since:0:7}..${head:0:7} ($(git rev-list --count "$since..$head") commits)"
changed="$(git diff --name-only "$since" "$head" -- ios scripts .claude/skills CLAUDE.md)"
echo
echo "## Changed files ($(printf '%s\n' "$changed" | grep -c .))"
printf '%s\n' "$changed" | sed 's/^/- /'

echo
echo "## Guards over the whole tree"
for guard in scripts/check-*.sh; do
  case "$guard" in */check-prereqs.sh|*/check-private-terms.sh) continue ;; esac
  out="$(bash "$guard" 2>&1 >/dev/null)"
  if [ $? -eq 0 ]; then
    echo "- $(basename "$guard"): pass"
  else
    echo "- $(basename "$guard"): **findings**"
    printf '%s\n' "$out" | head -5 | sed 's/^/  - /'
  fi
done

echo
echo "## Pending lists (shrink-only)"
for list in scripts/*-pending.txt; do
  count() { grep -cvE '^[[:space:]]*(#|$)'; }
  now="$(count < "$list")"
  before="-"
  git cat-file -e "$since:$list" 2>/dev/null && before="$(git show "$since:$list" | count)"
  flag=""
  [ "$before" != "-" ] && [ "$now" -ge "$before" ] && [ "$now" -gt 0 ] && flag=" (did not shrink)"
  echo "- $(basename "$list"): $before -> $now$flag"
done

echo
echo "## Dead-code candidates (grep, changed Swift files)"
common='^(body|id|init|reduce|hash|description|run|main|setUp|tearDown|task|state|action|value|name|test.*)$'
printf '%s\n' "$changed" | grep -E '^ios/.*\.swift$' | grep -vE '/(Tests|SnapshotTests)/' | while read -r file; do
  [ -f "$file" ] || continue
  grep -oE '^[[:space:]]{0,4}((public|internal) )?((static|final) )?(struct|class|enum|protocol|func|var|let|typealias)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' "$file" |
    awk '{print $NF}' | sort -u | grep -vE "$common" | while read -r name; do
      # Used again in its own file: in use. Otherwise look at the other files that name it.
      [ "$(grep -cw "$name" "$file")" -gt 1 ] && continue
      uses="$(grep -rlw --include='*.swift' "$name" ios | grep -vx "$file")"
      case "$file" in ios/DebugTools/*) product='/(Tests|SnapshotTests)/' ;; *) product='/(Tests|SnapshotTests)/|^ios/DebugTools/' ;; esac
      if [ -z "$uses" ]; then
        echo "- \`$name\` ($file): nothing names it"
      elif ! printf '%s\n' "$uses" | grep -vqE "$product"; then
        echo "- \`$name\` ($file): only tests or DebugTools name it"
      fi
    done
done

# A comment that quotes a board's numbers without "layout vN" can't go stale in check-layout-versions'
# eyes (2026-11-22: the audit dropped 34 stale versions): re-check these against the board each audit.
echo
echo "## Board numbers without a version (changed Swift files)"
boards="$(ls docs/superpowers/layout/*.json 2>/dev/null | xargs -n1 basename | sed 's/\.json$//' | paste -sd'|' -)"
if [ -n "$boards" ]; then
  printf '%s\n' "$changed" | grep -E '^ios/.*\.swift$' | while read -r file; do
    [ -f "$file" ] || continue
    grep -nE "^[[:space:]]*//.*\b($boards)\b" "$file" | grep -v "layout v[0-9]" |
      awk '{ line = $0; sub(/^[0-9]+:/, "", line); gsub(/20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]/, "", line)
             if (line ~ /[0-9][0-9]/) print }' |
      sed "s|^|- $file:|" | cut -c1-160
  done
fi

if [ "$mark" = 1 ]; then
  echo "$head" > "$LAST_FILE"
  echo
  echo "Marked ${head:0:7} as the last audited commit."
fi
