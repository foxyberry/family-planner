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
(by cable, or over Wi-Fi once paired) (a free Apple ID signed in to Xcode is enough). All targets are listed in
the `Makefile`.

## Privacy
This repository is public. Real personal data never goes into it; local-only values live in
git-ignored files, and commits are checked by `.githooks/` (run `make setup` to enable them).

Private here means "not in git", never "left out of the build". The international/private
school list and the preschool files (public sources, kept out of this repo for licence reasons)
live in a separate private repo, checked out next to this one as `../family-planner-private`.
`make setup` runs `make private`, which clones it with `gh` when it is missing and copies the
required files into the git-ignored `ios/Clients/SchoolDirectoryLive/Private/`. Every
installable build (make build/run/device, Xcode) needs them and stops with
"School data missing: run make private" otherwise. Only CI and public clones build without them,
on purpose: `make build PUBLIC_BUILD=1` (Bazel `--config=public`; for Xcode add
`build --config=public` to `user.bazelrc`). The private repo holds no family information.
