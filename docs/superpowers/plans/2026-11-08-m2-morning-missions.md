# Morning missions (build step 5, the MVP) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Each morning the kids see the way to their next outing and their missions; tapping a mission ticks it, "All done!" marks a kid ready, and grown-ups edit the missions in C5. This completes the MVP ("see today's schedule on this iPad, and do today's missions").

**Spec:** `docs/superpowers/specs/2026-11-07-m2-screens-spec.md` — "MVP data: missions, trips, done state", A1 "Mission morning", "A2-MVP", "C5"; boards A1-MVP, A2-MVP, A2-MVP-w, C5, 0c2.

## Global Constraints
- Missions: `Mission { id, kid, name, picture, order }`, morning only, at most 8 a kid, names at most 14 characters (C5).
- An outing is anything with a `Trip { way, leaveBefore }` (template slot, every-week or just-once item); leave = start − leaveBefore; the clock still draws from the start. Trips come from the seed only in the MVP (editing is N1). Shuttle stays hidden until N1b.
- Done state per kid per date (`doneMissionIds`, `ready`), resets at midnight, kept 14 days, keyed by mission id.
- Kids are never locked: "All done!" is always active; missions only help. No medals, no "On time", no live data (N1 / N2).
- Mission morning: from the earliest kid's wake-up until 12:00 pm; then home goes back to the now/next rule.
- Every time with am/pm; views only render State; new parts go to the gallery and snapshots first; kid screens never scroll ("+n" pages).

## Review Focus
- Tuesday 6:52 am: home shows "School in", the bus picture and "38 min"; "Missions →" opens A2-MVP with the road to school, the bus placed by the clock, "School at 7:30 am · by bus · timetable".
- Tick missions; "All done!" turns Kid A "Ready!" and chooses Kid B; both ready → "Back to the clock".
- Saturday 8:00 am: the strip shows weekend school by car with "Home" on the stem and no stops.
- After 12:00 pm: no "Missions →".
- C5: add a 7th and 8th mission, "8 is the most", rename keeps its tick, remove asks first, drag ≡ reorders.

---

### Task 1: Missions, trips and done state (Domain)
**Files:** `ios/Domain/Models.swift`, `ios/Domain/Missions.swift` (new), `ios/Domain/SeedData.swift`, `ios/Domain/DayPlanner.swift`, tests.
**Interfaces:** `Mission`, `Trip` (`Way`: walk, bus, car, taxi, shuttle; `leaveBefore`), `RoutineBlock.trip`, `ScheduleItem.trip`, `Slot.trip`; `MissionDay { kid, date, done: Set<Mission.ID>, ready }`; `DayPlanner.nextOuting(slots:, minute:) -> Outing?` (the slot, leave minute); `MissionMorning.isOn(minute:, wakes:)`; seed missions and trips; `SeedData.version = 3`.
- [ ] Tests: seed trips give leave 7:25 am (Tue) and 8:35 am (Sat); an outing that has started is skipped; no trip → no outing; morning window from the earliest wake to noon; mission rules (8 max, 14 characters).
- [ ] Commit `feat(domain): missions, trips and the morning window`.

### Task 2: Store missions and done days (ScheduleStore)
**Files:** `ScheduleStore.swift`, `ScheduleStoreLive.swift`, tests.
**Interfaces:** `ScheduleSnapshot.missions`; `saveMissions([Mission])` (whole list for a kid: add, rename, reorder, remove); `missionDay(kid, date)`, `saveMissionDay(MissionDay)` keeping 14 days.
- [ ] Tests: seed missions load; reorder and remove; a done day round-trips; days older than 14 are dropped; an old store reseeds (version 3).
- [ ] Commit `feat(store): missions and mission days`.

### Task 3: Mission morning on home (Home)
**Files:** `HomeFeature.swift`, `HomeModel.swift`, `HomeView.swift`, tests.
- [ ] `State.isMissionMorning`, `State.outing` (Kid A's next outing within 3 h), "{Place} in" + way picture 80 + `TimeLeft`; "Missions →" `InkButton` with `MarkerIcon(.arrowRight)`; action `missionsTapped` (the app opens A2-MVP).
- [ ] Tests: window edges (wake, 11:59 am, noon); outing beyond 3 h → Next row; started outing skipped.
- [ ] Commit `feat(home): mission morning with the next outing`.

### Task 4: A2-MVP missions screen (new feature `ios/Features/Missions`)
**Files:** `MissionsFeature.swift`, `MissionsView.swift`, `WayStrip.swift` (part, gallery + snapshot), tests; app navigation.
- [ ] Header (back, "Good morning!", "{Place} in" + "{n} min"); way strip (home and destination stems, crayon road, mover by the clock, `CrayonCard`-like card); kid list (ring 76 + face, `KidBand` on the chosen kid); chosen kid's name + "leave at"; mission circles (6 a kid, fold done into one ✓ circle, "+n" page); "All done!" pill → "Ready!", next unfinished kid, "Back to the clock".
- [ ] Tests: toggle and untoggle; All done chooses the next kid; everyone ready; the first unfinished mission is bold; paging with 8 missions.
- [ ] Commit `feat(missions): A2-MVP morning missions`.

### Task 5: C5 Morning missions editor (Grownup)
**Files:** `MissionEditorFeature.swift`, `MissionEditorView.swift`, hub rows (C1 More → Morning missions, E6 Cards), tests.
- [ ] Rows with ≡ drag reorder, "+ Add a mission (n of 8)", the editor card (name max 14, picture, Remove asks first, Save off while empty), kid tabs, Kid B note, Done.
- [ ] Commit `feat(grownup): C5 morning missions`.

### Task 6: Whole-branch check
- [ ] `make test`, guard tests, `make lint`; snapshots against A1-MVP, A2-MVP, A2-MVP-w, C5.
- [ ] `make device NOW=2026-11-10T06:52` and `NOW=2026-11-14T08:00`.
