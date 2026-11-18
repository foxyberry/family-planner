---
name: screen-layout
description: Use when placing parts on a screen in ios/Features or ios/AppCore from a board's redlines (docs/superpowers/layout/<board>.json), writing or changing a <Screen>Layout model, sizing a grown-up form card or its rows, adding a gesture to a screen, or when a screen on the iPad looks shifted, too wide, wrapped or unresponsive to a hold. Not for sizes or floors themselves (crayon-design) or reducers and State (tca-feature).
metadata:
  version: 0.1.0
  status: experimental
---

# Screen layout

Screens are placed from the board, not stacked by eye, so the four iPads keep the board's lines.

## Place a screen
1. Take the screen's redlines from `docs/superpowers/layout/<board>.json` (ask the design session
   if a board is missing).
2. Write a `<Screen>Layout` model (rects, lines and baselines through `Sizing`), and place every
   part with `place(_:)`, `place(left:baseline:)`, `place(right:baseline:)` or `place(topLeft:)`.
3. Parts carry no outer padding: a part's visible edge is its frame.
4. Add a layout test that checks the shared lines on the four iPads, then look at the screen on
   the iPad with `GRID=1` (bazel-ios).
5. Kid screens fill the window and keep the status bar visible with its band (y 0–24) empty.

## Common mistakes
- A grown-up form card sized by its rows: `.frame(maxWidth: .infinity)` does not cap a wider
  child, so one wide row (date chips, steppers) widens the card past 64…882. Pin the form to the
  card's inner width with `.frame(width:)` and check the widest row on the grid.
- Row labels in body type ("Arrive by") wrap in the 104–232 label column. Use caption labels on
  one line, as C2 and S2 do.
- A second gesture on a view that has `onLongPressGesture` (a `DragGesture(minimumDistance: 0)` to
  learn where the press began) takes the touch from the long press. Read the press location from
  a parent container in `.global` space. Check the clock hold on the iPad after any gesture change.
