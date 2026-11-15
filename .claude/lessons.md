# Lessons inbox

Lessons from real work, waiting for a skill retro (`skill-retro` skill). One line each:
`- YYYY-MM-DD · symptom · cause · rule · target` where target is a skill name, `CLAUDE.md`,
`guard` (a script or test can enforce it) or `drop`. This repo is public: no private names, places,
stops or schools. The retro moves each line into its target and deletes it here.
- 2026-11-15 · the CLAUDE.md edit landed in an unrelated PR commit · a commit chained with a blocked command never ran; the change rode along on the branch switch and git add -A swept it into the next branch's commit · run the commit alone and check git status (and the commit's --stat) before switching branches · git-flow-delivery
