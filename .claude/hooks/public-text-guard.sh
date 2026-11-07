#!/bin/bash
# PreToolUse hook (Bash): commit messages, tags, PR/issue/release/gist text go straight to the
# public GitHub repo, and the pre-commit hook never sees them. Check the whole command line plus
# every file it names. Exit 2 = block and tell Claude why.
set -u

CHECK="$(cd "$(dirname "$0")/../.." && pwd)/scripts/check-private-terms.sh"
INPUT="$(cat)"

CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')"
CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty')"
[ -z "$CMD" ] && exit 0

# Any gh call (gh api can post too, and gh may be called by full path), and git commands that
# carry a message. Over-matching only costs a scan; a term is blocked only if one is present.
GH='(^|[^[:alnum:]_.-])gh[[:space:]]'
GIT_TEXT='(^|[^[:alnum:]_.-])git[[:space:]].*(commit|tag|notes)([[:space:]]|$)'
printf '%s' "$CMD" | grep -Eq "$GH|$GIT_TEXT" || exit 0

# Text produced by command substitution is invisible here. A literal heredoc ($(cat <<'EOF' ...))
# is fine because its text is part of the command line; anything else must go through a file.
WITHOUT_HEREDOC="$(printf '%s' "$CMD" | sed -E 's/\$\(cat <<//g')"
if printf '%s' "$WITHOUT_HEREDOC" | grep -Eq '\$\(|`'; then
  echo "Blocked: published text built with \$(...) or backticks cannot be checked for private terms. Write it to a file and pass --body-file / -F <file> instead." >&2
  exit 2
fi

WORK="${CWD:-${CLAUDE_PROJECT_DIR:-.}}"
cd "$WORK" 2>/dev/null || exit 0

blocked=0
printf '%s\n' "$CMD" | "$CHECK" --stdin "command text" || blocked=1

# Any existing file named on the command line may become public text (--body-file, -F,
# gh gist create <file>, release notes files...). Scan every token that is a file.
while IFS= read -r f || [ -n "$f" ]; do
  f="${f#*=}"; f="${f#\"}"; f="${f%\"}"; f="${f#\'}"; f="${f%\'}"
  [ -n "$f" ] && [ -f "$f" ] && { "$CHECK" "$f" || blocked=1; }
done < <(printf '%s' "$CMD" | tr -s ' \t\n;&|' '\n')

if [ "$blocked" -ne 0 ]; then
  echo "Blocked: this command publishes text (commit/tag/PR/issue/release) that contains a private term. Rewrite it with fake values." >&2
  exit 2
fi
exit 0
