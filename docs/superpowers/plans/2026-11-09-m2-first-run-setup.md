# M2 build step 6: first-run setup S1–S4 (plan)

Spec: `2026-11-07-m2-screens-spec.md`, "S1–S4 · First-run setup". Boards: layout v6 `S1`–`S4.json`.
Status: planned. Not started: it changes how the app stores the family (see "Decisions").

## Decisions for the user (before building)
1. **Seeding.** `ScheduleStoreLive` seeds the fake family (`SeedData`) on the first load. Setup needs
   "no family yet" instead. Options:
   - Release builds start empty and show S1.
   - Debug builds keep the seed unless launched with `-fpFirstRun` (or the debug menu's "Start setup").
   The iPad in use keeps its seeded data either way. A store `version` bump would wipe it, so no bump.
2. **School list (S2).** The spec says "Picked from the MOE school list" with a search sheet over a bundled list. Is the
   public MOE list allowed in the repo (licence), or a plain name field first?
3. **Stop check (S3).** It uses `BusClient` `BusStops` with the built-in key. Without the key the stop name stays
   empty and Next stays on (as in C2).

## Shape
- `ios/Features/Setup`: `SetupFeature` holds four steps in one State (S1 kids, S2 school per kid,
  S3 way per kid with a school, S4 summary). Back keeps every value; nothing is saved before Start.
- Views on `GrownupScreen` / `GrownupLayout`. The header has "Step n of 4" and 28 dots, and no lock.
- New store call `saveFamily(kids, routines, busPlans)`: one write, replacing the seed.
- `AppFeature`: on launch, an empty store shows setup full screen; Start saves and opens home (A1, or E1
  with one kid). The debug link `familyplanner://s1` opens setup without saving (review only).
- Tests: reducer per step (Next enabled rules, colour swap, kids without a school skip S3,
  Start saves once), a `SetupLayout` line test, captures on the simulator with the grid.

## Order
1. Store: `saveFamily` + Live + tests; the seeding switch from decision 1.
2. S1 and S4 (no outside data), then S2 (decision 2), then S3 (`BusClient`).
3. App routing, the debug link, captures, retro.
