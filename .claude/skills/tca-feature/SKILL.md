---
name: tca-feature
description: Use when adding or changing a screen, reducer, State, model or view in ios/Features or ios/AppCore, adding a new service, client, system framework, network API or persisted store under ios/Clients, deciding where a piece of logic or copy belongs, or when outside_data (SwiftLint), check-view-values.sh, check-journeys.sh or check-kid-screens.sh blocks a push.
metadata:
  version: 0.12.2
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
| View | `*View.swift` | layout, parts, bindings that forward to State or actions | any value of its own: copy lookups (`.tr`), any `??`, placeholder numbers, decisions, date maths, `@Dependency` |
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
1. Write the reducer test first (TestStore, pinned `\.calendar`, `\.date`, clients). A new screen
   or flow gets a journey (`ios/Journeys/Tests`).
2. State holds everything the view shows: rows, titles, captions, enabled flags, tab items. Add
   computed properties or pure model functions with unit tests. Example: `State.canSave`,
   `State.confirmAcceptTitle`, `HubModel.sections(kid:routines:)`.
3. Every tap is one action; the reducer decides (`.skipRowTapped`, not a view-side choice between
   two actions). No string round-trips or force-unwraps for ids.
4. The view renders State with DesignSystem parts and tokens only. Kid screens use `KidFullScreen`;
   a new kid feature folder goes into `KID_DIRS` in `scripts/check-kid-screens.sh`.
5. A new part goes into `ComponentGallery` and `ComponentSnapshotTests` first.
6. Layout comes from the board's redlines: follow the `screen-layout` skill.
7. Every board of a screen family (A1, A1m, A1n, E3, …) is one State case (`HomeFeature.KidABlock`)
   with a test; capture each on the iPad at a time that hits it. A view that falls through to
   nothing is a missing case.
8. "As on <board>" in the spec: find that board's rule (spec, backlog, motion table) before building.

## State shape (views hold no values)
a. `init` builds a complete, renderable State: defaults known up front are initial values, never
   view or copy fallbacks. A field's starting value (default times) is in State from the form's
   start, seeded in the model: a wheel set to the value it already shows sends nothing, so a value
   that only the copy draws never reaches State. Soft placeholder looks are for truly empty inputs only.
b. Values that arrive later (store, network) live in `enum Phase { case loading, ready(Form), failed }`;
   `.loaded` builds the whole `Form` (or `.failed`); form actions before it do nothing. The view
   switches on the phase and draws the form only in `ready` (`ChangeSchoolFeature`, or `store.scope`
   for a Form reducer). No Optional or `??` stands in for "not loaded yet".
c. nil in State means a different UI (card closed, nothing picked), never "show X"; views have no
   `??` and branch with `if let`/`switch`. What a view shows or binds is non-optional (`KitSlot`, `String`).
d. Every form gets a TestStore test of Next/Save with no edits, and one that loading shows no form.

```swift
// Don't: before load, "At home" (stored == nil) beside the school tab (place = .school).
var stored: School?; var place: Place = .school
// Do: nothing is drawn until it is known; then every value is there.
@CasePathable enum Phase: Equatable { case loading, ready(Form), failed }
```

## Where does it go?

| It is... | Put it in |
|---|---|
| the current time, today, weekday, minute of day | the reducer via `\.date`/`\.calendar`, stored in State |
| text that depends on state ("Edit Swimming", "Every Wed") | a State computed property or a Domain formatter |
| a rule shared by screens (minute of day, day names) | Domain, with a unit test |
| which kid, item or row is shown | State or a model function |
| sizes, stacks, colours from tokens, animation progress | the view |
| any word a person reads (labels, captions) | a key in `ios/Strings/Localizable.xcstrings`, read in a State computed property with `strings.tr("area.thing")`; State keeps `public var strings = Localizer.injected` (`\.localizer`, module `Localization`) |
| a value shown before the user picks one (7:30 am, the "now" picture) | an initial value in State (see "State shape") |
| a DesignSystem part's words (back label) | arguments from the caller, which takes them from State |

## When a guard blocks

| Message | Fix |
|---|---|
| `global read` (`outside_data`) | read it in the reducer from a dependency; store the result in State |
| `view reads @Dependency` (`outside_data`) | move the value into State (a view gets the default, not the store's value) |
| `kid screen scrolls` | cap the list with `Capped` |
| `layout literal in a screen` / `pending count too high` | put the row on `FormRow` / `FormLines`, use a `Sizing` token or part variant, place corner controls with `cardCorner`; a row's `height:` / `minHeight:` follows its parts' scaled size (`MinutesStepper.rowHeight`, the sizing field and tab heights); lower `scripts/layout-literals-pending.txt` when a count drops |
| `value in view code` or `view_values` | add a non-optional State computed property (copy via `strings.tr`) and a test; a ternary on `store` or nil becomes a State property or a part's flag (`captionedRow(hasCaption:)`); drop the file from `scripts/view-values-pending.txt` when clean |
| `no journey reaches X` | drive it from a journey (`ios/Journeys/Tests/README.md`); unlist it in `scripts/journeys-pending.txt` |
| `hard-coded copy in …` / `key not in the catalog` / `unused catalog key` | add the key to the catalog and use `strings.tr` in State; remove keys nothing uses; a non-copy literal (bundle name) ends with `// copy-ok: <reason>` |
| `passes n argument(s) but its value has m placeholder(s)` | one key has two meanings: give the new screen its own key |
| `raw text input in …` | use `CrayonField`; a raw `TextField` prompt follows the window's dark scheme |

## Common mistakes
- Passing `Date()` or `Calendar.current` into a Live value from `bootstrap`: it then ignores the time machine and the reference time zone.
- Deciding in the view because "it is just one ternary": the choice is then untested, and it drifts from the reducer's guard.
- Copy assembled or looked up in views: it cannot be swapped or tested. Tests can set `$0.localizer = .keys` to check which key a State picks.
- Reading `@Dependency(\.localizer)` in a State computed property: a view evaluating it gets the default. Store the value (`Localizer.injected`) once.
- Mapping one enum onto another with `X(rawValue: y.rawValue)!` (a Domain kind onto a DesignSystem style): a new case then traps on screen, not in a build. Map with a `switch` or a fallback, and test every `allCases` value.
- `TestStore` with `exhaustivity = .off`: each `send` skips the received actions not yet asserted, so `receive` an effect's actions before the next `send`.
- A debug switch or fixture inside a feature (`#if DEBUG` state, a debug-only action, a board setup in a reducer): it ships in the feature's shape and drifts from the real flow. Give the value as a dependency that `DebugModel.install` swaps (as the time machine swaps `\.date`), keep fixtures in DebugTools, and reach the screen through the app's normal actions. `check-debug-boundary.sh` blocks the rest.
- Fixed test dates on a public holiday: 9 Nov 2026 (Deepavali observed) is a Sunday-template day in the app. Check the holiday list before a weekday fixture becomes a "school day" check, on the iPad too.
- A reducer that resets state on `textChanged`: a `TextField` sends its text again when it loses focus (a card hiding the keyboard), so ignore an unchanged text. Check field-plus-card flows on the iPad.
- `self.property` inside `LockIsolated(...)` in a test: the `Sendable` autoclosure captures `self` and the test does not build. Use statics (`SeedData.kidA.id`) or a local `let`.
