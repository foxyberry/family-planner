---
name: git-flow-delivery
description: Runs this repo's git flow delivery loop - feature/* branches cut from develop, English conventional commits, private-term checks on diffs and on commit/PR text, push only after explicit user approval, PRs into develop, CI checks with self-fix on the same branch, and release/hotfix merges into main with tags. Use when starting a milestone task, creating a branch, committing, pushing, opening or updating a PR, checking or fixing CI, or preparing a release.
metadata:
  version: 0.6.1
  status: experimental
---

# Git flow delivery

This repo is public. Everything in a commit, commit message, PR, issue, tag or release note is
published. This skill overrides generic branch-finishing advice from other skills.

## Branch model

```
main      ── release tags only ─────────●──────────●──
develop   ──●────●────●─────────────────┼──●───────┼──
feature/*    └─●─┘    └─●──●─┘          │          │
release/x.y.z                └────●─────┘          │
hotfix/*                                    └──●───┘
```

- `feature/<m#>-<topic>` (for example `feature/m1-dial`) starts from `develop`, PR into `develop`.
- `release/<x.y.z>` starts from `develop`, merges into `main` with a tag, then back into `develop`.
- `hotfix/<topic>` starts from `main`, merges into `main` and `develop`.
- Never commit directly to `main` or `develop`.

## Start a task

1. `git status --short` must be clean (or stash with the user's agreement).
2. `git switch develop && git pull --ff-only`
3. `git switch -c feature/<m#>-<topic>`

A checkout another session also works in keeps its branch: start there in a worktree instead.

## Commit

- English conventional commits: `feat:`, `fix:`, `build:`, `ci:`, `chore:`, `docs:`, `test:`.
- Stage files by path, never a whole folder (other sessions write untracked files there), then
  read `git diff --cached --name-status` before committing; leave unrelated changes out.
- Let the hooks run. Never `--no-verify`. If a hook blocks, replace the data with fake values.
- Write the message as literal text or a heredoc; `$VAR` / `$(...)` in messages is blocked by the
  public-text hook because it cannot be checked.
- Run the commit, tag or PR command in a shell call of its own: nothing else in that call except a
  trailing log of the new commit. A heredoc message next to any other command (even a PR status
  check) is blocked as unreadable stdin. The hook scans the whole command line: a `$VAR` anywhere else in the same call blocks it, and so does a note you append to a file
  in that call if the note mentions a publishing command. Edit such notes with the file tools.
  The same goes for scripts or tests that contain `git commit -m`: write them with the file tools,
  then run them with `bash <file>`.

## Before pushing (ask the user every time)

- Name the branch and remote you will push.
- Show the test command you ran and its result (`make test`, guard tests if scripts changed).
- Mention anything the user should know is going public (new files, new docs).
- The pre-push hook checks every commit new to the remote (gitleaks, private terms in diffs, file
  names, messages, authors, branch and tag names), runs `make lint` on Bazel changes and the guard
  tests on guard changes. If it blocks, rewrite the offending commit on the unpushed branch
  (amend, or a non-interactive rebase, with the user's agreement); never `--no-verify`.
- Something removed late on an unpushed branch (a private detail, a revealing comment) still sits
  in its earlier commits, and a push publishes them. Before the first push, offer to squash the
  branch into one commit (features are squash-merged anyway).
- Dry-run the hook without pushing: feed it one ref line,
  `<local ref> <sha> <remote ref> 0000000000000000000000000000000000000000`, on stdin with
  `.githooks/pre-push origin`.

## Stacked PRs

- Turn on auto-merge for the bottom PR only: auto-merge squashes whichever PR goes green first,
  and a top PR then carries the ones below it. Or base each PR on the one below it.
- After a merge, check the PR's state before pushing to its branch (a push to a deleted branch
  makes an orphan).
- When the base was squash-merged, the stacked branch still holds the base's commits:
  `git rebase --onto origin/develop <base tip>` and push under a new branch name (never
  force-push). Ask the user to delete the old remote branch.

## Pull request

- `gh pr create --base develop --title "<conventional title>" --body-file <file>`
- Body: Summary, Test evidence (commands + results), Risk. No personal data.
- `main` only receives `release/*` and `hotfix/*` PRs.

## CI loop

- `gh pr checks <n> --watch`; on failure `gh run view <run-id> --log-failed`.
- CI runs only the Linux checks (Guards, Secret scan). There is no macOS CI (cost): run `make test`
  locally and show its output in the PR before merging.
- Fix on the same branch, re-run the local check that covers the failure, ask before pushing again.
- Never merge with red CI.

## Merge

- `feature/*` → `develop`: squash merge.
- `release/*` → `main`: merge commit + tag `v<x.y.z>`, then merge `main` back into `develop`.

## Do not

- Force-push shared branches, `git reset --hard` without the user's say-so, merge with red CI,
  or paste content from `docs/private/` into tracked files or PR text.
