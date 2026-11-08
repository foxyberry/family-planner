# Picture rigs playback (build step 3) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tapping a slot on the kid clock plays its picture once (≤ 1.2 s): rigged pictures move their parts, every other picture hops. A debug-menu slider "Rig scale" (1.0–1.5) checks the size on the iPad.

**Spec:** `docs/superpowers/specs/2026-11-07-m2-screens-spec.md` — "Picture rigs: tap a slot, its picture plays" (boards 0g3 / 0g3b).

**Data (already in the repo):** `ios/KitArt/Resources/KitArt.xcassets/KitRigs.dataset/rigs.json` from `make art`: `default` (whole-picture hop, `px` 14, origin (120, 220)) and `rigs` (29 slots). Each rig has `runs` (`{image: "rig-<slot>-<n>", part}` in draw order, `part: null` = still) and `parts` (`{origin: [x, y], moves: [...]}`) in the 240 box. Moves: `rock(deg, times)`, `bob(px, times)`, `slide(px, times)`, `rise(px)`, `fall(px)`, `press(px, delay)`, `spin(deg)`, `blink`, `flicker`, `twinkle`, and the default `hop(px)`. There is no `scale` key yet: the app's default is 1.5 (spec), and the design session is asked to add it.

## Global Constraints
- Only rigid moves: rotate or move a part whole about its origin; never bend or stretch (the hop's 5 % squash on landing is the one exception, from the spec).
- `scale` multiplies rock, bob, slide, rise, fall, press and hop amounts; spin, blink, flicker and twinkle ignore it.
- A play lasts at most 1.2 s and ends at rest; a second tap during a play is ignored (reducer, `\.continuousClock`).
- A slot whose picture comes from a private override (`BundledKitArt.source == .private`) plays the default hop on the whole picture: the public run images would not match it.
- Reduce Motion: no movement; the tapped slot's outline thickens for 0.3 s.
- Views only render State; the tap's minute → slot lookup is a tested model function. Release builds use the default scale; only debug builds read the slider (`#if DEBUG`, `ios/DebugTools`).

## Review Focus
- Tap the Breakfast slot: the bowl's parts move and stop within 1.2 s; a tap on it again mid-play does nothing.
- Tap a slot with no rig: the whole picture hops 14 × scale and lands with a squash.
- Debug "Rig scale" at 1.0 vs 1.5: the moves visibly shrink and grow.
- Reduce Motion on: only the outline thickens.
- Long-press still opens the grown-up lock after 2 s.

---

### Task 1: Rig model and loader (KitArt)
**Files:** `ios/KitArt/KitRig.swift` (new), `ios/KitArt/Tests/KitRigTests.swift` (new).
**Interfaces:**
- `KitRig: Decodable` (`runs: [Run]`, `parts: [String: Part]`), `Run(image, part?)`, `Part(origin: CGPoint, moves: [Move])`, `Move` enum with associated values for the types above.
- `KitRigs.shared`: decoded once from the `KitRigs` data asset in the KitArt bundle; `rig(for: KitSlot) -> KitRig?`, `defaultHop`, `scale` (json value or 1.5).
- [ ] Tests: decode the bundled file; every rig's run images exist in the catalog; `busSingle` has a body bob and two wheel spins; unknown move types fail loudly in tests.
- [ ] Commit `feat(kitart): rig data model and loader`.

### Task 2: Move timelines (pure)
**Files:** `ios/KitArt/RigMotion.swift` (new), tests.
**Interfaces:** `RigMotion.pose(for: Move, at t: Double, scale: Double) -> Pose` (rotation degrees, offset, scaleY, opacity), t in 0…1 over the 1.2 s play; every move returns to rest at t = 1.
- [ ] Tests per move: rest at 0 and 1; rock peaks at ±deg × scale; spin reaches deg at 1; press waits for `delay`; hop squashes 5 % at landing.
- [ ] Commit `feat(kitart): rig move timelines`.

### Task 3: `RiggedKitIcon` part (DesignSystem)
**Files:** `ios/DesignSystem/Content/RiggedKitIcon.swift` (new), gallery, snapshot of the rest pose (stacked runs equal the picture).
**Interfaces:** `RiggedKitIcon(slot, size, playID: Int, scale: Double)`: stacks the run images (or the whole picture for the default hop) and, when `playID` changes, animates each part with `keyframeAnimator` / `TimelineView` from `RigMotion`, rotating about the part's origin scaled from the 240 box.
- [ ] Gallery: a tap-to-play row of five rigged slots and one default.
- [ ] Snapshot: rest pose of three rigged slots equals `KitIcon` (pixel compare in a test).
- [ ] Commit `feat(design): RiggedKitIcon plays a picture's rig`.

### Task 4: Tap a slot on the clock (Home)
**Files:** `ios/DesignSystem/Clock/PieClock.swift`, `PieClockLayout.swift`, `ios/Features/Home/HomeFeature.swift`, `HomeModel.swift`, `HomeView.swift`, tests.
**Interfaces:**
- `PieClockLayout.sector(at point: CGPoint, in sectors:, radius:, hub:) -> ClockSector?` (between hub and rim only).
- `HomeFeature.Action.slotTapped(start: Int)`; `State.playing: [Int: Int]` (slot start → play id) and `State.playingSlot: Int?`; a 1.2 s clock effect ends the play; taps during a play are ignored.
- `PieClock(..., plays: [Int: Int], rigScale: Double)` passes play ids to each sector's `RiggedKitIcon`.
- [ ] Tests: the hit test (hub and outside return nil); tap → play id up; tap during play ignored; play ends after 1.2 s (TestClock).
- [ ] Reduce Motion: outline 6 → 9 pt for 0.3 s instead.
- [ ] Commit `feat(home): tap a slot to play its picture`.

### Task 5: Debug "Rig scale" slider
**Files:** `ios/DebugTools/DebugSettings.swift`, `DebugMenu.swift`, `DebugModel.swift`, `ios/AppCore` (pass the scale down), tests.
- [ ] `DebugSettings.rigScale: Double?` (nil = the data's default); slider 1.0–1.5 step 0.1 in a "Pictures" section; the home screen reads it through the app root, never `@Dependency` in a view.
- [ ] Tests: default when unset, saved value round-trips.
- [ ] Commit `feat(debug): rig scale slider`.

### Task 6: Whole-branch check
- [ ] `make test` (or the targets touched while the faster-tests work lands), guard tests, `make lint`.
- [ ] `make device`: tap Breakfast, School (wolfie), Swimming, a flag; compare with board 0g3 / 0g3b; Reduce Motion on the iPad.
