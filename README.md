# Family Planner

An iPad app that shows a family's day on a 24-hour dial so children can see what comes next,
plan their own free time, and get out the door on time. Personal study project.

## Stack
SwiftUI, The Composable Architecture, Swift 6 concurrency, Bazel 8 (no Xcode GUI needed day to day).

## Requirements
- macOS with Xcode 26 and an iOS 26 simulator runtime
- Homebrew (`make setup` installs bazelisk, buildifier, gitleaks)

## Getting started
```bash
make setup
make run
```

`make test` runs the unit tests. `make device` builds, signs and launches the app on an iPad
connected by cable (a free Apple ID signed in to Xcode is enough). All targets are listed in
the `Makefile`.

## Privacy
This repository is public. Real personal data never goes into it; local-only values live in
git-ignored files, and commits are checked by `.githooks/` (run `make setup` to enable them).
