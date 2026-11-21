---
name: crayon-design
description: The design standard for this crayon iPad family planner. Use before choosing or changing any size, floor, padding, gap, type size, touch target, colour pair, contrast or copy on a board, in the M2 spec, in layout JSON / redlines (layout vN) or in ios/DesignSystem. Also use when another session asks a design question ("board or app?", "what floor?", "does this fit on the 11-inch / mini?"), when a screen looks cramped, clipped, truncated or overlapping, when an app screen and its board disagree, for the night look, Dynamic Type or kid vs grown-up rules, and before handing a board over. Use it even for one button or label. It says which general design skills to load for each job and which of their advice this app overrides. Not for reducers, TCA wiring, Bazel or git.
metadata:
  version: 0.2.0
  status: experimental
---

# Crayon design

## Overview
This app has one design language: hand-drawn boards at the 13" iPad size, shown on smaller
iPads through one scale and a set of floors. The rules live in the M2 spec; this skill says how
to use them, how to check a value before writing it, which general skills to load for which job,
and what to do when general Apple advice conflicts with this app.

**This skill holds no design numbers on purpose.** Numbers live in the spec and nowhere else, so
they can't drift. When you need a value, read it from the spec section named here.

## Where the rules are
Read these in `docs/superpowers/specs/2026-11-07-m2-screens-spec.md`:
- **Section 0 "Shared rules":**
  - **Principles** (board 00): time, kids, who is who, type and space, drawing, privacy.
  - **Text weights**, **Line height is total**, **Crayon rounded boxes**, **Crayon part inset**.
  - **Grid and frame**: Fixed regions, Layout contract, Status bar, and **Sizing formulas**. The
    formulas cover the scale, the type ramp, the spacing tokens and **Part floors**, which holds
    the three kinds of value, the touch floors, the floors per part, padding, the label column,
    text, Dynamic Type and the give-way order. The **Check** bullet says what the snapshot tests
    enforce.
  - **Grown-up form layout** and the **Fill rule**.
  - "One colour per kid" and the colour tokens (`kidA`, `kidB`, `pickBlue`, `softText`,
    `lateText` …).
- **Screen sections** (A1, A1n night look, Sky switch, Motion, G1 …): per-screen rules.
- **Change log** at the top: what changed and why.

Layout geometry per board is in `docs/superpowers/layout/*.json`; its README logs each layout
version.

Rules for reading the spec:
- The **Part floors** body overrides older change-log lines and older bullets on the same subject.
- If **Part floors** is missing, the repo copy of the spec is behind the design session's copy.
  Stop and ask the design session. Never rebuild the rules from memory or from this skill.
- If this skill and the spec disagree, the spec wins. Fix this skill in the same change.

## Before you write a value
1. **Find the part's rule** in Part floors. If the part has none, adding a rule is the job, not a
   one-off value for this screen.
2. **Measure text-driven minimums.** Run this from the repo:
   `swift .claude/skills/crayon-design/scripts/measure-text.swift 24 bold "Preschool"`.
   - Use the size of the type floor.
   - Use the weight the text shows in (bold when picked; semibold for hour labels).
3. **Try the formula on every iPad at once:**
   `python3 .claude/skills/crayon-design/scripts/scale.py "max(176*s,142)"`.
   - The 13" column must equal the board value: a floor never changes the 13" look.
   - Then add up the row's parts on the 11" and the mini. If they don't fit, name the
     give-way step that applies.
4. **Check colour pairs** before naming one:
   `python3 .claude/skills/crayon-design/scripts/contrast.py 625D6E FFFFFF`.
   The pass marks are the spec's **Contrast** rule (by text size), on day and night grounds.
5. **Write it down.** Put the value into the spec with its formula, plus a change-log line. A
   value that only lives in a chat message or a PR description is lost.

## Which guide for which job
The guides in `references/guides/` hold what this app needs from general design practice, already
filtered for it. Read the one for the job; general skills are optional extras.

| Job | Read | If installed |
|---|---|---|
| New or changed rule, token or part | `guides/reviews.md` §1 | `design:design-system` |
| Touch, contrast, accessibility settings, gestures | `guides/accessibility.md` | `ios-design-guidelines`, `ipados-design-guidelines`, `design:accessibility-review` |
| Custom font, Dynamic Type | `guides/typography.md` | `apple-skills:design` (typography) |
| Sizes, safe area, orientation, floors SwiftUI can build | `guides/layout-and-sizes.md` | `ipados-design-guidelines`, `swiftui-expert:swiftui-expert-skill` |
| Labels, confirms, empty looks | `guides/copy.md` | `design:ux-copy`, `apple-skills:design` (ux-writing) |
| Kid moments (slide, medal, checks, picture rigs) | `guides/kid-feedback.md` | `apple-skills:design` (game-feel) |
| Board → build handover | `guides/reviews.md` §2 | `design:design-handoff` |
| A board is finished | `guides/reviews.md` §3 | `design:design-critique` |

Filter anything general through `references/hig-exceptions.md`. Work from the spec, never from
memory. To add the optional HIG skills:
`npx skills add ehmo/platform-design-skills -g -a claude-code -s ipados-design-guidelines -s ios-design-guidelines -y`.

## Kid screens
- Kid screens follow the kid rules in the Principles and the screen sections.
- `scripts/check-kid-screens.sh` blocks some kid-screen mistakes at push.
- Kid touch floors are in Part floors. Never take a grown-up floor for a kid control.

## When the app and its board disagree
1. The building session reports: board id · what it sees · measured pt vs expected · a crop.
   Use fake names only.
2. The design session decides which one is right.
3. The losing side changes. If the board changes, update the board, re-export the layout JSON
   (layout vN, README line) and add a spec change-log line. If the app changes, the layout test
   proves it.
4. Neither side quietly copies the other: a silent copy hides a rule that was missing.

## Size check: 13 → 11 → mini
Follow `references/size-check.md`: screens and states to capture, known risks, and the report
format. Fix rules first, then code. A per-screen workaround means a rule is missing.

## Handover contract
The spec, the layout JSON and this skill have one copy each, in this repo. The **design session**
edits them on its own branch (a worktree, PR into develop); the building session reads them and
changes app code only. After a board change, the design session does these steps with the tools in
`scripts/board/` (its README covers setup):
1. Re-export the layout JSON and redlines, and bump the layout version with a README line.
2. Add a change-log line to the spec.
3. Tell the building session.

The app's layout tests read the JSON, so a board changed without a re-export is a silent fork.
Other sessions report board problems; they don't edit layout JSON.

## Common mistakes
| Mistake | Instead |
|---|---|
| Squeezing text (`minimumScaleFactor`, 70 % labels) | Reword, or use the give-way order |
| A gap or padding cut for one screen | The part's floor in Part floors |
| A kid control given a grown-up floor | Use the kid floors |
| The `Spacing.m` (24) token where the spec says the 16 token | Use the token the spec names |
| A minimum width from a rounded guess | `measure-text.swift` |
| A floor that changes the 13" look | The 13" column of `scale.py` must equal the board |
| A number written into this skill | The number goes in the spec; the skill names the section |

## Public repo
This repo is public. Boards, specs, layout JSON, captures and this skill use Kid A / Kid B and
fake places. Never write real names, ages, school names, stops, routes or keys.
