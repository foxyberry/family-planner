---
name: ux-review
description: Use when reviewing the UX of a screen or flow before or after it is built (a new screen such as the school calendar, a board family, a kid or grown-up flow), when a state may have no board ("did anyone draw this?"), when checking the kids' home across a whole day, or when a fresh reviewer should judge screens from screenshots and a task alone.
metadata:
  version: 0.1.0
  status: experimental
---

# UX review

## Overview
Board-only reviews miss what no board draws: the home's Next row named School twice under the Leave
row (fixed in #233). That state had no board, and nobody looked at the home at that minute. This
review runs three pieces, and each finds what the others can't:

| Piece | Finds | Runs on |
|---|---|---|
| 1. State list (`scripts/ux-states.sh`) | states in the code that no board draws | built screens |
| 2. Home sweep (`make ux-sweep`) | what the home shows at each time of a day | the kids' home |
| 3. Screen-only reviewer | what a person can't tell or do from the screens | boards, mockups, frames, iPad captures |

A screen with no code yet (a new design) gets piece 3 alone, on its boards.

## 1. State list
1. Mark the enum that holds a screen's states: add `/// ux-states: <screen>` to its doc comment.
2. Start each case's doc comment with the boards that draw it: `/// A1 / A1m / E1: …`. A case that
   starts any other way has no board.
3. Run `bash scripts/ux-states.sh` (or pass the screen's folder). Each line holds the screen, the
   state, its boards and a verdict. A verdict of `NO BOARD` or `UNKNOWN BOARD …` is a finding for the
   design session: draw it, or show it can't happen.
- The list sees enum cases. A state that lives in a count or a flag (E1 is "one kid") needs its own
  enum or a sweep day.

## 2. Home sweep
- Run `make ux-sweep` (add `PUBLIC_BUILD=1` in a worktree without private data). One simulator; it
  takes minutes. The output goes to `.ux-review/sweep-<time>/` (git-ignored; it may hold the private
  home drawing, so it never goes into a PR, an Artifact or an issue):
  - `<day>-sheet.png`: every 15 minutes of the day on one sheet, each frame labelled with its time
    and states (for the design session);
  - `frames/<day>/<HHMM>.png`: the bare frames, named by time only (for piece 3);
  - `states.tsv`: day, time, Kid A's block and its end, E1's Next row, Kid B's Now and Next.
- The days are a school day, a Saturday, a public holiday and a one-kid school day
  (`ios/Journeys/Tests/Sweep/HomeSweepTests.swift`). Add a day there when a review needs one.
- Read `states.tsv` against the spec's rules ("an item shows once per kid"), then the sheet.
  Compare the states the sweep hit with piece 1's list: a state it never hit needs a day that reaches
  it, or a reason why no day can.

## 3. Screen-only reviewer
1. Pick the screenshots: board images from the design session, bare sweep frames, or iPad captures.
   File names carry the time or the board only, never a state name, a test name or a conclusion.
2. Write the user tasks in the user's words ("From tomorrow, dinner is at 6:00 pm on school days"),
   each with the person who does it (Kid A reads the clock, Kid B doesn't, a grown-up).
3. Start a fresh subagent, never a fork: it must not see this conversation, the driver's action list,
   the design notes or piece 1's table. Give it the images, the tasks and the prompt in
   `reviewer-prompt.md`.
4. Bring its findings to the design session as they are, with the screens they cite. Items it marks
   "needs iPad observation" go into the review's iPad table (format: the #225 review in
   `docs/superpowers/reviews/`).

## Output
One review file in `docs/superpowers/reviews/<date>-<screen>.md`, written by the design session. It
holds the boards and layout versions reviewed, the findings ranked with screen evidence, piece 1's
board-less states, and the iPad observations still to make. It never quotes private data.

## Common mistakes
- Giving the reviewer the answer: state names in file names, "the duplicate is at 7:30", the spec
  section. It then confirms instead of finding.
- Sweeping a sample family only: one-kid states (E1) never show. Keep the one-kid day.
- Reading the sheet without `states.tsv`: a frame that looks right can still sit in a board-less state.
