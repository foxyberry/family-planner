---
name: tca-feature
description: Use when adding or changing a screen, reducer, State, model or view in ios/Features or ios/AppCore, adding a new service, client, system framework, network API or persisted store under ios/Clients, deciding where a piece of logic or copy belongs, or when check-dependencies.sh or check-kid-screens.sh blocks a push.
metadata:
  version: 0.3.0
  status: experimental
---

# TCA feature

## Overview
Every layer has one job, and the outside world reaches the app only through dependencies. Then the
reference time zone, the time machine and tests can replace any of it in one place.

| Layer | Module | Holds | Never |
|---|---|---|---|
| Domain | `ios/Domain` | pure models and rules (`DayPlanner`, `DayText`) | imports beyond Foundation, globals |
| Port | `ios/Clients/X` | `@DependencyClient` interface, `testValue`, in-memory `previewValue` | `liveValue`, system frameworks |
| Adapter | `ios/Clients/XLive` | SwiftData, Face ID, files, network; reads `\.date`/`\.calendar` at call time | visibility beyond `//ios:__pkg__` and its tests |
| Feature | `ios/Features/*`, `ios/AppCore` | reducer (flow), State (incl. computed copy), model functions | globals, Live imports |
| View | `*View.swift` | layout, parts, bindings that forward to State or actions | decisions, copy choices, date maths, `@Dependency` |
| App | `ios/App` | `@main`, one injection line per Live value | logic |

## New service
1. `ios/Clients/X/X.swift`: `@DependencyClient public struct X: Sendable` with
   `@Sendable` closures, `TestDependencyKey`, a `previewValue` with fake data seeded from `\.date`, and
   `extension DependencyValues { var x }`.
2. `ios/Clients/XLive/XLive.swift`: `extension X { static func live(...) -> X }`. Pass only what
   is fixed for the app's life (a folder, a key). Read time and calendar inside the closures.
3. BUILD: `XLive` visible to `//ios:__pkg__` and `//ios/Clients/XLive/Tests:__pkg__`. A target that
   needs this Mac's state (profiles, keychain) is tagged `manual`.
4. Tests for the Live value in `XLive/Tests`, run under `withDependencies` (override `invokeTest`).
5. One line in `AppDelegate.bootstrap`.

## New screen or change
1. Write the reducer test first (TestStore, pinned `\.calendar`, `\.date`, clients).
2. State holds everything the view shows: rows, titles, captions, enabled flags, tab items. Add
   computed properties or pure model functions with unit tests. Example: `State.canSave`,
   `State.confirmAcceptTitle`, `HubModel.sections(kid:routines:)`.
3. Every tap is one action; the reducer decides (`.skipRowTapped`, not a view-side choice between
   two actions). No string round-trips or force-unwraps for ids.
4. The view renders State with DesignSystem parts and tokens only. Kid screens use `KidFullScreen`;
   a new kid feature folder goes into `KID_DIRS` in `scripts/check-kid-screens.sh`.
5. A new part goes into `ComponentGallery` and `ComponentSnapshotTests` first.
6. Layout comes from the board, not from stacks: take the screen's redlines from
   `docs/superpowers/layout/<board>.json` (ask the design session if a board is missing), write a
   `<Screen>Layout` model (rects, lines and baselines through `Sizing`), and place every part with
   `place(_:)`, `place(left:baseline:)`, `place(right:baseline:)` or `place(topLeft:)`. Parts
   carry no outer padding: a part's visible edge is its frame. Add a layout test that checks the
   shared lines on the four iPads, then look at the screen on the iPad with `GRID=1` (bazel-ios).
   Kid screens fill the window and keep the status bar visible with its band (y 0–24) empty.
7. Every board of a screen family (A1, A1m, A1n, E3, …) is one State case (`HomeFeature.KidABlock`)
   with a test; capture each on the iPad at a time that hits it. A view that falls through to
   nothing is a missing case.
8. "As on <board>" in the spec: find that board's rule (spec, backlog, motion table) before building.

## Where does it go?

| It is... | Put it in |
|---|---|
| the current time, today, weekday, minute of day | the reducer via `\.date`/`\.calendar`, stored in State |
| text that depends on state ("Edit Swimming", "Locks in 0:30") | a State computed property or a Domain formatter |
| a rule shared by screens (minute of day, day names) | Domain, with a unit test |
| which kid, item or row is shown | State or a model function |
| sizes, stacks, colours from tokens, animation progress | the view |
| any word a person reads (labels, captions, accessibility text) | a key in `ios/Strings/Localizable.xcstrings`, read with `L10n.tr("area.thing")` |

## When a guard blocks

| Message | Fix |
|---|---|
| `global read in …` | read it in the reducer from a dependency; store the result in State |
| `view reads @Dependency in …` | move the value into State (a view gets the default, not the store's value) |
| `kid screen scrolls` | cap the list with `Capped` |
| `hard-coded copy in …` / `key not in the catalog` / `unused catalog key` | add the key to the catalog and use `L10n.tr`; remove keys nothing uses; a non-copy literal (bundle name) ends with `// copy-ok: <reason>` |

## Common mistakes
- Passing `Date()` or `Calendar.current` into a Live value from `bootstrap`: it then ignores the time machine and the reference time zone.
- Deciding in the view because "it is just one ternary": the choice is then untested, and it drifts from the reducer's guard.
- Copy assembled in views: it cannot move to the String Catalog.
- Mapping one enum onto another with `X(rawValue: y.rawValue)!` (a Domain kind onto a DesignSystem style): a new case then traps on screen, not in a build. Map with a `switch` or a fallback, and test every `allCases` value.
- A grown-up form card sized by its rows: `.frame(maxWidth: .infinity)` does not cap a wider child, so one wide row (date chips, steppers) widens the card past 64…882. Pin the form to the card's inner width with `.frame(width:)` and check the widest row on the grid.
- Row labels in body type ("Arrive by") wrap in the 104–232 label column. Use caption labels on one line, as C2 and S2 do.
- `TestStore` with `exhaustivity = .off`: each `send` skips the received actions not yet asserted, so `receive` an effect's actions before the next `send`.
- Fixed test dates on a public holiday: 9 Nov 2026 (Deepavali observed) is a Sunday-template day in the app. Check the holiday list before a weekday fixture becomes a "school day" check, on the iPad too.
