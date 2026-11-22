---
name: pr-review-handoff
description: Use when a change in this repo is ready for review (code, guards, docs or design spec), when sending work to the code review session, when another session's commits need a PR, when acting as the review session ("Family-planner iOS 코드 리뷰"), when a review or LGTM is posted on your PR, or before merging a PR.
metadata:
  version: 0.9.2
  status: experimental
---

# PR review handoff

Several sessions share this repo. Branches switch and worktrees appear under each other, so a local
checkout never shows "the change"; only the pull request does. Session messages get lost from the
record, so the review lives on the PR as inline review comments, and messages only point there
(user, 2026-11-21). The review session owns code review.

## The loop

| Step | Who | Where |
|---|---|---|
| 0. Start the work as a draft PR | author | draft PR, so the board shows it (not reviewed) |
| 1. Mark it ready and ask for a review | author | PR, then a message with the PR number |
| 2. Review | reviewer | one inline review on the PR (`event: COMMENT`) |
| 3. Say the review is posted | reviewer | message with the review URL |
| 4. Fix each comment, or reply with the reason | author | commits, and a reply on each thread |
| 5. Ask for a re-review | author | message with the old and new head SHAs |
| 6. Resolve fixed threads, answer replies, review what is left | reviewer | PR |
| 7. Repeat 3–6, then "LGTM at <sha>" | reviewer | PR comment, then a message |
| 8. Merge on LGTM + green CI (+ the user's iPad check for a screen change) | author | `gh pr merge N --squash --match-head-commit <sha>` |

The user approved posting reviews, thread replies and LGTM comments on this repo's PRs without a
per-post OK (2026-11-21). Post from a file (`--body-file`, or `--input` for JSON): the public-text
hook blocks shell expansion and checks the text for private terms.

## Author
1. Show the work from its start (user, 2026-11-21: the board must show what is being built).
   - Work in a worktree of your own, cut from `develop` (`git worktree add`), not in a checkout
     another session uses; a long build there blocks everyone else.
   - At the start, push the branch with its first commit (an empty "start" commit is fine) and open
     a draft PR into `develop` (`gh pr create --draft`; `git-flow-delivery`). The board shows it as
     "초안: 작성 중"; the review session does not review drafts.
   - Push as you go: after the first push, pushes to your own draft or open PR branch need no ask
     (`git-flow-delivery`), so the board shows whether the work is moving or stuck. A draft's
     commits are public from the first push.
   - When the work is done and checked, update the PR body with the test evidence, then
     `gh pr ready N` and ask for the review (step 3).
   - Write the body file in its own step and read it back before `gh pr create` or `gh pr edit`.
   - Never put the two in one batch: a failed write still creates the PR, with an old body.
2. One PR per change. Run `gh pr list --state open` first.
   - If the commits are already in an open PR, add to that PR.
   - If another session owns the commits, ask it to open the PR. Moving them needs the user's OK.
3. Ask the review session (the one titled "Family-planner iOS 코드 리뷰"; if there is none, tell the user):
   - the PR number;
   - what to look at;
   - what is checked, and what isn't yet (the iPad check).
   - for a screen PR, the journeys, UI tests and snapshots that cover it (`test-layers`), so the
     iPad check is look and feel only.
4. When the review is posted, read every comment: `gh api repos/{owner}/{repo}/pulls/N/comments`.
   - Fix each one, or decide not to.
   - Reply on its thread with the fixing commit or your reason: `gh api repos/{owner}/{repo}/pulls/N/comments/<id>/replies --method POST --input <file>`.
   - A board-vs-app finding goes to the design session; don't pick a value yourself. The user hears
     about it from the design session.
5. Ask for a re-review with the old and new head SHAs.
6. Merge when all of these hold (a push after the LGTM needs a new look):
   - an "LGTM at <sha>" comment names the current head;
   - CI is green: every check says pass. develop requires guard-tests and secret-scan, for admins
     too; still run `gh pr checks N --watch` first so the merge doesn't fail;
   - a PR that changes a screen has the user's iPad check. Ask for it in your own session: it is
     the only time a merge waits for the user (user, 2026-11-21). Any other PR merges by itself.
     When the user says the head looks right, post "iPad OK at <sha>" on the PR, quoting their words.
     Describe what was checked on the family's iPad without copying any value from its screen
     (numbers, names, stops are private; the term hook only knows listed ones).
     Like the LGTM it covers one head, so a later push needs a new check (`make board` reads it).
7. Bind every PR you open to the app's PR monitor with Auto-fix on (`ccd_pr` get_status, bind_pr,
   set_monitor). Your session then wakes on review comments, CI failures and conflicts.
8. When a step needs a human decision, tell the user in your own session. Never leave it only in a
   message to another session. Read the failing log first, and ask only for what you can't do.
   A failure an outside review reports is reproduced on your path before you set it aside.

## Review session
- Skip draft PRs: review a PR once it is marked ready and its author asks.
- Read only from the PR, never from a shared checkout:
  - `gh pr view N --json headRefOid,files`, `gh pr diff N` and `gh pr checks N`;
  - `git fetch origin <sha>`, then `git show <sha>:<path>` and `git diff <old>..<new>`.
- Build only when the change needs one:
  - in a worktree of your own (`git worktree add <dir> <sha>`);
  - never while another session builds (8 GB Mac);
  - then `bazel shutdown` in it and `git worktree remove <dir>`.
- Post one review per pass:
  - write a JSON file with `commit_id` (the head), `event: COMMENT` and `comments[]` (`path`, `line`, `side: RIGHT`);
  - send it with `gh api repos/{owner}/{repo}/pulls/N/reviews --method POST --input <file>`;
  - a comment's line must sit inside a diff hunk (else 422), so put other findings in the review body.
- One GitHub account pushes for every session, so approving and request-changes reviews are refused.
  - Approval is a PR comment, "LGTM at <sha>" plus what was checked, then a message to the author.
- Re-review: read only `<old>..<new>`, then:
  - resolve the fixed threads (GraphQL `resolveReviewThread`, thread ids from `pullRequest.reviewThreads`);
  - answer the author's replies;
  - post a new review for anything left, or LGTM.
- Review to guard: when a finding could be caught by a script (a pattern in the code, a name or
  number that can be compared) and its kind has come up twice, write the lesson line
  (`skill-retro` format, target `guard`, naming both PRs) in the review body and send it to the
  harness session, which commits it in its next harness PR. Never edit `.claude/lessons.md` in a
  shared checkout: an uncommitted line there rides into another session's commit.

## Common mistakes

| Mistake | Instead |
|---|---|
| "Review my working tree" / "look at branch X here" | Send a PR number. |
| The reviewer switches the shared checkout to the PR branch | `git show <sha>:<path>`, or its own worktree. |
| Findings or approval only in session messages | Inline review and LGTM on the PR; the message points to it. |
| Fixing silently | Reply on each thread with the fixing commit or the reason. |
| Two sessions open PRs for the same commits | Check `gh pr list`; the commits' owner opens it. |
| Merging on green CI, or after a push that followed the LGTM | Merge only at the LGTM's head SHA. |
| Merging while a check is still pending | `gh pr checks N --watch`, then merge. |
| PR body file written in the same batch as `gh pr create` | Write it, read it back, then create the PR. |
