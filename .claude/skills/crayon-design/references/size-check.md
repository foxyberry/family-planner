# Size check: 13" → 11" → mini

Run the same list on every iPad, largest first. A rule is right only when it holds on all of
them, so don't fix one size at a time.

The iPads and their scale are in `scripts/scale.py` (it prints s for each). Read the real `safe.top` on each device first; if it differs, every y shifts.

## Steps
1. Use `scripts/scale.py` to work out the expected values of the parts on the risk list below.
2. Capture each screen and state on the list: device or simulator screenshots, landscape, fake
   names only, nothing saved.
3. Compare each capture with the expected values and the risk list.
4. Report each difference as: board id · what you see · measured pt vs expected · a crop.
5. Fix rules first (spec **Part floors**), then code. A per-screen workaround is a sign a rule is
   missing.

## Known risks (check these first)
1. **Labels at caption 24 in a label column that scales.** "Arrive by", "Goes to" and "Face,
   colour" can touch or overlap their controls. The label column may grow; it must never squeeze.
2. **Body and caption both at 24** flatten two-line rows (G8, S2s list, G6 Children). Report
   whether they still read.
3. **Kid targets under the kid floor** (A2 slide and check circles, A1 kid row, A3 medal, E1).
4. **Clipping or "…" on one-line text**:
   - header tab rows;
   - day-type tabs;
   - "Bus 12 · leave 7:05 · 2nd 34" rows;
   - "2nd choice · 34 › 33";
   - A2 bubbles.
5. **Clock hub text in a smaller hub** (G1 drag readout, G1g, hour labels).
6. **The keyboard covering a focused field** (G4, C3, S2s / G7 search with its list).
   Also with a floating keyboard and a hardware keyboard: every screen keeps its normal look (spec
   **Keyboard**).
7. **Bottom stacks** (G1 hint + "Changes start tomorrow." + Save) and the G1f new-slice card.
8. **Cards that hug their content and ConfirmCards** (C3x, G1d, Starts on, the Bring picker
   with More).
9. **Paired rows that stack on the mini**: the G1 slice-card start → end pair is expected to
   stack there (see **Part floors**, G1 worked example).

## Screens and states
✱n = check against risk n.

**Kid**
- A1:
  - morning before leave, both kids ✱3 ✱5;
  - A1b, before an outing ✱3;
  - A1n, night;
  - E1, one kid;
  - E3 / E3b, weekend and Sunday.
- A2:
  - live with a faded 2nd choice, direct and changing ✱4;
  - timetable look;
  - Bring checks ✱3.
- A3 / A3r: medal and ready ✱3.

**Grown-up**
- G0: pencil way in.
- G1:
  - idle;
  - dragging (hub readout) ✱5;
  - G1c slice card ✱9;
  - G1d leave card ✱8;
  - G1e "+" between;
  - G1f new-slice grid ✱7;
  - G1g skipped ✱5;
  - School's card with "Edit School ›".
- G2 / G2b / G2m ✱1, G3 This day, G5 "Change from when?".
- G4:
  - All days ✱1 ✱4;
  - This day with Skip ✱1;
  - keyboard on Arrive by ✱6.
- G6:
  - school kid ✱2 ✱4;
  - at-home kid;
  - Family tab ✱2;
  - the foot.
- G7: Goes to + search list ✱1 ✱6, Preschool rows, Starts on ✱8.
- G8: a long row that wraps ✱2.

**Forms**
- C2: 1st / 2nd pills, Ride 2nd, the link ✱4.
- C2c ✱1.
- C3:
  - Once · Weekly · Monthly ✱4;
  - C3g, C3m;
  - C3x ✱8;
  - Bring picker + More ✱8.
- C4, C5.

**Setup**
- S1, S2 + S2s ✱1 ✱6, S3, S4.

## What right looks like
- Every part sits where the formulas put it.
- Nothing clips, overlaps or scrolls sideways.
- Touch meets the floors in Part floors.
- Type stays at or above its floor.
- Spare width goes where the spec's Grown-up form layout says.
- Out of scope until decided: portrait and split view (see `hig-exceptions.md`, Open).
