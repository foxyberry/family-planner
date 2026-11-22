# Local status board

One page that shows where every session's work stands, for a user who runs several Claude
sessions on this repo at once. It runs on this Mac only. The output lands in `tools/board/out/`
(git-ignored), and the server listens on 127.0.0.1.

```bash
make board                        # http://127.0.0.1:8765, rebuilt in the background while open
python3 tools/board/board.py      # write tools/board/out/index.html once
```

What it shows:
- **Who has to act now**: each open PR's next step and who owns it (the user, the review
  session, or the session that opened the PR), following the `pr-review-handoff` loop.
- **Lanes**: review waiting, fixing, re-review waiting, user check (the iPad check for screen PRs),
  merge waiting, and recently merged. Each card has its category (from the conventional title and
  the paths it touches), the session that opened it, CI, open threads, and LGTM state.
- **Sessions**: every recent session's title, whether it is busy, and its open PRs.
- **Local work**: every local branch with its last commit, its size against develop, the areas it
  touches and a verdict:
  - *in progress*: it has an open PR;
  - *decide*: uncommitted changes, changes develop doesn't have, or a PR closed unmerged;
  - *safe to delete*: its PR merged, or every file it changed already matches develop. These fold
    away with the commands that clean them up; the board itself deletes nothing.
- **This Mac**: free memory, Bazel servers, booted simulators, and open lessons.
- **Open issues** (between the lanes and the sessions): `scripts/issue.sh` files in the main
  checkout's `.claude/issues/`, by owner; closed ones leave the board.

Every section and lane folds (recently merged starts folded), and the folds survive the 15 s reload.

Where the facts come from:
- `gh api graphql` for the PRs.
- `~/.claude/projects/*/*.jsonl` for the sessions. Claude Code records each PR a session opened
  (`gitOperation.pr`, action `created`), its title and its working folder. The board reads only the
  bytes added since the last run (`out/sessions-cache.json`, kept in full only for this repo's sessions).
- `git worktree list`, `git for-each-ref`, `pgrep`, `simctl` and `memory_pressure` for the rest.
  While the page is open it runs `git fetch --prune origin` in the shared repo at most every
  5 minutes. That only updates remote-tracking refs and never touches local branches; if it hits
  another session's fetch or push, it fails quietly and tries again later.

A screen PR waits in "user check" after its LGTM until a comment says `iPad OK at <head sha>`
(`pr-review-handoff` step 6); a later push needs a new check. The server answers only `/` for a
`127.0.0.1` or `localhost` Host.
