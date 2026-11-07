#!/bin/bash
# PreToolUse hook (Write|Edit|MultiEdit|NotebookEdit): blocks private terms the moment Claude
# writes them into a file that git would publish. Git-ignored files (docs/private/, .private-terms,
# LocalConfig.*) and files outside any git repo are allowed.
# Exit 2 = block and tell Claude why. Bash-based writes are caught later by .githooks/pre-commit.
set -u

CHECK="$(cd "$(dirname "$0")/../.." && pwd)/scripts/check-private-terms.sh"
INPUT="$(cat)"

FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')"
TEXT="$(printf '%s' "$INPUT" | jq -r '[.tool_input.content, .tool_input.new_string, .tool_input.new_source, (.tool_input.edits[]?.new_string)] | map(select(. != null)) | join("\n")')"
[ -z "$FILE" ] || [ -z "$TEXT" ] && exit 0

# Find the repo the file belongs to (the file or its folder may not exist yet).
DIR="$(dirname "$FILE")"
while [ ! -d "$DIR" ]; do DIR="$(dirname "$DIR")"; done
ROOT="$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null)" || exit 0
git -C "$ROOT" check-ignore -q -- "$FILE" && exit 0

if ! (cd "$ROOT" && printf '%s\n' "$TEXT" | "$CHECK" --stdin "$FILE"); then
  echo "Blocked: this text contains a private term and $FILE is tracked by git (public repo). Replace it with a fake value (stop 12345, Example Primary School, Kid A), or keep real data under docs/private/." >&2
  exit 2
fi
exit 0
