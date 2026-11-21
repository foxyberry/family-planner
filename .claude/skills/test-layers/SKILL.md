---
name: test-layers
description: Use when deciding which test should catch a bug, a review finding or something seen on the iPad or simulator while self-checking (WebDriverAgent, screenshots, taps); adding tests for a new screen or flow; a test would need Face ID, a passcode or a person to tap; choosing between a reducer test, a journey, a UI test and a snapshot; or writing a PR's test evidence.
metadata:
  version: 0.1.0
  status: experimental
---

# Test layers

## Overview
Every check a person makes once should become a test that runs without them. Self-checking (the
simulator, or the real iPad through WebDriverAgent) is how you find and fix things while you build;
each finding then moves into the cheapest layer below that would have caught it. What stays manual
is only the look and feel.

## The layers
| Layer | Where | Catches | Runs |
|---|---|---|---|
| Model / reducer | `ios/*/Tests` (`tca-feature`) | rules, copy, date maths, one reducer's flow | `make test`, pre-push (`test-affected`) |
| Journey | `ios/Journeys/Tests` (README there) | a flow across screens through the root store: saves, reloads, locks, the clock | same |
| Snapshot | `ios/DesignSystem/SnapshotTests` | a part's drawing, size, clipping, dark look | `make snapshots` (local, not CI) |
| UI test | `ios/Journeys/Tests/UI` | what State can't show: holds, keyboard focus, sheets, scrolling | `make ui-test` (local) |
| Self-check | simulator, or the iPad over WebDriverAgent | anything, while building | by hand, never evidence alone |
| The user's iPad check | screen PRs (`pr-review-handoff`) | look and feel only | the user |

## A finding goes to
| You saw | Add |
|---|---|
| wrong value, missing reload, wrong screen after a step | a journey step that asserts the State a person would see |
| a rule or copy wrong in one screen | a reducer or model test |
| clipped, cramped, wrong size or colour in a part | a snapshot case (and the part's gallery entry) |
| a value that changes with device size (11-inch vs 13-inch) | a layout-model test at both sizes (`screen-layout`) |
| a gesture, focus or keyboard step that loses input | a UI test, plus a journey step that replays the round trip as actions |
| only "it feels off" | nothing: say so in the PR for the user's iPad check |

Before calling a test done, check that it catches the bug: put the bug back and see the test fail. A
test that already passed with the bug proves nothing. Then remove the bug again and see it pass.

## Nobody waits
No test waits for a person, and `scripts/check-unattended-tests.sh` blocks the ways in:
- journeys fake Face ID through `WorldData.faceID`; unit tests fake the `parentAuth` client;
- UI tests start the app only through `TestApp.launch`, which pins `-fpNow`, sets `-fpFamily
  empty|sample` and passes `-fpSkipFaceID` (simulator only);
- a step only a person can do (Face ID on the real iPad, a passcode) belongs in self-checking,
  never in a test. Never type a passcode or password through automation.

## PR evidence
In the PR body, for each layer you touched: the command, its result line (`PASSED`, the count), and
the bug-back failure (file and line). Name what is not checked: snapshots not recorded, the iPad not
seen. A screen PR also lists the journeys and UI tests that cover it, so the user's iPad check is
look and feel only.

## Common mistakes
- Treating a WebDriverAgent screenshot as the test: it is evidence for you, not a check that stays.
- A journey that uses `finish()` plus `skipReceivedActions()` where the order matters: it can hide a
  missing reload. `receive` the action by name when the step is the point.
- Re-testing journey logic through the UI: slow, and it breaks on layout changes. UI tests cover only
  what State can't show.
- A UI test that finds parts by position: find them by the words a person sees or a picture's slot.
