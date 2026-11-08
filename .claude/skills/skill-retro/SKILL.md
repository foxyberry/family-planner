---
name: skill-retro
description: Use when the lessons inbox (.claude/lessons.md) has 5 or more open lessons, when check-skills or the session-start note reports waiting lessons, at the end of a milestone or PR stack, when the user asks to retrospect, review or reorganise skills, or right after a mistake that another session could repeat (record it first).
metadata:
  version: 0.1.0
  status: experimental
---

# Skill retro

## Overview
Lessons go into `.claude/lessons.md` the moment they happen and reach skills in batches. The inbox is
short-lived: a retro moves every line into the one place that will stop the mistake, then deletes it.

## Record a lesson (any time)
Append one line, no private data (public repo):
`- YYYY-MM-DD · symptom · cause · rule · target`
- symptom: what went wrong, as a user would see it
- cause: the real reason, not the first guess
- rule: what to do next time, as an instruction
- target: `guard`, `CLAUDE.md`, a skill name (`bazel-ios`, `git-flow-delivery`, ...) or `drop`

## Run a retro
1. `bash scripts/check-skills.sh`: count the open lessons and catch broken frontmatter or oversized files.
2. For each lesson, choose its target in this order and record the choice:

| If the rule... | Target |
|---|---|
| can be checked by a script, hook or test | `guard`: add the check and its test under `scripts/tests/` |
| holds for every task in this repo | `CLAUDE.md`: one line in the matching section |
| is a step of a procedure a skill already owns | that skill: put it in the step, error table or checklist where it applies |
| is a new repeatable procedure (3+ steps) | a new skill (superpowers:writing-skills) |
| was a one-off or is already covered | `drop`, and say where it is covered |

3. Edit the targets. Each rule appears in one place only: search CLAUDE.md and every skill for it
   first, merge duplicates, and link with the skill name instead of copying text.
4. Tidy every skill you touched:
   - bump `metadata.version` (patch for wording, minor for a new rule)
   - keep the description to trigger conditions only
   - stay under the word limits that check-skills enforces
   - remove rules the code no longer needs
5. Delete the processed lines from the inbox. The rest of the file stays.
6. Verify:
   - `bash scripts/check-skills.sh` reports 0 open lessons and no errors
   - `for t in scripts/tests/*-test.sh; do bash "$t"; done` passes
7. Commit as `docs(harness): skill retro <date>`. List each lesson and its target in the message,
   and ask the user before pushing.

## Common mistakes
- Copying a lesson word for word into a skill as a story. Write the rule at the step where it applies.
- Adding to CLAUDE.md what only one procedure needs. It loads in every session.
- Leaving a guard-able rule as prose. A check never forgets; prose does.
- Recording only after the fix. Write the line as soon as the cause is known, so a compaction cannot lose it.
