# Lessons inbox

Lessons from real work, waiting for a skill retro (`skill-retro` skill). One line each:
`- YYYY-MM-DD · symptom · cause · rule · target` where target is a skill name, `CLAUDE.md`,
`guard` (a script or test can enforce it) or `drop`. This repo is public: no private names, places,
stops or schools. The retro moves each line into its target and deletes it here.
- 2026-11-08 · kid home slid under the iPad status bar · boards are full-screen 1376 × 1032 and the home clock frame is a fixed 1032 tall inside the safe area · fit kid screens to the safe-area height, keep the status bar visible and its band empty · tca-feature
- 2026-11-08 · way strip bus rocked as one picture, wheels still · spec said only 'rocks as on A2'; the A2 motion lives in backlog N1a and I guessed instead of looking · when a spec says 'as on <board>', find that board's motion rule (spec, backlog, motion catalogue) before building · tca-feature
- 2026-11-09 · A2 parts sat on different left/right lines and ran past the margin · the spec gave region bounds only and the inside was stacked by eye with paddings · before building a screen, get per-element board coordinates (redlines) from the design session and place parts on shared edges; add a layout test for the shared edges · tca-feature
- 2026-11-09 · parts looked off the board lines · I measured screenshots by eye; the cause (iPadOS 26 safe top 32, a wrong window height, the strip's aspect gap) only showed with the board-line grid on · check layout on the iPad with OPEN=<screen> GRID=1 and measure against the lines · bazel-ios
