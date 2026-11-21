---
name: pr-review-handoff
description: Use when a change in this repo is ready for review (code, guards, docs or design spec), when sending work to the code review session, when another session's commits need a PR, when acting as the review session ("Family-planner iOS 코드 리뷰"), or before merging a PR that has not been reviewed.
metadata:
  version: 0.2.0
  status: experimental
---

# PR review handoff

Several sessions share this repo. Branches switch and worktrees appear under each other, so a local
checkout never shows "the change". The pull request is the only thing that does. Review always
starts from a PR number, and the review session owns code review (user, 2026-11-21).

## Author: hand a change to review
1. Commit on a `feature/*` branch, push, and open a PR into `develop` (`git-flow-delivery`).
   - Write the body file in its own step, and read it back before `gh pr create` or `gh pr edit`.
   - Never put them in one batch: a failed write still creates the PR, with an old body.
2. One PR per change. Run `gh pr list --state open` first.
   - If the commits are already in an open PR, add to that PR.
   - If another session owns the commits, ask that session to open the PR. Moving them onto a fresh branch needs the user's OK.
3. Find the review session: list the sessions and pick the one titled "Family-planner iOS 코드 리뷰". If there is none, tell the user and stop.
4. Message it (SendMessage to its session id) with:
   - the PR number and title;
   - what to look at (the risky part, the boards it follows);
   - what is checked (commands and results);
   - what is not checked yet, such as the iPad check.
   Ask it to report to the user in Korean.
5. Keep working on other things. Findings come back as messages:
   - fix them on the same branch;
   - push;
   - tell the review session which commit fixes which finding, and the new head SHA.

## Review session: review a PR
- Read only from the PR:
  - `gh pr view N --json headRefOid,files`, `gh pr diff N` and `gh pr checks N`;
  - files at the head: `git fetch origin <headRefOid>`, then `git show <sha>:<path>` (the working tree is never touched).
- Build only when the change needs one:
  - use a worktree of your own (`git worktree add <dir> <sha>`);
  - never build next to another session's build (8 GB Mac);
  - afterwards run `bazel shutdown` in it, then `git worktree remove <dir>`.
- Never run `git switch`, `git checkout` or `gh pr checkout` in a checkout another session uses.
- Send findings to the author session as a message. Each finding gives the file, the line, what breaks and the fix.
  - PR comments and reviews are published text. Post one only with the user's OK, written to a file and sent with `--body-file`, so the private-term hook reads it.
- Approval is a message to the author naming the head SHA it covers ("#132 approved at 455a66e"), with what you checked.
  - Every session pushes as one GitHub account, so GitHub refuses an approving review.
- Re-review: when the author names the fixing commits, review only `git diff <old head>..<new head>`, then approve the new head.

## Merge
- A PR merges when all of these hold:
  - the review session approved the PR's current head SHA (merge with `--match-head-commit <sha>`);
  - CI is green;
  - a change to a screen has been checked on the iPad (or the user waived it).
- The author merges (squash into `develop`), unless the user told the review session to merge.
- Docs-only PRs (spec, boards) follow the same path.

## Common mistakes

| Mistake | Instead |
|---|---|
| "Review my working tree" / "look at branch X here" | Send a PR number. |
| The reviewer switches the shared checkout to the PR branch | `git show <sha>:<path>`, `gh pr diff`, or its own worktree. |
| Two sessions open PRs for the same commits | Check `gh pr list` and let the commits' owner open it. |
| Merging because CI is green while review is pending | Wait for the review session's approval. |
| Merging after new commits landed on an approved PR | Approval covers one head SHA; re-review the new commits. |
| Posting findings or approval as PR comments without asking | Message the author; publish only with the user's OK. |
| PR body file written in the same batch as `gh pr create` | Write it, read it back, then create the PR. |
