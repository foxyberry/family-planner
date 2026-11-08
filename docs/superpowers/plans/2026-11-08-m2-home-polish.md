# Home polish (build step 2) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the kids' home screens (A1, E1, E3, E3b) to the boards: every time with am/pm, the picture size and radius rules, the `KidScreen` frame, the night look with the sky switch, and the M2 motion (new-slot hop, on-the-hour pulse, idle wink).

**Spec:** `docs/superpowers/specs/2026-11-07-m2-screens-spec.md` — A1 (Pie clock, Hub text, Right panel, States), E1, E3, E3b, A1n, Sky switch, Motion. Backlog build step 2.

**Not here:** picture rigs playback (step 3), C6 (step 4), missions (step 5), "Bed in" / "Tomorrow" on the night panel (needs M3 leave times; the night panel keeps the day panel's rows).

## Global Constraints
- Every time on a screen is 12-hour with a lowercase "am"/"pm"; a range in one half puts it once at the end ("3:30–4:30 pm"); a range across halves keeps both ("7:30 am–3:00 pm"). Video lengths are not times.
- Views only render State. Strings, times, night/day and which picture to show are decided in reducers, State or tested model functions (`tca-feature`).
- Time from `\.date` / `\.continuousClock` only; tests pin `Asia/Singapore` and a fixed date that is not a holiday (10 Nov 2026 is a Tuesday school day).
- New parts go into `ComponentGallery` and `ComponentSnapshotTests` first; colours only from `DesignSystem` tokens.
- Reduce Motion: each animation has the fallback from the Motion table.
- Check on the iPad with `make device` (cable) and look at `bazel-device/screen.png`.

## Review Focus
- 6:52 am Tuesday: "Tuesday / Breakfast / until 7:30 am"; Next "School 7:30 am–3:00 pm".
- 7:20 pm: night look (evening routine started at 7:15 pm); 6:31 am: day again.
- Sky switch tap at 3 pm → night until the next planned change (evening routine), then the plan wins again.
- A 45-minute slot shows a 56 picture at 0.8R; a 20-minute slot shows none.

---

### Task 1: Times with am/pm everywhere
**Files:** `ios/Domain/Formatting.swift`, `ios/Features/Home/HomeModel.swift`, `ios/Features/Home/HomeView.swift`, `ios/Features/Grownup/HubModel.swift`, `ios/Features/Grownup/FormPreview.swift`, `ios/Features/Grownup/ItemForm.swift`, tests next to each.
**Interfaces:**
- `TimeText.range(_ start: Int, _ end: Int) -> String`: "3:30–4:30 pm", "7:30 am–3:00 pm"; 1440 is "12:00 am".
- `NextRow.detail` (first row: range; second row: start with am/pm) built in `HomeModel`, so the view prints it as is.
- `TimeText.clock` stays only for places that are not shown times (none on screens after this task).
- [ ] Tests: `testRangeSameHalfPutsPeriodOnce`, `testRangeAcrossHalvesKeepsBoth`, `testMidnightIsTwelveAm`, `testNextRowsCarryTheirDetail`, hub rows in Grownup with am/pm.
- [ ] Implement; replace every on-screen `TimeText.clock`.
- [ ] Run Domain, Home, Grownup tests; commit `feat: every time on screen says am or pm`.

### Task 2: Picture size and radius rules
**Files:** `ios/DesignSystem/Clock/PieClockLayout.swift`, `ios/DesignSystem/Tests/PieClockLayoutTests.swift`.
**Interfaces:** sizes 104 (≥ 3 h), 84 (1–3 h), 56 (30–60 min), none under 30 min; distance 0.68R for 104 and 84, 0.8R for 56; still inside hub + 8 … R − 8.
- [ ] Tests per size and distance, then implement, re-record the clock snapshots and compare with A1.
- [ ] Commit `feat(clock): picture sizes 104 / 84 / 56 at 0.68R and 0.8R`.

### Task 3: Home in `KidScreen`
**Files:** `ios/Features/Home/HomeView.swift`, `ios/DesignSystem/Screens/KidScreen.swift` (an empty-header form if needed).
- [ ] A1 / E1 / E3 / E3b use `KidScreen` with an empty header; clock area x 0–900, disc centre (448, 528); right panel x 928–1312, y 96–968.
- [ ] Check the layout grid in the debug menu on the iPad; commit `refactor(home): kid screens sit in KidScreen`.

### Task 4: Night look
**Files:** `ios/Domain/DayPlanner.swift` (or a `DayLight` model), `ios/Features/Home/HomeFeature.swift`, `HomeView.swift`, `ios/DesignSystem/Tokens` (night tokens, if missing), gallery + snapshots.
**Interfaces:**
- `DayPlanner.nightStart(template) -> Int?` (first evening-routine slot) and `wake(template) -> Int?`; `isNight(minute:)`.
- `HomeFeature.State.look: Look { day, night }` from the plan, plus the sky-switch override (Task 5).
- [ ] Tests: 19:14 day, 19:15 night, 06:29 night, 06:30 day; weekend template times.
- [ ] Colours from the A1n table; lit paper face on the disc; chalk ticks and labels; plated pictures off the clock; 2 s crossfade.
- [ ] Snapshot `testHomeNight`; commit `feat(home): night look from the evening routine to wake-up`.

### Task 5: Sky switch
**Files:** `ios/DesignSystem/Controls/SkySwitch.swift` (new part: gallery + snapshots first), `HomeFeature.swift`, `HomeView.swift`.
**Interfaces:**
- `SkySwitch(look:, isAnimating:, action:)`; kit slots `skyDay`, `skyDusk`, `skyNight`; 160 × 96 at x 40, y 36.
- `HomeFeature.Action.skySwitchTapped`; `State.override: Look?` cleared at the next planned change; taps while animating are ignored.
- [ ] Tests: tap at 3 pm → night; at 7:15 pm the override clears; double tap ignored.
- [ ] Animation 1.2 s as specified; Reduce Motion 0.3 s crossfade; haptics; label "Day. Tap for night." / "Night. Tap for day.".
- [ ] Commit `feat(home): sky switch`.

### Task 6: M2 motion
**Files:** `PieClock.swift`, `HomeFeature.swift`, `HomeView.swift`.
- [ ] New slot: picture hop 1 → 1.15 → 1 and hub text slides up, 0.4 s (Reduce Motion: text changes in place). Triggered by a State change of the current slot, tested in the reducer.
- [ ] On the hour: the hand disc pulses once, 0.6 s.
- [ ] Idle wink: after 20 s without a touch the clock's sun or moon blinks, 0.3 s (`\.continuousClock`, tested with a test clock).
- [ ] Commit `feat(home): new-slot hop, hour pulse and idle wink`.

### Task 7: Whole-branch check
- [ ] `make test`, guard tests, `bash scripts/check-skills.sh`.
- [ ] `make device NOW=2026-11-10T06:52`, then `NOW=2026-11-10T19:20`; look at both screenshots against A1 and A1n.
