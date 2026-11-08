---
name: bazel-ios
description: Builds, tests, runs and troubleshoots the iPad app with Bazel 8 and the Makefile on an 8 GB Mac - make build/test/run/device/lint/fmt/sim-stop, signed builds on a real iPad, single-target bazel test with simulator flags, user.bazelrc memory caps, one-simulator rule, buildifier, adding Swift packages through Package.swift and MODULE.bazel, rules version bumps, and common Bazel/rules_apple errors. Use when running or fixing builds or tests, editing BUILD.bazel, .bzl, MODULE.bazel, .bazelrc or the Makefile, or when the simulator or Bazel server misbehaves.
metadata:
  version: 0.9.0
  status: experimental
---

# Bazel iOS

## 8 GB rules

- One build or test at a time; one simulator. `make run` builds first, then boots.
- `make test`, `test-one` and `snapshots` shut down other simulators (a dev simulator next to
  the test one makes tests fail) and keep the test one booted: the next run skips a 15-20 s boot. Look at changes on the iPad (`make device`).
- Shut down idle Bazel servers of other projects: `cd <other repo> && bazel shutdown`.
- "Another command is running" means wait; Bazel serializes commands in one workspace.
- If memory pressure stays red during a cold build, set `common --local_resources=cpu=2` in
  `user.bazelrc` (git-ignored; created from `user.bazelrc.example` by `make setup`).
- The test simulator is `BAZEL_TEST_<device>_<os>`; `make run` shuts all simulators down first.
  `make sim-stop` when done. Never address a simulator as `booted`: use its UDID.

## Simulator Face ID (parent mode)

```bash
UDID=$(xcrun simctl list devices booted | grep -o '[0-9A-F-]\{36\}' | head -1)
xcrun simctl spawn $UDID notifyutil -s com.apple.BiometricKit.enrollmentChanged 1
xcrun simctl spawn $UDID notifyutil -p com.apple.BiometricKit.enrollmentChanged   # enrolled
# tap Parent, wait until the Face ID sheet shows, then:
xcrun simctl spawn $UDID notifyutil -p com.apple.BiometricKit_Sim.pearl.match      # matching face
```

A match before the sheet shows does nothing. Easier: debug "Skip Face ID".

## Real iPad (`make device`)

- Works with a free Apple ID (Personal Team). The profile lasts 7 days; run `make device` again
  to renew it. Installing over the old app keeps its data. One device holds 3 such apps.
- `scripts/device-profile.sh` has Xcode create the team profile (throwaway xcodegen stub);
  `//ios:device_profile` finds it in `~/Library`. Team and device IDs never enter the repo.
- `--config=device` (ios/.bazelrc) builds arm64 and selects the profile; plain builds stay unsigned.
- First time on an iPad: pair (`xcrun devicectl manage pair --device <id>`, tap Trust),
  run `make device` once so Settings shows Developer Mode, turn it on and restart, then after
  the first install trust the developer in Settings > General > VPN & Device Management.
- After that first cabled pairing, `make device` also works over Wi-Fi (same network, iPad awake);
  `devicectl` shows it as `localNetwork`. Wake the iPad if it is not found. Wi-Fi installs can
  time out (`tunnel connection failed`); plug in the cable rather than retrying.
- `make device` ends with `scripts/device-check.sh` (needs `pymobiledevice3` and a cable): it fails
  on a crash after launch, tells whether the crashed binary is new, and saves
  `bazel-device/screen.png`. Look at it; "Launched" proves nothing.
- Layout check: `make device NOW=… OPEN=missions GRID=1` opens the screen by deep link with the
  board-line grid on; `pymobiledevice3 developer dvt screenshot x.png`; a part off its line is a bug.

## Commands

| Need | Command |
|---|---|
| Build app | `make build` |
| Build + launch on simulator | `make run` |
| Build + sign + launch on the iPad (cable or Wi-Fi) | `make device` (see Real iPad) |
| Start the app clock at another time (debug builds) | `make run NOW=2026-11-09T07:30 SPEED=60` (same for `make device`), or the debug bubble's Time machine |
| All tests except snapshots | `make test` (override `SIM_DEVICE=... SIM_OS=...`) |
| Snapshot tests | `make snapshots` (see Snapshot tests) |
| One test target | `make test-one TARGET=//ios/<Pkg>/Tests:<Target>` (plain `bazel test` skips `ios/.bazelrc` and loses cache hits) |
| Test log | `bazel-testlogs/ios/<Pkg>/Tests/<Target>/test.log` |
| Force a re-run | `make test TEST_ARGS=--nocache_test_results` (`(cached) PASSED` means it did not run) |
| See what went into a test bundle | `find -L bazel-out/ios_sim_arm64-fastbuild-*/bin/ios/<Pkg>/Tests -name '*.xctest' -path '*archive-root*'` |
| BUILD lint / format | `make lint` / `make fmt` |
| What depends on what | `bazel query 'deps(//ios/AppCore)' --output=label` |
| Xcode (only when needed) | `make xcodeproj` |

## New module

```starlark
load("//ios:build_defs.bzl", "fp_swift_library")

fp_swift_library(
    name = "BusArrivalClient",               # module name = target name
    visibility = ["//ios:__subpackages__"],  # *Live modules: ["//ios:__pkg__"] only
    deps = ["@swiftpkg_swift_composable_architecture//:ComposableArchitecture"],
)
```

Tests live in `<Pkg>/Tests` with an `ios_unit_test` that sets `runner = "//ios:test_runner"`
(reuses one simulator, writes no .xcresult). Pure modules too: `macos_unit_test` measured
slower (xcodebuild start-up 4-9 s per target vs 1-3 s on the booted simulator).

## Resources (pictures, fonts)

```starlark
load("@build_bazel_rules_apple//apple:resources.bzl", "apple_resource_bundle")

apple_resource_bundle(
    name = "KitArtResources",
    bundle_id = BUNDLE_ID + ".kitart",
    infoplists = ["ResourceBundle-Info.plist"],   # must contain CFBundleIdentifier
    resources = glob(["Resources/KitArt.xcassets/**"]),
)

fp_swift_library(name = "KitArt", data = [":KitArtResources"])
```

- The bundle's Info.plist needs `CFBundleIdentifier` set to `${PRODUCT_BUNDLE_IDENTIFIER}`. Without
  it the bundle is copied (Assets.car is there) but UIKit never finds an image in it.
- Find the bundle from code with `Bundle(for: <a class in the module>)`: that is the app in the
  app and the `.xctest` bundle in unhosted tests (`Bundle.main` is the test runner there).
- Optional local-only resources: `glob([...], allow_empty = True)`; an empty bundle builds fine.
- Show catalog pictures with SwiftUI `Image(name, bundle:)`. `Image(uiImage:)` rasterizes the
  asset at its natural size, so preserved vectors blur when scaled up.
- Check a compiled catalog: `xcrun --sdk iphonesimulator assetutil --info <bundle>/Assets.car`.

## Snapshot tests

- `make test` and CI skip them (tag `snapshot`): run `make snapshots` after changing
  DesignSystem, KitArt or a screen.
- Baselines are `data` runfiles of the `ios_unit_test`; the test reads them under
  `$TEST_SRCDIR/_main/<package>/__Snapshots__` (the xctestrun runner forwards `TEST_SRCDIR`).
  Keep PNGs out of resource bundles: rules_apple may recompress them.
- `#filePath` is relative under Bazel, so never let swift-snapshot-testing pick the folder.
- Record: `make snapshots-record` (passes `SNAPSHOT_RECORD_DIR` through `env_inherit`; the run
  reports failures because recording is not a pass). Then `make snapshots` to compare.
- Unhosted tests render SwiftUI fine through swift-snapshot-testing's `.image(layout:traits:)`.
- `.sizeThatFits` proposes a zero size: wrap the view in `.fixedSize(...)` or text gets squeezed
  and truncated. Pin `\.locale` and `\.timeZone` so the simulator's settings never change a picture.
- Open the recorded PNGs and look at them before committing; a "passing" baseline can be wrong.

## Adding a Swift package

1. Add it to `Package.swift`, run `swift package resolve`, then `rm -rf .build` (its checkouts
   carry BUILD files that `make lint` would scan; `.bazelignore` keeps them out of `//...`).
2. Add `swiftpkg_<identity>` to `use_repo(swift_deps, ...)` in `MODULE.bazel` if you depend on it directly.
3. Build, then commit `Package.swift`, `Package.resolved`, `MODULE.bazel`, `MODULE.bazel.lock`.
4. Large clones (swift-syntax) can time out on weak networks; retry on a stable connection.

## Error triage

| Symptom | Cause / fix |
|---|---|
| `@build_bazel_rules_apple` not found | `repo_name` missing on a bazel_dep |
| `'X' is unavailable ... obsoleted` inside a Swift package | rules_swift_package_manager < 1.19; keep >= 1.19 |
| `is not visible from target` | A feature reached for a `*Live` module. Usually the boundary is right: depend on the interface |
| `Unsupported argument '--device_type'` | Use `--ios_simulator_device/--ios_simulator_version` |
| CI: `no provisioning profile was found` (or any target needing this Mac's state) | `//ios/...` builds every non-manual target; tag such targets `manual` and reach them through a `select` |
| Library builds but app does not | Building a library alone targets macOS; build the app or a test target |
| Swift 6 Sendable errors in our code | Capture dependencies explicitly in `.run { [dep] send in ... }` |
| `call to main actor-isolated static method` warning in tests | Pure helpers inside a `View` inherit main-actor isolation; mark them `nonisolated` |
| `cannot be registered to your development team because it is not available` | Placeholder bundle IDs (com.example.*) are taken; use the real `BUNDLE_ID` in `project.bzl` |
| Device install: `not a valid bundle ... CFBundleName` | The simulator ignores a missing `CFBundleName`; a real iPad does not. Keep it in `ios/Info.plist` |
| A view's `@Dependency(\.x)` is the default, not what `bootstrap` injected | Views read `DependencyValues._current`, not the store's; pass the value in or expose it (e.g. `DebugModel.installed`) |
| iPad runs old code after `make device` (crash uuid ≠ built uuid) | ipa files are dated 1980; devicectl skipped a same-size binary. Keep the Makefile's `touch` step |
| Device launch: `profile has not been explicitly trusted` | Trust the developer once in Settings > General > VPN & Device Management |
| `UIImage(named:in:)` returns nil though the asset exists | Resource bundle Info.plist lacks `CFBundleIdentifier` (see Resources) |

## CI differences

- CI has no `user.bazelrc` (no memory caps) and picks an available iPad simulator itself.
- Cache key: `MODULE.bazel.lock`, `.bazelversion`, `Package.resolved`. Changing them means a cold run.
- CI uploads no artifacts and prints no environment; keep it that way.
