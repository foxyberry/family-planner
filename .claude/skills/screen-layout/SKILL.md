---
name: screen-layout
description: Use when placing parts on a screen in ios/Features or ios/AppCore from a board's redlines (docs/superpowers/layout/<board>.json), writing or changing a <Screen>Layout model, sizing a grown-up form card or its rows, adding a gesture to a screen, or when a screen on the iPad looks shifted, too wide, wrapped or unresponsive to a hold. Not for sizes themselves (crayon-design) or reducers and State (tca-feature).
metadata:
  version: 0.4.1
  status: experimental
---

# Screen layout

Screens are placed from the board, not stacked by eye. Every screen is the board × one scale `s`
from the app window (spec "Sizing: one scale, no floors"), so a screen that is right at s = 1 is
right on every window.

## Place a screen
1. Take the screen's redlines from `docs/superpowers/layout/<board>.json` (ask the design session
   if a board is missing).
2. Write a `<Screen>Layout` model (board values through `Sizing.x`, `Sizing.y`, `Sizing.rect`),
   and place every part with `place(_:)`, `place(left:baseline:)`, `place(right:baseline:)` or
   `place(topLeft:)`. Every other size in the view is `sizing(board)` or a named part size.
3. Parts carry no outer padding: a part's visible edge is its frame.
4. Add a layout test at s = 1 against the board JSON and one small window (the mini, the Duo
   inner screen) checking every rect is the 13" rect × s, then look at the screen on the iPad
   with `GRID=1` (bazel-ios).
5. Screens lay out in the board frame (1376 s wide, centred by the app root; the navigation
   stack spans the window and frames each screen with `boardFrame()`, so nothing clips a pushed
   screen's sides); full-bleed backgrounds and dim layers use `fullBleed()`, so the paper runs
   past the frame and under the status bar band (y 0–24), which stays empty.

## Common mistakes
- A grown-up form card sized by its rows: `.frame(maxWidth: .infinity)` does not cap a wider
  child, so one wide row (date chips, steppers) widens the card past 64…882. Pin the form to the
  card's inner width with `.frame(width:)` and check the widest row on the grid.
- A number written straight into a view or part (`.frame(width: 180)`, `Spacing.m` as a gap)
  stays 13" sized on a smaller window and pushes the row past its card. Write `sizing(180)` (part
  size parameters such as `CrayonTabs(itemSize:)` or `RoundButton.size(_:)` take board values and
  scale themselves; widths a layout computes, such as `TimeField` or `KidFace` sizes, take screen
  points, and each parameter's doc comment says which); `OneScaleTests` draws parts at two scales.
- Row labels in body type ("Arrive by") wrap in the 104–232 label column. Use caption labels on
  one line, as C2 and S2 do.
- A second gesture on a view that has `onLongPressGesture` (a `DragGesture(minimumDistance: 0)` to
  learn where the press began) takes the touch from the long press. Read the press location from
  a parent container in `.global` space, less `sizing.bleed` (the paper left of the board frame).
  Check the clock hold on the iPad after any gesture change.
