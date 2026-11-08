# Day templates (Mon–Fri / Sat / Sun) and the new seed — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the school-day / day-off routine model with three day templates per kid (Mon–Fri, Sat, Sun; a weekday school holiday uses Sun), add free time and locked school edges, and switch the seed to the design board values.

**Architecture:**
- **Domain:** gets `DayType` and dated templates (`Routine.from`), so C6 can later save a template "from tomorrow".
- **`DayPlanner`:** picks the newest template whose `from` is on or before the day.
- **Free time:** a real slot kind that the clock draws as plain paper.
- **The live store:** reseeds when its stored seed version is older than `SeedData.version`. The data is fake until M4.

**Tech Stack:** Swift 6, TCA 1.26.2, SwiftData (via JSON payload records), Bazel 8.8.2.

**Spec:** `docs/superpowers/specs/2026-11-07-m2-screens-spec.md` — sections "Seed data in M2", "Schedule model the screens assume", A1 "Pie clock", E3.

## Global Constraints
- Day types are exactly `Mon–Fri`, `Sat`, `Sun`; a weekday school holiday uses `Sun`.
- "Free time" is a real template slot with no picture; drawn as plain paper.
- Priority: just-once > every-week > day template; lower ones are cut around higher ones.
- Sleep across midnight is two slots (0:00–wake, bedtime–24:00).
- Weekend activities are every-week items, never template slots.
- Seed values (public-safe, from the spec tables):
  - **Kid A Mon–Fri:**
    - Sleep 20:00–6:30
    - Breakfast 6:30–7:30
    - School 7:30–15:00 (locked)
    - Snack 15:00–16:00 (play)
    - free 16:00–17:00
    - Play 17:00–18:30
    - Dinner 18:30–19:15
    - Shower 19:15–20:00
  - **Sat/Sun (both kids' weekend shape):** Sleep 20:45–7:30, Breakfast 7:30–8:30, Play 8:30–19:00, Dinner 19:00–20:15, Shower 20:15–20:45.
  - **Kid B every day:** sleep 19:30–6:30, nap 13:00–15:00.
  - **Every-week items:**
    - Swimming Mon+Wed 15:30–16:30, skip holidays on
    - Art club Fri 15:00–16:00
    - Weekend school Sat 9:00–12:00, `actLanguageSchool`, skip holidays off
  - **Just-once:** Birthday, the coming Saturday 14:00–16:00, both kids, star on.
- Time only from dependencies; copy only through `L10n.tr` (titles shown on screen are catalog keys). Guards: `check-dependencies.sh`, `check-strings.sh`.
- Follow the `tca-feature` skill. Tests pin `Asia/Singapore` and a fixed date.

## Review Focus
- A weekday school holiday on a Monday → Sun template, and Swimming (skip holidays on) is hidden, but Weekend school on a Saturday holiday still shows (skip off).
- An existing device store seeded with the old model (dayKind JSON) → reseeded on first load, not a "corrupt store" error.
- Free time between two slots → drawn as paper, hub says "Free time until …" (A1 NOW rule), never a picture.
- A template saved `from` tomorrow → today still uses the old template; tomorrow uses the new one.
- Seed Monday 6:52 → hub "Breakfast" / "until 7:30"; seed Saturday 9:15 → "Weekend school" / "until 12:00".

---

### Task 1: Domain model — DayType, dated templates, free and locked

**Files:**
- Modify: `ios/Domain/Models.swift` (DayKind → DayType, Routine, RoutineBlock, SlotKind)
- Modify: `ios/Domain/DayPlanner.swift`
- Test: `ios/Domain/Tests/DayPlannerTests.swift`

**Interfaces:**
- Produces:
  - `public enum DayType: String, Codable, CaseIterable, Sendable { case weekday, saturday, sunday }`
  - `DayPlanner.dayType(on: Day, holidays: Set<Day>, calendar: Calendar) -> DayType`: Mon–Fri → `.weekday` unless the day is a holiday, then `.sunday`; Sat → `.saturday`; Sun → `.sunday`.
  - `DayPlanner.isDayOff(on:holidays:calendar:) -> Bool`: weekend or holiday (E3 layout).
  - `Routine { kid: Kid.ID; dayType: DayType; from: Day; blocks: [RoutineBlock] }`
  - `RoutineBlock { …existing…; isLocked: Bool = false }`
  - `SlotKind.free`
  - `DayPlanner.template(for kid: Kid.ID, on: Day, routines: [Routine], holidays:calendar:) -> Routine?`: the newest `from <= day` for that day type.
- Remove `DayKind`; update every caller (37 places; `git grep -n DayKind`).

- [ ] **Step 1: Write failing tests**:
  - `testWeekdayHolidayUsesSunday`
  - `testSaturdayAndSundayTypes`
  - `testNewestTemplateOnOrBeforeTheDay` (two weekday routines `from` Nov 1 and Nov 12; Nov 11 → first, Nov 12 → second)
  - `testFreeSlotHasNoPictureButIsASlot`
  - `testIsDayOffOnWeekendAndHoliday`
- [ ] **Step 2:** `make test-one TARGET=//ios/Domain/Tests:DomainTests`. Expected: compile errors (no DayType).
- [ ] **Step 3:** Implement the model and planner. `slots(on:…)` uses `template(…)`. Free blocks become slots with `kind: .free` and an empty `iconName`.
- [ ] **Step 4:** Run the Domain tests. Expected: PASS. Fix the callers (Home, Grownup HubModel, ItemForm) until `make build` passes.
- [ ] **Step 5: Commit** `feat(domain): Mon–Fri / Sat / Sun day templates with dates, free time and locked edges`

### Task 2: New seed values

**Files:**
- Modify: `ios/Domain/SeedData.swift`
- Test: `ios/Domain/Tests/SeedDataTests.swift` (or the seed tests inside SeriesEditsTests)

**Interfaces:**
- Produces:
  - `SeedData.version: Int = 2`
  - `SeedData.routines(from: Day) -> [Routine]`: three templates per kid, `from` = the seed day.
  - `SeedData.items(today:calendar:)`: the four items from the Global Constraints, ids fixed (`5EED…`).

- [ ] **Step 1: Write failing tests**:
  - `testMondayAt652IsBreakfastUntil730`: slots for Kid A on Monday Nov 9 2026, `DayPlanner.now(at: 412)` current = Breakfast, end 450
  - `testMondayAfterSchoolShowsSnackSwimmingFree`: 15:00–15:30 Snack, 15:30–16:30 Swimming, 16:30–17:00 free
  - `testSaturdayAt915IsWeekendSchoolUntilNoon`
  - `testWeekdayHolidayHidesSwimming`
  - `testKidBNapsAndSleepsAt730pm`
- [ ] **Step 2:** Run the Domain tests. Expected: FAIL (old seed).
- [ ] **Step 3:** Implement the seed. Titles are catalog keys rendered through `L10n.tr`; follow how the current seed titles reach the screen. If seed titles are data, keep them as data, and note the ruling.
- [ ] **Step 4:** Run the Domain, Home and Grownup tests; update expectations that encoded the old seed (Art Thu → Art club Fri, etc.). Expected: PASS.
- [ ] **Step 5: Commit** `feat(domain): seed matches the design boards (Mon–Fri, weekend, Kid B nap)`

### Task 3: Live store reseeds old data

**Files:**
- Modify: `ios/Clients/ScheduleStoreLive/ScheduleStoreLive.swift`
- Test: `ios/Clients/ScheduleStoreLive/Tests/ScheduleStoreLiveTests.swift`

**Interfaces:**
- Consumes: `SeedData.version`, `SeedData.routines(from:)`
- Produces: `meta:seeded` stores the seed version; a lower version, a missing version, or a routine record that fails to decode → delete all records and seed again.

- [ ] **Step 1: Write failing tests**:
  - `testOldSeedVersionIsReplaced`: write records as version 1 (old routine JSON with a `dayKind` field), then load → new templates
  - `testCurrentSeedVersionKeepsUserItems`
- [ ] **Step 2:** Run the store tests. Expected: FAIL.
- [ ] **Step 3:** Implement the version check in `seedIfNeeded`.
- [ ] **Step 4:** Run the store tests. Expected: PASS.
- [ ] **Step 5: Commit** `fix(store): reseed when the stored seed is older than the app's`

### Task 4: Clock draws free time as paper; slot styles

**Files:**
- Modify: `ios/DesignSystem/Tokens/ClockSlot.swift`, `ios/DesignSystem/Clock/PieClock.swift`, `ios/Features/Home/HomeModel.swift`
- Test: `ios/Features/Home/Tests/HomeModelTests.swift`, `ios/DesignSystem/SnapshotTests/ComponentSnapshotTests.swift`

**Interfaces:**
- Produces: `ClockSlotStyle.free`: no fill, no picture; the hub NOW rule says "Free time" / "until …" for a free slot, exactly as for a gap.

- [ ] **Step 1: Write failing tests**:
  - `testHubSaysFreeTimeForAFreeSlot`
  - `testFreeSectorHasNoPicture`
  - a snapshot `testPieClockFreeSlot`
- [ ] **Step 2:** Run them. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** `make snapshots-record`; open the new or changed PNGs and compare with board A1. `testPieClockSeedDay` changes with the new seed.
- [ ] **Step 5: Commit** `feat(clock): free time is plain paper`

### Task 5: Whole-branch check and device look
- [ ] `make test` (all green; no other simulator booted), the guard tests, `bash scripts/check-skills.sh`.
- [ ] `make device NOW=2026-11-09T06:52`: the user compares the iPad with board A1.
