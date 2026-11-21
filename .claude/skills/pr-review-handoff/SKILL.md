---
name: pr-review-handoff
description: Use when a change in this repo is ready for review (code, guards, docs or design spec), when sending work to the code review session, when another session's commits need a PR, when acting as the review session ("Family-planner iOS 코드 리뷰"), or before merging a PR that has not been reviewed.
metadata:
  version: 0.1.0
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
5. Keep working on other things. Findings come back as messages or PR comments:
   - fix them on the same branch;
   - push;
   - tell the review session which commit fixes which finding.

## Review session: review a PR
- Read only from the PR:
  - `gh pr view N`, `gh pr diff N` and `gh pr checks N`;
  - files at the PR head with `gh api repos/{owner}/{repo}/contents/{path}?ref={head}`;
  - if you must build, a worktree of your own (`git worktree add <dir> origin/<head>`).
- Never run `git switch`, `git checkout` or `gh pr checkout` in a checkout another session uses.
- Send findings to the author session and on the PR. Each finding gives the file, the line, what breaks and the fix.
- Approve with `gh pr review N --approve` (or a message when GitHub refuses self-approval), and say what you checked.

## Merge
- A PR merges when all of these hold:
  - the review session approved it;
  - CI is green;
  - a change to a screen has been checked on the iPad (or the user waived it).
- The author merges (squash into `develop`), unless the user told the review session to merge.
- Docs-only PRs (spec, boards) follow the same path.

## Common mistakes

| Mistake | Instead |
|---|---|
| "Review my working tree" / "look at branch X here" | Send a PR number. |
| The reviewer switches the shared checkout to the PR branch | `gh pr diff`, or its own worktree. |
| Two sessions open PRs for the same commits | Check `gh pr list` and let the commits' owner open it. |
| Merging because CI is green while review is pending | Wait for the review session's approval. |
| PR body file written in the same batch as `gh pr create` | Write it, read it back, then create the PR. |
