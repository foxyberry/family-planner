# Lessons inbox

Lessons from real work, waiting for a skill retro (`skill-retro` skill). One line each:
`- YYYY-MM-DD · symptom · cause · rule · target` where target is a skill name, `CLAUDE.md`,
`guard` (a script or test can enforce it) or `drop`. This repo is public: no private names, places,
stops or schools. The retro moves each line into its target and deletes it here.
- 2026-11-09 · a push from a worktree set core.bare and user.email=test@example.com in the real repo · git sets GIT_DIR for hooks run in a worktree, and the guard tests' scratch-repo git commands inherited it · run guard tests with the git env cleared (pre-push now does); a session that shares a checkout must not switch branches there · guard
