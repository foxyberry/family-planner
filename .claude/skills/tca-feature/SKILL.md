---
name: tca-feature
description: Use when adding or changing a screen, reducer, State, model or view in ios/Features or ios/AppCore, adding a new service, client, system framework, network API or persisted store under ios/Clients, deciding where a piece of logic or copy belongs, or when check-dependencies.sh or check-kid-screens.sh blocks a push.
metadata:
  version: 0.2.0
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
4. The view renders State with DesignSystem parts and tokens only. Kid screens use `KidScreen`;
   a new kid feature folder goes into `KID_DIRS` in `scripts/check-kid-screens.sh`.
5. A new part goes into `ComponentGallery` and `ComponentSnapshotTests` first.

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
