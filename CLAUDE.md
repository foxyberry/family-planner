# Family Planner

iPad family schedule app. SwiftUI + TCA, Swift 6, Bazel 8.8.2 + Makefile (no Xcode GUI). Public repo.
Monorepo: `ios/` today; other parts (backend, web) go next to it later.

## Privacy (public repo)
- Never put real personal data in code, defaults, tests, previews, docs, commit messages, or PR/issue text:
  home location, bus stop IDs or routes, children's names/ages/schools, API keys. Use fake values
  (stop `12345`, `Example Primary School`, `Kid A`).
- Real values live only in git-ignored files: `docs/private/`, `.private-terms`, `LocalConfig.*`, `user.bazelrc`.
- If gitleaks or the private-term check blocks you, replace the data. Never bypass (`--no-verify`).
- Design doc and research: `docs/private/` (git-ignored). Do not quote them in tracked files or @-import them.
- Screen specs come from the design session; `docs/superpowers/specs/` copies must match its file.
  Diff them before building or changing a screen, and copy changes in first.
- Publishing text (commit/PR/issue bodies): pass literal text or `--body-file <file>`; shell expansion is blocked.

## Machine limits (8 GB Mac)
- One Bazel build/test at a time, one simulator. `make sim-stop` when done.
- `make run` builds first, then boots the simulator. Shut down idle Bazel servers of other projects.
- Check screens on the iPad (`make device`), never the dev simulator; for tap or Face ID states,
  ask the user or add a launch flag.
- Local memory caps live in `user.bazelrc` (copied from `user.bazelrc.example`); CI does not use them.

## Commands
make setup | build | run | device | test | test-one | snapshots | snapshots-record | art | lint | fmt | xcodeproj | sim-stop | clean
Single test target (same flags as `make test`, keeps caches warm):
`make test-one TARGET=//ios/AppCore/Tests:AppCoreTests`. Plain `bazel test` skips `ios/.bazelrc`.
Guard tests: `for t in scripts/tests/*-test.sh; do bash "$t"; done` (the pre-push hook runs them when guards change).

## Module rules
- `ios/App`: only `@main` and `AppDelegate.bootstrap` (inject live clients, one line each).
  Keep it under 20 code lines, not counting imports.
- Screens, state and lifecycle live in `ios/AppCore` (and later `ios/Features/*`) as TCA reducers;
  lifecycle callbacks become actions (`AppDelegateBase`, `AppScene`).
- Views only render State and send actions. Decisions, copy, date maths, parsing and picking items
  live in the reducer, State computed properties or tested model functions. Views never read
  `@Dependency` (it returns the default, not the store's value) or `Calendar.current`/`Date()`.
- Features depend on `ios/Clients/*` interfaces only; `*Live` modules are visible to `//ios:__pkg__`
  and their own `Tests` package only. Live values read `\.date`/`\.calendar` at call time, never
  take a clock from `bootstrap`.
- Every Swift module uses `fp_swift_library` (Swift 6 mode); tests use `runner = "//ios:test_runner"`.
- `ios/Domain`: pure rules (Foundation and `//ios/Strings` only): kids, routines, schedule items,
  `DayPlanner`, `SeriesEdits`, copy formats. Screens: `ios/Features/Home` (kids' clock), `ios/Features/Grownup` (Our day, List, Settings, editors),
  `ios/Features/Setup` (first-run S1–S4).
- Outside data (time, calendar and time zone, locale, device, bundle, settings, launch arguments)
  comes only through dependencies (`\.date`, `\.calendar`, `\.continuousClock`, clients), read in
  reducers or Live values; the reference time zone is set once in `bootstrap`.
  `scripts/check-dependencies.sh` blocks globals (`Date()`, `Calendar.current`, …) and views reading
  `@Dependency`. Days are `Day` values and minutes after midnight (0–1440). Elapsed time counts
  clock ticks, never `date` differences. Tests pin `Asia/Singapore` and a fixed date.
- New screens, reducers and services: follow the `tca-feature` skill.
- The app starts empty and runs first-run setup (S1–S4); `ScheduleStoreLive` never seeds or wipes.
  `SeedData` (Kid A / Kid B) is only for tests, previews and the debug menu's "Load sample family".
- Grown-up screens: hold the clock 2 s, then Face ID (no passcode). An iPad without Face ID set up
  gets an "Enter" button (the hold is the gate).
- `ios/DebugTools`: debug builds only (`#if DEBUG` in every file). Floating bubble + menu: time
  machine (feeds `\.date`; `make run NOW=2026-11-09T07:30 SPEED=60`), layout grid, flags
  (Skip Face ID, simulator only), "Load sample family" (overwrites after a confirm). Debug links
  `familyplanner://s1`…`s4` open setup with the sample family; `f1`…`f5`, C3's cards. On a real iPad the menu opens only after Face ID (the bubble sits over kids'
  screens). New developer switches go here, never into release code paths. System UI is
  fine there; product screens still use only `DesignSystem`.

## Design system (crayon)
- Screens use only `DesignSystem` tokens, parts and frames. No color hex, font size numbers or
  (in kid screens) `ScrollView` outside the part files (`scripts/check-kid-screens.sh` enforces the last).
- A new part goes into `ComponentGallery` and `ComponentSnapshotTests` first.
- Every crayon shape has a fixed seed per part (`CrayonStyle.Seed`). Any `Canvas` other than
  `CrayonSurface` needs a `// bleed-ok:` note (a Canvas clips crayon wobble; `check-crayon-canvas.sh`).
- Pictures only through `KitIcon(slot)`, so kid drawings can replace them later.
- Copy only through `L10n.tr("key")` and `ios/Strings/Localizable.xcstrings`; `scripts/check-strings.sh` enforces it.
- Playpen Sans has no arrows or ticks (→ ← ✓). The system fallback for them differs between
  iOS versions (snapshots break on CI), so draw them with a part or symbol, never in text.
- Public pictures come only from `make art`; never hand-edit generated SVGs. The school mascot
  `wolfie` is public (user's choice, 2026-11-08); the real home drawing lives in git-ignored
  `ios/KitArt/Private/` (`make art-private`).
- Snapshots (tag `snapshot`) are not part of `make test` or CI: run `make snapshots` whenever you
  change DesignSystem, KitArt or a screen. `make snapshots-record`, then open the PNGs and compare
  with the design boards before committing. Diffs stay in local `__Diffs__`.

## Git flow
- `feature/*` from `develop`, PR into `develop`. `release/*` and `hotfix/*` go to `main`.
- English conventional commits. Ask before pushing. This repo's git flow overrides generic
  branch-finishing skills. See the `git-flow-delivery` skill.

## Versions
Bazel 8.8.2; rules_apple 4.3.3, rules_swift 3.6.0, apple_support 1.24.5,
rules_swift_package_manager 1.25.0, rules_xcodeproj 3.5.1; TCA 1.26.2. Record bumps here.

## Known gotchas
1. `repo_name` is mandatory for apple/swift deps in MODULE.bazel.
2. `apple_cc_configure` must reference `@build_bazel_apple_support`.
3. `.buildifier.json` `warnings` must be a string.
4. Resolve simulator UUIDs by name + OS; never hardcode.
5. rules_swift_package_manager must stay >= 1.19: older versions compile Swift packages with the
   app's iOS 26 minimum and break swift-perception's obsoleted back-ports.
6. `bazel build //ios/Clients/X` alone compiles for the macOS host; check iOS through app or test targets.
7. The xctestrun runner takes `--ios_simulator_device/--ios_simulator_version`, not `--test_arg=--device_type`.
8. TCA TestStore: assert pushed stack elements with `$0.path[id: 0] = ...`, not `append`.
9. `Package.swift` needs `swift-tools-version: 6.2` for `.iOS(.v26)`.
10. Project hooks in `.claude/settings.json` load when a session starts; restart to pick up changes.

## Agent harness
- `AGENTS.md` is a symlink to this file. Edit `CLAUDE.md`, never the link.
- Skills in `.claude/skills` (`.agents/skills` links there): `git-flow-delivery`, `bazel-ios`, `tca-feature`, `skill-retro`.
- Lessons: append one line to `.claude/lessons.md` as soon as a mistake's cause is known; the
  `skill-retro` skill moves them into guards, this file or skills (a session-start note says when 5+ wait).
  `bash scripts/check-skills.sh` checks skills, this file's length and the inbox.
- Hooks block private terms in file writes and in commit/tag/PR/issue/release text.
- Git hooks (`.githooks`, enabled by `make setup`): pre-commit (gitleaks + terms on staged lines),
  commit-msg, pre-push (gitleaks + terms on every new commit, ref and tag; `make lint` on Bazel
  changes; guard tests on guard changes).
- Show the command and its output as evidence before saying a build or test passed.
