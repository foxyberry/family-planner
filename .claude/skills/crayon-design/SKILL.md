---
name: crayon-design
description: The design standard for this crayon iPad family planner. Use before choosing or changing any size, padding, gap, type size, touch target, colour pair, contrast or copy on a board, in the M2 spec, in layout JSON / redlines (layout vN) or in ios/DesignSystem. Also use when another session asks a design question ("board or app?", "does this fit on the mini?"), when a screen looks cramped, clipped, truncated or overlapping, when an app screen and its board disagree, for the night look, scaling or kid vs grown-up rules, and before handing a board over. Use it even for one button or label. It says which general design skills to load for each job and which of their advice this app overrides. Not for reducers, TCA wiring, Bazel or git.
metadata:
  version: 0.2.1
  status: experimental
---

# Crayon design

## Overview
This app has one design language: hand-drawn boards at the 13" iPad size, shown on smaller
screens through one scale with no floors. The rules live in the M2 spec; this skill says how
to use them, how to check a value before writing it, which general skills to load for which job,
and what to do when general Apple advice conflicts with this app.

**This skill holds no design numbers on purpose.** Numbers live in the spec and nowhere else, so
they can't drift. When you need a value, read it from the spec section named here.

## Where the rules are
Read these in `docs/superpowers/specs/2026-11-07-m2-screens-spec.md`:
- **Section 0 "Shared rules":**
  - **Principles** (board 00): time, kids, who is who, type and space, drawing, privacy.
  - **Text weights**, **Line height is total**, **Crayon rounded boxes**, **Crayon part inset**.
  - **Grid and frame**: Fixed regions, Layout contract, Status bar, and **Sizing: one scale, no
    floors** (every size is board × s; touch is the visible box; leftover space is paper). The
    **Check** bullet says what the snapshot tests enforce.
  - **Grown-up form layout** and the **Fill rule**.
  - "One colour per kid" and the colour tokens (`kidA`, `kidB`, `pickBlue`, `softText`,
    `lateText` …).
- **Screen sections** (A1, A1n night look, Sky switch, Motion, G1 …): per-screen rules.
- **Change log** at the top: what changed and why.

Layout geometry per board is in `docs/superpowers/layout/*.json`; its README logs each layout
version.

Rules for reading the spec:
- The **Sizing** body overrides older change-log lines and older bullets on the same subject.
- If **Sizing: one scale, no floors** is missing, the repo copy of the spec is behind the design session's copy.
  Stop and ask the design session. Never rebuild the rules from memory or from this skill.
- If this skill and the spec disagree, the spec wins. Fix this skill in the same change.

## Before you write a value
1. **Find the part's board size** on its board and in the layout JSON. On screen it is that
   size × s; a part never gets its own size per screen.
2. **Measure text-driven minimums.** Run this from the repo:
   `swift .claude/skills/crayon-design/scripts/measure-text.swift 24 bold "Preschool"`.
   - Use the board size of the text.
   - Use the weight the text shows in (bold when picked; semibold for hour labels).
3. **See the value on every screen at once:**
   `python3 .claude/skills/crayon-design/scripts/scale.py "176*s"`.
   - It must fit on the board (s = 1); then it fits everywhere, since everything scales together.
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
| Custom font, type ramp | `guides/typography.md` | `apple-skills:design` (typography) |
| Sizes, scale, safe area, orientation in SwiftUI | `guides/layout-and-sizes.md` | `ipados-design-guidelines`, `swiftui-expert:swiftui-expert-skill` |
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
- Kid targets are big on the board (spec Principles and the screen sections); they scale like everything else.

## When the app and its board disagree
1. The building session reports: board id · what it sees · measured pt vs expected · a crop.
   Use fake names only.
2. The design session decides which one is right.
3. The losing side changes. If the board changes, update the board, re-export the layout JSON
   (layout vN, README line) and add a spec change-log line. If the app changes, the layout test
   proves it.
4. Neither side quietly copies the other: a silent copy hides a rule that was missing.

## Size check
Follow `references/size-check.md`: what to check at s = 1 and on the smallest screen, the known
risks and the report format. A per-screen size means something didn't scale.

## Handover contract
The spec, the layout JSON and this skill have one copy each, in this repo. The **design session**
edits them on its own branch (a worktree, PR into develop); the building session reads them and
changes app code only. After a board change, the design session does these steps with the tools in
`scripts/board/` (its README covers setup):
1. Re-export the layout JSON and redlines, and bump the layout version with a README line.
2. Add a change-log line to the spec.
3. Before the PR, look at the changed screen's night and public-holiday boards at 13" (s = 1): they show what the day board hides.
4. Tell the building session.

The app's layout tests read the JSON, so a board changed without a re-export is a silent fork.
Other sessions report board problems; they don't edit layout JSON.

## Common mistakes
| Mistake | Instead |
|---|---|
| Squeezing text (`minimumScaleFactor`, 70 % labels) | Reword the board label |
| A gap, padding or size set for one screen | Board value × s, everywhere |
| A floor, a max() or a fixed size in code | Board value × s |
| The `Spacing.m` (24) token where the spec says the 16 token | Use the token the spec names |
| A minimum width from a rounded guess | `measure-text.swift` |
| A number written into this skill | The number goes in the spec; the skill names the section |
| Night ink (light) on a light surface, e.g. the hub's moon-paper disc | Words on a light surface stay dark ink by day and by night; night ink is for the dark ground |
| A width limit the spec gives one line applied to the whole block | Apply it to that line only |

## Public repo
This repo is public. Boards, specs, layout JSON, captures and this skill use Kid A / Kid B and
fake places. Never write real names, ages, school names, stops, routes or keys.
