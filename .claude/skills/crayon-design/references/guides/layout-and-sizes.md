# Layout and sizes across iPads

Use this when a screen must fit every iPad, when a Part floors rule has to become SwiftUI, or
when someone asks about orientation or multitasking. The numbers live in the spec
(`docs/superpowers/specs/2026-11-07-m2-screens-spec.md`, section 0): **Grid and frame**,
**Sizing formulas** (with **Part floors**), **Grown-up form layout** and the **Fill rule**.

## The iPads
- The boards are drawn at the 13" size. Every other landscape iPad gets the same board through
  one scale `s` plus floors. The list of iPads and their `s` comes from
  `python3 .claude/skills/crayon-design/scripts/scale.py "<formula>"`; don't keep your own list.
- Think in the full set at once: the 13" (board), the family's 12.9", the 11" models and the
  mini. A rule is right only when it holds on all of them (`../size-check.md`).
- Never design a separate layout per device and never branch on a device name. The same code
  reads the window size and `safe.top` and computes `s`.

## Safe area and the status bar
- Read the top inset from the system each time (`safe.top` in **Sizing formulas → Inputs**).
  It differs between iPads and OS versions; a hard-coded value shifts every y.
- The status band holds only full-bleed backgrounds (paper, night sky). Use
  `ignoresSafeArea` on those background layers only, naming the edges; never on content.
- Don't subtract the safe area twice. If a view already lays out inside the safe area, don't
  also pad it by the inset.
- The main button bottom stays clear of the home indicator (spec **Grid and frame → Bottom**).

## How a Part floors rule becomes SwiftUI
1. **One helper per part.** Every floored value comes from the `Sizing` helper in
   `ios/DesignSystem` (Part floors: "Build it once in DesignSystem"). A screen never computes
   its own `max(...)`.
2. **Know the kind of value.** Part floors names three: free × s, floored, fixed. Region frames
   are free; control boxes, type and tokens are floored; strokes, touch floors and identity
   faces are fixed. Pick the right `Sizing` call for the kind.
3. **Minimum frames, not fixed ones.** Controls take
   `.frame(minWidth: sizing.…, minHeight: sizing.…)`. A fixed `.frame(width:height:)` is only
   for things the spec calls fixed and that hold no text (a stroke, a face, a knob).
   This is what lets Dynamic Type grow a control (spec **Part floors → Text → Dynamic Type**).
4. **Regions are fixed frames.** Regions come from the layout JSON through the one placement
   modifier (`ios/DesignSystem/Layout`). Content is top-aligned inside its region and never
   resizes it (spec **Fixed regions**, **Layout contract**). No stack spacing, `Spacer`
   centring or guessed offsets between listed parts.
5. **No whole-screen scaling.** Never `scaleEffect` a screen; multiply each value by `s`.
6. **Measure text-driven minimums** with
   `swift .claude/skills/crayon-design/scripts/measure-text.swift <size> <weight> "<text>"` at
   the type floor and the weight the text shows in.

## The give-way order in code
The spec's order ("When a row does not fit, give way in this order") maps to code like this:
- **Steps 1–4** (spare width, gaps down to floors, stretchable controls down to their minimum,
  the label column growing) are arithmetic. Do them in the part's `Sizing` helper, the way the
  spec's **G1 slice card times row** worked example does, and return the widths.
- **Step 5, reflow**, is a layout switch:
  - When the switch depends only on whether the row fits, use `ViewThatFits(in: .horizontal)`
    with the row first and the stacked version second. `ViewThatFits` picks the first child
    that fits at its ideal size.
  - When the children hold `@State` (a focused field, a picked tab), use one container with
    `AnyLayout(HStackLayout())` / `AnyLayout(VStackLayout())` chosen from the computed widths,
    so the controls keep their identity and state when the row flips.
  - Equal-choice groups wrap to a second line and apply the **Fill rule** per line.
  - A start → end pair stacks as the spec says (start first, "→ end" second).
- **Step 6** is a vertical `ScrollView` on the card only, never on a kid screen (kid screens
  never scroll; they turn a page, spec **Principles → Kids**).
- **Never**: sideways scroll, `minimumScaleFactor`, padding under its floor, a target under its
  touch floor.

## Dynamic Type and the scale together
- `s` sizes the screen; Dynamic Type sizes the text on top of it. Use one or the other per
  value, never both (spec **Sizing formulas → Type**: no `@ScaledMetric` on the same size).
- At large text sizes a row hits step 5 earlier. That is expected; check it in the size run.
- Kid screens are fixed regions that don't scroll. When large text would overflow a kid
  region, raise it with the design session rather than clipping or shrinking.

## Orientation and multitasking: open questions
These are **not decided**. Don't design or build them on your own; raise the question when it
matters (`../hig-exceptions.md`, "Open").
- **Orientation**: the app is landscape only. Question: portrait for grown-up screens?
- **Split View, Slide Over, Stage Manager, resizable windows**: not designed. The formulas run
  with `s` floored (spec **Sizing formulas → Not covered yet**), so small windows may clip.
  Question: design small windows, or lock to full screen?
- **Reflow instead of scale** on the mini for grown-up screens (fewer columns rather than a
  smaller `s`): decide after the mini check.
- Until decided, still write code that would survive: read the proposed size and the safe
  area, not the screen bounds; don't cache a size; don't branch on orientation.

## When something doesn't fit
1. Run `scale.py` on the part's formula; the 13" column must equal the board.
2. Add up the row on the 11" and the mini.
3. Name the give-way step that applies. If none does, the rule is missing: report it with the
   format in SKILL.md ("When the app and its board disagree") instead of a one-screen fix.

Source: distilled from ipados-design-guidelines and ios-design-guidelines (platform-design-skills,
MIT) and swiftui-expert layout-best-practices (Antoine van der Lee, MIT).
