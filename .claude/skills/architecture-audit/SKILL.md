---
name: architecture-audit
description: Use only when the user asks to audit or check develop ("develop 점검해줘", "audit develop", "아키텍처 점검") — never on a schedule or on your own — or when asked whether develop has dead code, rule drift, stale board citations or pending lists that stopped shrinking.
metadata:
  version: 0.1.0
  status: experimental
---

# Architecture audit

## Overview
An on-request look at what changed on develop since the last audit: the guards over the whole
tree, the rules a guard can't see, and dead code. It ends in cleanup PRs (or issues), guard
lessons and a short Korean report. It never edits the shared checkout.

## Run
1. Work in your own worktree at the latest develop:
   `git fetch origin develop && git worktree add --detach <scratch>/audit origin/develop`
   (or `git checkout --detach origin/develop` in your existing one). Never the shared checkout.
2. `bash scripts/audit.sh --mark` prints the report skeleton and records HEAD as `audit-last` in the
   git common dir, which every worktree of this clone shares; the next audit starts there. First
   audit: `--since <sha>`.
   - **Guards over the whole tree**: every finding is a cleanup item (`check-layout-versions.sh`
     lists stale board citations).
   - **Pending lists**: a list that did not shrink since the last audit is a cleanup item.
   - **Dead-code candidates** (grep): judge each (below).
3. Read the changed files against the rules guards can't see:
   - views: decisions or copy computed in a view, values in parts (`tca-feature`, View row);
   - layout: board values vs screen points, rows sized by hand (`screen-layout`);
   - design: sizes, copy and pictures against the spec and boards (`crayon-design`); a
     board-vs-app difference goes to the design session, never a value you pick;
   - comments citing retired boards (C1, C6, E5, E6): the version guard can't see boards that no
     longer have a layout file;
   - code left from a replaced spec: a type, case or copy key only the old flow used.
4. Dead code, deeper than grep: Periphery (`brew install periphery`, the user's OK), when Bazel is
   free. Its Bazel mode needs a module entry that also moves apple_support and rules_apple past the
   CLAUDE.md pins, so it never lands in git: in the audit worktree only, append
   `bazel_dep(name = "periphery", version = "3.8.0", dev_dependency = True)` and
   `use_repo(use_extension("@periphery//bazel:generated.bzl", "generated", dev_dependency = True), "periphery_generated")`
   to MODULE.bazel, run `periphery scan --bazel --bazel-filter '//ios:FamilyPlanner'`, then
   `git checkout -- MODULE.bazel MODULE.bazel.lock`. The first run builds swift-syntax (about 8
   min). Read it like this:
   - drop "Redundant public accessibility" (modules export on purpose) and the `Path` cases of a
     `@Reducer enum` (the macro uses them);
   - it scans the app only, so grep each finding in tests and `DesignSystem/Gallery` first;
   - delete only what grep and Periphery both call unused, and say so in the PR.
   - Not dead: protocol requirements (`placeSubviews`, `body`), `@main`, TCA actions a view sends,
     anything reached by name from a JSON journey or `AgentContract`.
   - Dead: nothing reads it, and no spec or board still asks for it. Code only tests or the debug
     menu use is dead unless it exists for them (`SeedData`, `FakeWorld`, DebugTools).
5. Act on what you found:
   - a cleanup PR per kind (dead code, stale citations, pending items), each with its evidence,
     sent for review (`pr-review-handoff`); something that needs a person's call becomes an issue
     or a question to the design session;
   - a kind a script could catch next time: a lesson with target `guard` (`skill-retro`), or a
     new rule for the SwiftLint native rules work;
   - a Korean report to the user: the range, what was fixed in which PR, what is left and why.

## Common mistakes
- Treating a grep or Periphery candidate as a verdict: check the uses (protocols, TCA, journeys).
- Deleting code a spec still asks for because no screen calls it yet: ask the session that owns it.
- Auditing the whole history every time: the last audited SHA keeps each audit to its change.
