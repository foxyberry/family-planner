#!/bin/bash
# PreToolUse hook (Bash): commit messages, tags, PR/issue/release text go straight to the public
# GitHub repo, and the pre-commit hook never sees them. Check the whole command line plus any
# --body-file / -F / --file it points at. Exit 2 = block and tell Claude why.
set -u

CHECK="$(cd "$(dirname "$0")/../.." && pwd)/scripts/check-private-terms.sh"
INPUT="$(cat)"

CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')"
CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty')"
[ -z "$CMD" ] && exit 0

PUBLISHING='(^|[;&|(`[:space:]])(git[[:space:]]+(commit|tag)|gh[[:space:]]+(pr|issue|release|repo|gist))([[:space:]]|$)'
printf '%s' "$CMD" | grep -Eq "$PUBLISHING" || exit 0

WORK="${CWD:-${CLAUDE_PROJECT_DIR:-.}}"
cd "$WORK" 2>/dev/null || exit 0

blocked=0
printf '%s\n' "$CMD" | "$CHECK" --stdin "command text" || blocked=1

# Files whose contents become public text.
while IFS= read -r f; do
  f="${f#\"}"; f="${f%\"}"; f="${f#\'}"; f="${f%\'}"
  [ -f "$f" ] && { "$CHECK" "$f" || blocked=1; }
done < <(printf '%s' "$CMD" | grep -oE '(--body-file|--notes-file|--file|-F)[= ]+[^ ;&|]+' | sed -E 's/^(--body-file|--notes-file|--file|-F)[= ]+//')

if [ "$blocked" -ne 0 ]; then
  echo "Blocked: this command publishes text (commit/tag/PR/issue/release) that contains a private term. Rewrite it with fake values." >&2
  exit 2
fi
exit 0
