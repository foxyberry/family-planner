#!/bin/bash
# Keeps the agent harness healthy: every project skill (.claude/skills/<name>/SKILL.md) has a
# matching name, a description of at most 1024 characters and a metadata version, and stays
# under the word limit; CLAUDE.md stays short; every entry in the lessons inbox
# (.claude/lessons.md) has the five fields. Prints how many lessons wait for a skill retro.
#
# Usage: check-skills.sh [repo root]   (default: this repository)
# Exit code: 0 = healthy, 1 = something to fix.
set -u

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
SKILL_WORDS=1500
CLAUDE_WORDS=1200
found=0

fail() { echo "check-skills: $*"; found=1; }

for skill in "$ROOT"/.claude/skills/*/SKILL.md; do
  [ -f "$skill" ] || continue
  dir="$(basename "$(dirname "$skill")")"
  front="$(awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {exit} f {print}' "$skill")"
  name="$(printf '%s\n' "$front" | sed -n 's/^name:[[:space:]]*//p')"
  description="$(printf '%s\n' "$front" | sed -n 's/^description:[[:space:]]*//p')"
  [ "$name" = "$dir" ] || fail "$dir: name '$name' does not match the folder"
  [ -n "$description" ] || fail "$dir: description missing"
  [ "${#description}" -le 1024 ] || fail "$dir: description is ${#description} characters (max 1024)"
  printf '%s\n' "$front" | grep -qE '^[[:space:]]+version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+' \
    || fail "$dir: metadata version missing (bump it on every change)"
  words="$(wc -w < "$skill" | tr -d ' ')"
  [ "$words" -le "$SKILL_WORDS" ] || fail "$dir: $words words (max $SKILL_WORDS; move detail out or split)"
done

if [ -f "$ROOT/CLAUDE.md" ]; then
  words="$(wc -w < "$ROOT/CLAUDE.md" | tr -d ' ')"
  [ "$words" -le "$CLAUDE_WORDS" ] || fail "CLAUDE.md: $words words (max $CLAUDE_WORDS; move procedures into skills)"
fi

open=0
if [ -f "$ROOT/.claude/lessons.md" ]; then
  while IFS= read -r line; do
    case "$line" in
      "- "*)
        if printf '%s\n' "$line" | grep -qE '^- [0-9]{4}-[0-9]{2}-[0-9]{2}( · [^·]+){4}$'; then
          open=$((open + 1))
        else
          fail "lesson needs 'date · symptom · cause · rule · target': $line"
        fi ;;
    esac
  done < "$ROOT/.claude/lessons.md"
fi
echo "check-skills: $open open lessons"

exit "$found"
