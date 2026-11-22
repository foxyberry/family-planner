#!/bin/bash
# Tests for tools/board/board.py classify(): each PR lands in the lane of its next step on the
# pr-review-handoff loop, with the right actor. Pure Python, no GitHub, runs anywhere (CI included).
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
BOARD="$HERE/../../tools/board/board.py"

python3 -I - "$BOARD" <<'EOF'
import importlib.util, json, sys

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
# A question waits only when it came after the user's last turn; missing times never crash.
for args, want in [(("2026-11-21T03:00:00Z", "2026-11-21T02:00:00Z"), True),
                   (("2026-11-21T02:00:00Z", "2026-11-21T03:00:00Z"), False),
                   (("2026-11-21T02:00:00Z", None), True), ((None, "2026-11-21T03:00:00Z"), False),
                   ((None, None), False)]:
    if board.is_waiting(*args) == want:
        passed += 1
    else:
        failed += 1
        print(f"FAIL is_waiting{args}: want {want}")
# GitHub is asked at most once a minute for open PRs and every 10 minutes for the history; a failure
# keeps the last answer and waits the same gap.
calls, clock, fail = [], [1000.0], [False]
def fake_run(cmd):
    calls.append("ended" if "allMerged" in cmd[-1] else "open")
    if fail[0] == "ended" and "allMerged" in cmd[-1]:
        return 1, "", "history refused"
    if fail[0] is True:
        return 1, "", "rate limit"
    data = {"open": {"nodes": [{"number": 1}]}, "merged": {"nodes": []}, "allMerged": {"nodes": []},
            "oldMerged": {"nodes": [{"headRefName": "feature/a"}]}, "closed": {"nodes": []}}
    return 0, json.dumps({"data": {"repository": data}}), ""
board.run = fake_run
board.time = type("T", (), {"time": staticmethod(lambda: clock[0])})
def step(seconds, want_calls, name, failing=False):
    global passed, failed
    clock[0] += seconds
    fail[0] = failing
    calls.clear()
    try:
        result = board.fetch_prs("o/r")
    except RuntimeError:
        result = None
    if calls == want_calls and result is not None and result[0] == [{"number": 1}]:
        passed += 1
    else:
        failed += 1
        print(f"FAIL fetch_prs {name}: calls {calls}, result {result}")
step(0, ["open", "ended"], "first build asks both")
step(15, [], "a reload 15 s later asks nothing")
step(50, ["open"], "after a minute only the open PRs")
step(61, ["open"], "a failure keeps the last answer", failing=True)
if board._github["error"] == "rate limit":
    passed += 1
else:
    failed += 1
    print("FAIL fetch_prs: the failure message is kept")
step(15, [], "a failure waits the gap too")
step(600, ["open", "ended"], "after 10 minutes the history again")
board._github.update(ended=None, ended_at=0.0, open_at=0.0)
step(0, ["open", "ended"], "a fresh board whose history is refused", failing="ended")
step(61, ["open", "ended"], "an unread history retries with the open PRs, not after 10 minutes")
# Each session maps to the issue owner whose word comes first in its title.
for title, want in [("가족 플래너 구현 (iPad 앱, M2→MVP: 홈·C6·아침 미션, 하네스·가드)", "main"),
                    ("Family-planner 하네스 (스킬·가드·2차 리뷰)", "harness"),
                    ("Family-planner iOS 코드 리뷰", "review"),
                    ("가족 플래너 디자인·기획 (Hi-Fi 캔버스, 키트, 명세, 백로그)", "design"),
                    ("Some other project", None), (None, None)]:
    if board.owner_of_title(title) == want:
        passed += 1
    else:
        failed += 1
        print(f"FAIL owner_of_title({title!r}): want {want}, got {board.owner_of_title(title)}")

# An owner needs the user's nudge only when every session rests, none asks, nothing is in hand
# (no doing issue, no open PR) and open issues are left.
def issue(n, status="open"):
    return {"number": n, "title": f"Issue {n}", "status": status, "owner": "harness"}
rest = {"busy": False, "asking": False, "prs": 0}
for name, o, want in [
    ("resting with open issues", dict(rest, issues=[issue("003"), issue("004")]), ["003", "004"]),
    ("busy", dict(rest, busy=True, issues=[issue("003")]), []),
    ("asking the user", dict(rest, asking=True, issues=[issue("003")]), []),
    ("an open PR in hand", dict(rest, prs=1, issues=[issue("003")]), []),
    ("a doing issue in hand", dict(rest, issues=[issue("003", "doing 2026-11-22 17:10"), issue("004")]), []),
    ("only closed issues", dict(rest, issues=[issue("003", "done 2026-11-22")]), []),
]:
    got = [i["number"] for _, items in board.idle_with_issues({"harness": o}) for i in items]
    if got == want:
        passed += 1
    else:
        failed += 1
        print(f"FAIL idle_with_issues {name}: want {want}, got {got}")
# A session owns the branches it cut, whatever flags come before -c / -b.
for line, want in [(b"git switch -q -c feature/a origin/develop", "feature/a"), (b"git checkout -b feature/b", "feature/b"),
                   (b"git switch -c feature/c", "feature/c"), (b"git checkout --quiet -B feature/d x", "feature/d"),
                   (b"git worktree add ../w -b feature/e", "feature/e"), (b"git switch feature/f", None)]:
    m = board.NEW_BRANCH.search(line)
    got = (m.group(1) or m.group(2)).decode() if m else None
    if got == want:
        passed += 1
    else:
        failed += 1
        print(f"FAIL NEW_BRANCH {line!r}: want {want}, got {got}")
print(f"board: {passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
EOF
