# Lessons inbox

Lessons from real work, waiting for a skill retro (`skill-retro` skill). One line each:
`- YYYY-MM-DD · symptom · cause · rule · target` where target is a skill name, `CLAUDE.md`,
`guard` (a script or test can enforce it) or `drop`. This repo is public: no private names, places,
stops or schools. The retro moves each line into its target and deletes it here.
- 2026-11-22 · the harness session deleted an untracked file in the main checkout (another session's) while the review session was still asking the user · "it is safe, the content is on develop" felt like enough · deleting or overwriting anything in another session's checkout waits for the user's yes, even when the content is kept elsewhere · pr-review-handoff
- 2026-11-22 · a second TestStore in one test sent `\.path[id: 0]` and got "action for a missing element" · StackState ids keep counting across states built in the same test, so the second state's first element is not 0 · read the id from `store.state.path.ids` for any store after the first · tca-feature
