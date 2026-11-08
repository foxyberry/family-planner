#!/bin/bash
# SessionStart hook: says so when 5 or more lessons wait in .claude/lessons.md, or when the skills
# or the inbox are malformed. Prints nothing otherwise. Never blocks the session (always exit 0).
ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
[ -f "$ROOT/scripts/check-skills.sh" ] || exit 0

out="$(bash "$ROOT/scripts/check-skills.sh" "$ROOT" 2>&1)"
code=$?
open="$(printf '%s\n' "$out" | sed -n 's/^check-skills: \([0-9]*\) open lessons$/\1/p' | tail -1)"

if [ "$code" -ne 0 ]; then
  echo "Agent harness needs fixing (scripts/check-skills.sh):"
  printf '%s\n' "$out"
elif [ "${open:-0}" -ge 5 ]; then
  echo "$open open lessons wait in .claude/lessons.md. Use the skill-retro skill when the current task allows."
fi
exit 0
