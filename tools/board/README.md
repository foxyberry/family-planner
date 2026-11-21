# Local status board

One page that shows where every session's work stands, for a user who runs several Claude
sessions on this repo at once. It runs on this Mac only. The output lands in `tools/board/out/`
(git-ignored), and the server listens on 127.0.0.1.

```bash
make board                        # http://127.0.0.1:8765, rebuilt on reload (at most every 25 s)
python3 tools/board/board.py      # write tools/board/out/index.html once
```

What it shows:
- **Who has to act now**: each open PR's next step and who owns it (the user, the review
  session, or the session that opened the PR), following the `pr-review-handoff` loop.
- **Lanes**: review waiting, fixing, re-review waiting, user check (the iPad check for screen PRs),
  merge waiting, and recently merged. Each card has its category (from the conventional title and
  the paths it touches), the session that opened it, CI, open threads, and LGTM state.
- **Sessions**: every recent session's title, whether it is busy, and its open PRs.
- **Local-only work**: worktrees with uncommitted or unpushed changes, branches with no PR, and
  (folded) what can be cleaned up.
- **This Mac**: free memory, Bazel servers, booted simulators, and open lessons.

Where the facts come from:
- `gh api graphql` for the PRs.
- `~/.claude/projects/*/*.jsonl` for the sessions. Claude Code records each PR a session opened
  (`gitOperation.pr`, action `created`), its title and its working folder. The board reads only the
  bytes added since the last run (`out/sessions-cache.json`).
- `git worktree list`, `git for-each-ref`, `pgrep`, `simctl` and `memory_pressure` for the rest.

A screen PR waits in "user check" after its LGTM until a PR comment starts with `iPad OK` (or the
PR gets the `ipad-ok` label).
