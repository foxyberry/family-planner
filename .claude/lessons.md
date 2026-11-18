# Lessons inbox

Lessons from real work, waiting for a skill retro (`skill-retro` skill). One line each:
`- YYYY-MM-DD · symptom · cause · rule · target` where target is a skill name, `CLAUDE.md`,
`guard` (a script or test can enforce it) or `drop`. This repo is public: no private names, places,
stops or schools. The retro moves each line into its target and deletes it here.
- 2026-11-15 · the CLAUDE.md edit landed in an unrelated PR commit · a commit chained with a blocked command never ran; the change rode along on the branch switch and git add -A swept it into the next branch's commit · run the commit alone and check git status (and the commit's --stat) before switching branches · git-flow-delivery
- 2026-11-15 · pre-push-test failed after a new guard was wired into the pre-push hook · the test copies each guard script into a temp repo by name, and the new one was missing · when adding a guard to .githooks/pre-push, add it to the copy list in scripts/tests/pre-push-test.sh too · guard
- 2026-11-18 · S2 Next stayed off with the default times on screen · the form kept nil and the copy drew the defaults as soft placeholders, so the shown value was never in State (and a wheel set to the same value sends nothing) · any value a field shows as its starting value lives in State from the form's start (seed it in the model, not the copy); soft placeholders only for truly empty inputs, and test "Next with no edits" · tca-feature
- 2026-11-18 · C3 For / Repeat tabs ran past the card on the 11-inch iPad · fixed 3 x 180 tab widths came from the 13-inch board and never shrank · a row of tabs takes its width from the control column (GrownupLayout.tabWidth), and check every fixed-width row on the 11-inch before merging · crayon-design
