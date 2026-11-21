# Size check: one scale, every screen

Every screen is the board times one scale `s` (spec **Sizing: one scale, no floors**). The board
is right at s = 1, so a size check mostly asks one question: did every part scale by the same s?

The iPads and the iPhone Duo inner screen, with their s, are in `scripts/scale.py`. Read the real
`safe.top` on each device first; if it differs, every y shifts.

## Steps
1. Check the screen at s = 1 (13") against its board and its layout JSON.
2. Check it once more on the smallest screen (the Duo inner screen, or the mini simulator):
   every part should be its board size × s, in the same place × s.
3. Report each difference as: board id · what you see · measured pt vs board × s · a crop.
4. Fix the board or the rule first, then the code. A per-screen size is a sign of a bug: no
   screen sets its own size.

## Known risks (check these first)
1. **A part that didn't scale**: a fixed number left in code, a floor, a `max(…)`, or
   `scaleEffect` on a whole screen (it blurs text).
2. **Leftover space**: it is paper (night sky at night), centred, with nothing on it.
3. **Touch**: a tap hits only the visible box; a drag on a part with no drag of its own grabs the nearest handle of its named area only (the clock ring, a slider's track; spec **Sizing → Touch**). No tap area bigger than what is drawn.
4. **Text that wraps** (typed names, " · " value lines): it wraps the same way on every screen,
   since everything scales together. Labels are reworded on the board, never squeezed.
5. **The keyboard covering a focused field** (G4, C3, S2s / G7 search with its list). A floating
   or hardware keyboard keeps the normal look (spec **Keyboard**).

## What right looks like
- Every part is board × s and sits at its board position × s.
- Nothing clips, overlaps or scrolls sideways.
- The leftover space is plain paper.
- Small parts under 44 pt on the Duo inner screen are expected (user decision); they are not a
  finding.
- Out of scope until decided: portrait, and the Duo outer screen (see `hig-exceptions.md`, Open).
