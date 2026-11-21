#!/bin/bash
# Tests for tools/board/board.py classify(): each PR lands in the lane of its next step on the
# pr-review-handoff loop, with the right actor. Pure Python, no GitHub, runs anywhere (CI included).
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
BOARD="$HERE/../../tools/board/board.py"

python3 -I - "$BOARD" <<'EOF'
import importlib.util, sys

spec = importlib.util.spec_from_file_location("board", sys.argv[1])
board = importlib.util.module_from_spec(spec)
spec.loader.exec_module(board)

HEAD, OLD = "b" * 40, "a" * 40
T0, T1, T2, T3 = ("2026-11-21T01:00:00Z", "2026-11-21T02:00:00Z",
                  "2026-11-21T03:00:00Z", "2026-11-21T04:00:00Z")


def pr(files=("docs/x.md",), ci="SUCCESS", reviews=(), comments=(), threads=(), committed=T1,
       mergeable="MERGEABLE", draft=False):
    return {
        "headRefOid": HEAD, "isDraft": draft, "mergeable": mergeable, "createdAt": T0,
        "files": {"nodes": [{"path": f} for f in files]},
        "commits": {"nodes": [{"commit": {"committedDate": committed, "statusCheckRollup": {"state": ci}}}]},
        "reviews": {"nodes": [{"submittedAt": t, "commit": {"oid": sha}} for t, sha in reviews]},
        "comments": {"nodes": [{"body": b, "createdAt": t} for b, t in comments]},
        "reviewThreads": {"nodes": [{"isResolved": False, "comments": {"nodes": [{"createdAt": t}]}}
                                    for t in threads]},
    }


SCREEN = ("ios/Features/Setup/SetupView.swift",)
cases = [
    ("first review", pr(), "review", "리뷰 세션"),
    ("open threads on the reviewed head", pr(reviews=[(T2, HEAD)], threads=[T2]), "fixing", "author"),
    ("new commits after the review", pr(reviews=[(T2, OLD)], threads=[T2]), "rereview", "리뷰 세션"),
    ("author replied on every open thread", pr(reviews=[(T2, HEAD)], threads=[T3]), "rereview", "리뷰 세션"),
    ("one thread still unanswered", pr(reviews=[(T2, HEAD)], threads=[T3, T2]), "fixing", "author"),
    ("a push after an LGTM-only pass is a re-review",
     pr(comments=[(f"LGTM at {OLD[:7]}", T2)]), "rereview", "리뷰 세션"),
    ("docs PR with LGTM at head merges", pr(comments=[(f"LGTM at {HEAD[:7]}", T2)]), "merge", "author"),
    ("screen PR with LGTM waits for the user",
     pr(files=SCREEN, comments=[(f"LGTM at {HEAD[:7]}", T2)]), "user", "사용자"),
    ("a stale iPad OK doesn't count",
     pr(files=SCREEN, comments=[(f"iPad OK at {OLD[:7]}", T1), (f"LGTM at {HEAD[:7]}", T2)]), "user", "사용자"),
    ("iPad OK at the head merges",
     pr(files=SCREEN, comments=[(f"LGTM at {HEAD[:7]}", T2), (f"iPad OK at {HEAD[:7]}", T3)]), "merge", "author"),
    ("red CI goes back to the author", pr(ci="FAILURE", comments=[(f"LGTM at {HEAD[:7]}", T2)]), "fixing", "author"),
    ("a conflict goes back to the author", pr(mergeable="CONFLICTING"), "fixing", "author"),
]

passed = failed = 0
for name, p, lane, actor in cases:
    got_lane, got_actor, what, *_ = board.classify(p, "author")
    if (got_lane, got_actor) == (lane, actor):
        passed += 1
    else:
        failed += 1
        print(f"FAIL {name}: got {got_lane}/{got_actor} ({what}), want {lane}/{actor}")
# Local branch verdicts: "delete" only when nothing local can be lost.
MERGED = {"number": 9}
verdicts = [
    ("open PR is in progress", ("feature/x", {"number": 1}, 0, None, None, False, 3, False, 2), "active"),
    ("uncommitted changes need a decision", ("feature/x", None, 2, "merged", MERGED, True, 0, True, 0), "decide"),
    ("tip inside the merged PR is safe", ("feature/x", None, 0, "merged", MERGED, True, 4, False, 3), "delete"),
    ("commits after the merge are kept",  # the remote was deleted, so nothing says "ahead"
     ("feature/x", None, 0, "merged", MERGED, False, 5, False, 3), "decide"),
    ("no commits beyond develop is safe", ("feature/x", None, 0, None, None, False, 0, False, 0), "delete"),
    ("files already match develop is safe", ("feature/x", None, 0, None, None, False, 2, True, 4), "delete"),
    ("a PR closed unmerged needs a decision", ("feature/x", None, 0, "closed", MERGED, False, 2, False, 4), "decide"),
    ("a local-only branch needs a decision", ("local/x", None, 0, None, None, False, 1, False, 1), "decide"),
]
for name, args, want in verdicts:
    got, why = board.branch_verdict(*args)
    if got == want:
        passed += 1
    else:
        failed += 1
        print(f"FAIL {name}: got {got} ({why}), want {want}")
# Deep links open only well-formed desktop session ids.
for value, want in [("local_5a2bb023-eff5-4f72-b7db-356a241b64c3",
                     "claude://code/continue?session=local_5a2bb023-eff5-4f72-b7db-356a241b64c3"),
                    ("local_x&y=1", None), ("8e36d840-0433", None), (None, None)]:
    got = board.session_link(value)
    if got == want:
        passed += 1
    else:
        failed += 1
        print(f"FAIL session_link({value!r}): got {got}, want {want}")
print(f"board: {passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
EOF
