# Lessons inbox

Lessons from real work, waiting for a skill retro (`skill-retro` skill). One line each:
`- YYYY-MM-DD · symptom · cause · rule · target` where target is a skill name, `CLAUDE.md`,
`guard` (a script or test can enforce it) or `drop`. This repo is public: no private names, places,
stops or schools. The retro moves each line into its target and deletes it here.
- 2026-11-09 · the C4 form card grew past 64…882 and shifted left · a row wider than the card; .frame(maxWidth: .infinity) does not cap a wider child, so the card took the child's size · pin a form to the card's inner width with .frame(width:) and check the widest row (date chips, steppers) on the grid · tca-feature
- 2026-11-09 · a simulator check showed the old layout after a rebuild · simctl install skips a same-size binary because every file carries the 1980 build time (as devicectl did) · install a touched copy; make run now does · drop (fixed in the Makefile)
- 2026-11-09 · a push from a worktree set core.bare and user.email=test@example.com in the real repo · git sets GIT_DIR for hooks run in a worktree, and the guard tests' scratch-repo git commands inherited it · run guard tests with the git env cleared (pre-push now does); a session that shares a checkout must not switch branches there · guard
