# Layout and sizes across screens

Use this when a screen must fit every supported screen, when the scale rule has to become SwiftUI,
or when someone asks about orientation or multitasking. The numbers live in the spec
(`docs/superpowers/specs/2026-11-07-m2-screens-spec.md`, section 0): **Grid and frame**,
**Sizing: one scale, no floors**, **Grown-up form layout** and the **Fill rule**.

## The screens
- The boards are drawn at the 13" size. Every other screen shows the same board times one scale
  `s`, with no floors. The list of screens and their `s` comes from
  `python3 .claude/skills/crayon-design/scripts/scale.py "<formula>"`; don't keep your own list.
- The set: the 13" (board), the family's 12.9", the 11" models, the mini, and the iPhone Duo
  inner screen. Since everything scales together, checking the 13" and the smallest screen is
  enough (`../size-check.md`).
- Never design a separate layout per device and never branch on a device name. The same code
  reads the device screen size (landscape, once at launch) and `safe.top` and computes `s`.

## Safe area and the status bar
- Read the top inset from the system each time (`safe.top` in **Sizing → Inputs**). It differs
  between devices and OS versions; a hard-coded value shifts every y.
- The status band holds only full-bleed backgrounds (paper, night sky). Use `ignoresSafeArea`
  on those background layers only, naming the edges; never on content.
- Don't subtract the safe area twice. If a view already lays out inside the safe area, don't also
  pad it by the inset.
- The main button bottom stays clear of the home indicator (spec **Grid and frame → Bottom**).

## How the scale becomes SwiftUI
1. **One `Sizing` from the device screen.** The app root builds it once and puts it in the
   environment. Every value is `board value × s`; a screen never computes its own size and never
   writes a `max(...)` or a floor.
2. **Fixed regions.** Regions come from the layout JSON through the one placement modifier
   (`ios/DesignSystem/Layout`). Content is top-aligned inside its region and never resizes it
   (spec **Fixed regions**, **Layout contract**).
3. **Centre the scaled board.** The scaled board (1376 s wide) is centred; the leftover sides
   and bottom are paper.
4. **Scale values, not the screen.** Multiply each size, position and font size by `s`. Never
   `scaleEffect` a whole screen: it rasterizes and blurs text. Fractional font sizes are fine.
5. **Touch is the visible box.** No `.contentShape` or hit area larger than what is drawn.
6. **Text that may wrap** (typed names, " · " value lines) wraps to at most 2 lines, then "…" for
   typed names. Measure board labels with
   `swift .claude/skills/crayon-design/scripts/measure-text.swift <size> <weight> "<text>"` at the
   board size; a label that doesn't fit on the board is reworded there.
7. A card whose content is taller than the card scrolls vertically, never sideways; kid screens
   never scroll (they turn a page, spec **Principles → Kids**).

## Orientation and multitasking: open questions
These are **not decided**. Don't design or build them on your own; raise the question when it
matters (`../hig-exceptions.md`, "Open").
- **Orientation**: the app is landscape only. Question: portrait for grown-up screens?
- **Split View, Slide Over, Stage Manager, resizable windows**: the layout keeps the device-screen
  size; a smaller window crops it and the hidden part scrolls (spec **Supported screens and
  windows**).
- **The iPhone Duo outer screen** (phone width) is out of scope.
- Until decided, still write code that would survive: read the proposed size and the safe area,
  not the screen bounds; don't cache a size; don't branch on orientation.

## When something doesn't fit
1. Check it on the 13": the board itself must fit. If it doesn't, fix the board.
2. If it fits on the 13" but not on a smaller screen, something didn't scale by `s`: find the
   fixed number (`../size-check.md`, risk 1).
3. Report a board problem with the format in SKILL.md ("When the app and its board disagree")
   instead of a one-screen fix.

Source: distilled from ipados-design-guidelines and ios-design-guidelines (platform-design-skills,
MIT) and swiftui-expert layout-best-practices (Antoine van der Lee, MIT).
