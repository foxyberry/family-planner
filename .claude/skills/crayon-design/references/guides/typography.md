# Typography: Playpen Sans

Use this when you set a text style, pick a weight or set line height. The sizes, weights and line-height factors are in the spec
(`docs/superpowers/specs/2026-11-07-m2-screens-spec.md`, section 0): **Principles → Type and
space**, **Text weights**, **Line height is total**, and the type ramp in **Sizing →
Type**. Read them there; don't copy them here or into a view.

## One font, one ramp
- Every word on screen is Playpen Sans. SF and the system text styles are not used for visible
  text (an accepted exception in `../hig-exceptions.md`).
- Use only the ramp steps, through the one modifier in `ios/DesignSystem` (`crayonType`).
  No raw font sizes, weights or line spacing at a call site.
- Hierarchy comes from the ramp step and the weight, not from colour.
- If text doesn't fit on the board, reword it there; never shrink it.

## Weights
- Use the weights the spec gives per role (**Text weights**). The font file is variable and
  also ships named instances (`PlaypenSans-Medium`, `-SemiBold`, `-Bold`, `-ExtraBold`, and
  lighter ones). Use the named instance for the role's weight.
- Measure with the weight the text shows in: bold when picked, semibold where the spec says
  (hour labels).
- A picked tab gets heavier. Size the tab for the picked weight so it doesn't jump.
- **Bold Text** on: step each role up one named instance (Medium → SemiBold, Bold →
  ExtraBold), via `@Environment(\.legibilityWeight)` in the style modifier, not at call sites.
  Re-measure widths that were sized from the normal weight.

## Size
- Build each style as `Font.custom("<instance name>", size: <ramp size × s>)`. The size may be
  fractional; fonts are vectors and stay crisp. Text sizes come from `s` only: no
  `relativeTo:` scaling and no `@ScaledMetric` in this phase (spec **Sizing → Type**).
- In debug builds, assert at launch that each instance name resolves (`UIFont(name:size:)`
  not nil). A missing font falls back to the system font silently.

## Line height
- The spec's line height is the **whole line box**: size × factor. It is not added on top of the
  font's own leading (**Line height is total**).
- Compute the line box from the size the text is rendered at (ramp size × s).
- Line pitch inside a text block (two-line hub, row title over caption) is type, not spacing:
  take it from the ramp, not from the spacing tokens.

## Lines, wrapping and "…"
- Button and tab text is one line (spec **Sizing → Text that does not fit**). Switch captions take at most two lines.
- Only typed names (kid, school, activity) may end with "…", after two lines.
- Prefer wrapping to truncating. Don't use `allowsTightening` or tracking to squeeze a label
  into a box: reword it.
- Give text the full width it may use (`.frame(maxWidth: .infinity, alignment: .leading)`)
  and `fixedSize(horizontal: false, vertical: true)` where it must grow downwards.

## Measuring
- Minimum widths come from measured text, never a rounded guess:
  `swift .claude/skills/crayon-design/scripts/measure-text.swift <size> <weight> "<text>"`.
  Use the board size and the shown weight; add both paddings from the board.
- Measure the longest label that can appear there, including picked and Bold Text weights.
- Write the measured minimum into the spec with its formula (SKILL.md, step 5).

## Checks before handing over
- Every text uses `crayonType`; no `.font(.system…)`, no raw sizes.
- At s = 1 and on the smallest screen: nothing clips or overlaps.
- Bold Text on: picked tabs and label columns still fit.
- Night look (A1n, B2n): weights and sizes match the day look.

Source: distilled from apple-skills design → typography and design-system (MIT),
ios-design-guidelines (platform-design-skills, MIT) and swiftui-expert text-patterns and
accessibility-patterns (Antoine van der Lee, MIT).
