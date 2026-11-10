# M2 grown-up mode (build row 6d)

Spec: `2026-11-07-m2-screens-spec.md` › "Grown-up mode"; boards G0–G8 (layout v26).
C6 is absorbed into G1, C1 becomes Settings (G6), and a List view (G8) is kept.

## PR 1a: Our day is the way in (G1 header, G8, Undo / Redo)

- After the unlock (2 s hold, debug links) grown-up mode opens on Our day for the first kid; "←"
  leaves grown-up mode. Save stays on the clock.
- Header right end: List (a toggle) · Settings. Leaving the clock with unsaved changes asks first
  (today's confirm card; G1d comes in PR 2).
- G8 List: "Every week" (School, then activities) and "Just once"; rows open the editor; side column
  "Add every week" / "Add once".
- Undo / Redo: `RoundButton` 72 with the new `undo` / `redo` marker glyphs at the clock area's
  bottom right, off at 45 %; `TemplateEdit` keeps a redo stack until the next change or Save.
- Settings opens over Our day on the kid shown (still the C1 look until PR 1b).
- G0's pencil waits for the `pencil` kit picture (design session).

## PR 1b: Settings (G6)

Kid tab: About (Age, Face / colour), School (School, Hours, Terms), Getting there (To school, Home),
Routines (Missions); Family tab: This iPad (lock, live bus, medals). Foot: "School lists · {date}"
and "Data sources". The item lists move out (they are G8).

## PR 2: the day on the clock on real dates (G1, G1c, G1d)

The day button and the G1c picker (two weeks of date chips); template slots get This day / All days
in the slice card (a day change for the routine); School and activities open G4 / G2; G1d "Save the
changes?" (Save / Don't save / Cancel) replaces the leave card.

## PR 3: Edit School (G4)

School as an event on the E5 screen: School (name ›), When, Days, Arrive by + latest, Terms, Going,
Bring, Missions, Medal (on).

## PR 4: Change school (G7)

"Starts on" (Next term / Date) splits the School item; S3 for the new trip; the pending row with
"Pick another school" and "Cancel the change".
