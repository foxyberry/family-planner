---
name: bazel-ios
description: Builds, tests, runs and troubleshoots the iPad app with Bazel 8 and the Makefile on an 8 GB Mac - make build/test/run/lint/fmt/sim-stop, single-target bazel test with simulator flags, user.bazelrc memory caps, one-simulator rule, buildifier, adding Swift packages through Package.swift and MODULE.bazel, rules version bumps, and common Bazel/rules_apple errors. Use when running or fixing builds or tests, editing BUILD.bazel, .bzl, MODULE.bazel, .bazelrc or the Makefile, or when the simulator or Bazel server misbehaves.
metadata:
  version: 0.1.0
  status: experimental
---

# Bazel iOS

## 8 GB rules

- One build or test at a time; one simulator. `make run` builds first, then boots.
- `make sim-stop` when you are done looking at the app.
- Shut down idle Bazel servers of other projects: `cd <other repo> && bazel shutdown`.
- "Another command is running" means wait; Bazel serializes commands in one workspace.
- If memory pressure stays red during a cold build, set `common --local_resources=cpu=2` in
  `user.bazelrc` (git-ignored; created from `user.bazelrc.example` by `make setup`).

## Commands

| Need | Command |
|---|---|
| Build app | `make build` |
| Build + launch on simulator | `make run` |
| All tests | `make test` (override `SIM_DEVICE=... SIM_OS=...`) |
| One test target | `make test-one TARGET=//ios/<Pkg>/Tests:<Target>` (plain `bazel test` skips `ios/.bazelrc` and loses cache hits) |
| Test log | `bazel-testlogs/ios/<Pkg>/Tests/<Target>/test.log` |
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
(reuses one simulator, writes no .xcresult).

## Adding a Swift package

1. Add it to `Package.swift`, run `swift package resolve`.
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
| Library builds but app does not | Building a library alone targets macOS; build the app or a test target |
| Swift 6 Sendable errors in our code | Capture dependencies explicitly in `.run { [dep] send in ... }` |

## CI differences

- CI has no `user.bazelrc` (no memory caps) and picks an available iPad simulator itself.
- Cache key: `MODULE.bazel.lock`, `.bazelversion`, `Package.resolved`. Changing them means a cold run.
- CI uploads no artifacts and prints no environment; keep it that way.
