#!/usr/bin/env python3
"""Local status board for the sessions that work on this repo at the same time.

It reads three things on this Mac and writes one HTML page (tools/board/out/index.html, git-ignored):
  - GitHub, through `gh`: open PRs on the pr-review-handoff loop (review, fixes, re-review, LGTM,
    iPad check, merge) and the PRs merged lately;
  - Claude Code transcripts (~/.claude/projects): each session's title, the PRs and branches it
    created and the folder it works in;
  - git and the machine: worktrees, local-only branches and commits, Bazel servers, simulators;
  - local issues: .claude/issues/*.md in the main checkout (git-ignored; scripts/issue.sh).

  python3 tools/board/board.py            # write the page once
  python3 tools/board/board.py --serve    # http://127.0.0.1:8765, rebuilt in the background while open

Nothing leaves the Mac: the server listens on 127.0.0.1 only and the page stays git-ignored.
"""
import argparse
import datetime as dt
import glob
import html
import http.server
import json
import os
import re
import subprocess
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
PAGE = os.path.join(OUT, "index.html")
CACHE = os.path.join(OUT, "sessions-cache.json")
PROJECTS = os.path.expanduser("~/.claude/projects")
SESSION_DAYS = 3          # sessions idle longer than this are hidden
MERGED_HOURS = 36         # merged PRs shown in the last lane
SCREEN_DIRS = ("ios/Features/", "ios/AppCore/", "ios/DesignSystem/", "ios/KitArt/")
LGTM = re.compile(r"^\s*LGTM at ([0-9a-f]{7,40})", re.I | re.M)
# The user's iPad check covers one head, like an LGTM: "iPad OK at <sha>" (pr-review-handoff step 8).
IPAD_OK = re.compile(r"^\s*iPad OK at ([0-9a-f]{7,40})", re.I | re.M)

TYPES = {"feat": "기능", "fix": "버그 수정", "docs": "문서", "refactor": "리팩터", "test": "테스트",
         "build": "빌드", "ci": "CI", "chore": "정리", "perf": "성능", "style": "스타일"}
AREAS = [  # (label, path prefixes)
    ("화면", ("ios/Features/", "ios/AppCore/")),
    ("디자인 시스템", ("ios/DesignSystem/", "ios/KitArt/", "tools/crayon-art/")),
    ("도메인·클라이언트", ("ios/Domain/", "ios/Clients/", "ios/Strings/")),
    ("스펙·보드", ("docs/superpowers/",)),
    ("하네스", (".claude/", "scripts/", ".githooks/", "tools/board/", "CLAUDE.md")),
    ("빌드", ("MODULE.bazel", "Makefile", ".bazelrc", "ios/BUILD.bazel", "ios/build_defs.bzl", "Package.")),
]


def run(args, cwd=None, timeout=60):
    try:
        p = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout, p.stderr
    except (OSError, subprocess.TimeoutExpired) as e:
        return 1, "", str(e)


def git(*args, cwd=None):
    code, out, _ = run(["git", *args], cwd=cwd or HERE)
    return out.strip() if code == 0 else None


def now():
    return dt.datetime.now(dt.timezone.utc)


def parse_time(s):
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00")) if s else None


def ago(t):
    if not t:
        return ""
    s = int((now() - t).total_seconds())
    if s < 90:
        return "방금"
    if s < 3600:
        return f"{s // 60}분 전"
    if s < 86400:
        return f"{s // 3600}시간 전"
    return f"{s // 86400}일 전"


# ---------------------------------------------------------------- sessions (Claude transcripts)

TITLE = re.compile(rb'"(?:customTitle|agentName)":"((?:[^"\\]|\\.)*)"')
CWD = re.compile(rb'"cwd":"((?:[^"\\]|\\.)*)"')
EMPTY = {"v": 4, "active_at": None, "offset": 0, "title": None, "cwd": None, "prs": [], "branches": [], "related": False,
         "ask": None, "user_at": None}
# Messages that reach a session as a user turn but are not the user's own words.
NOT_USER = ("<ci-monitor-event", "<cross-session-message", "<side-sessions-event", "<system-reminder",
            "<task-notification", "<command-", "<local-command", "Another Claude session sent a message")
# Other flags may come first (`git switch -q -c <branch>`).
NEW_BRANCH = re.compile(rb'(?:checkout|switch)(?:\s+-{1,2}[A-Za-z-]+)*?\s+-[bcBC]\s+([A-Za-z0-9._/-]+)|worktree add[^"]*?\s-b\s+([A-Za-z0-9._/-]+)')


def scan_sessions(repo_root, slug):
    """Each recent session's title, folder, created PRs and branches, read incrementally."""
    try:
        with open(CACHE) as fh:
            cache = json.load(fh)
    except (OSError, ValueError):
        cache = {}
    # Claude Code records a PR a Bash call opened as gitOperation.pr with action "created".
    pr_url = re.compile(rb'"gitOperation":\{"pr":\{"number":(\d+),"url":"https://github\.com/'
                        + re.escape(slug.encode()) + rb'/pull/\d+","action":"created"')
    cutoff = time.time() - SESSION_DAYS * 86400
    sessions = {}
    for path in glob.glob(os.path.join(PROJECTS, "*", "*.jsonl")):
        mtime = os.path.getmtime(path)
        if mtime < cutoff:
            continue
        sid = os.path.basename(path)[:-6]
        c = cache.get(path)
        size = os.path.getsize(path)
        if not c or size < c["offset"] or c.get("v") != EMPTY["v"]:
            c = dict(EMPTY, prs=[], branches=[])
        mine = b'"sessionId":"' + sid.encode() + b'"'
        root_b, slug_b = repo_root.encode(), slug.encode()
        with open(path, "rb") as fh:
            fh.seek(c["offset"])
            data = fh.read()
        end = data.rfind(b"\n") + 1  # keep a half-written last line for the next pass
        for line in data[:end].split(b"\n"):
            if mine not in line:  # a fork's copy of its parent's lines belongs to the parent
                continue
            if b'"type":"assistant"' in line:
                m = re.search(rb'"timestamp":"([^"]+)"', line)
                if m:
                    c["active_at"] = m.group(1).decode()
            if not c["related"] and (root_b in line or slug_b in line):
                c["related"] = True
            if b'"customTitle"' in line or b'"agentName"' in line:
                m = TITLE.search(line)
                if m:
                    c["title"] = json.loads(b'"' + m.group(1) + b'"')
            if b'"cwd"' in line:
                m = CWD.search(line)
                if m:
                    c["cwd"] = json.loads(b'"' + m.group(1) + b'"')
            if b'"gitOperation"' in line:
                for m in pr_url.finditer(line):
                    n = int(m.group(1))
                    if n not in c["prs"]:
                        c["prs"].append(n)
            # A question the session left for the user (wrap_up's ask), and the user's last own turn.
            if b'"name":"mcp__ccd_turn__wrap_up"' in line and b'"tool_use"' in line:
                try:
                    d = json.loads(line)
                except ValueError:
                    continue
                for part in d.get("message", {}).get("content", []):
                    if isinstance(part, dict) and part.get("name") == "mcp__ccd_turn__wrap_up":
                        inp = part.get("input", {})
                        c["ask"] = ({"text": inp["ask"], "blocked": bool(inp.get("blocked")),
                                     "at": d.get("timestamp"), "recap": inp.get("recap", "")}
                                    if inp.get("ask") else None)
            elif b'"type":"user"' in line and b"tool_result" not in line:
                try:
                    d = json.loads(line)
                except ValueError:
                    continue
                content = d.get("message", {}).get("content", "")
                text = content if isinstance(content, str) else " ".join(
                    x.get("text", "") for x in content if isinstance(x, dict))
                if not d.get("isMeta") and text.strip() and not text.lstrip().startswith(NOT_USER):
                    c["user_at"] = d.get("timestamp")
            if b'"tool_use"' in line and (b"-b " in line or b"-c " in line):
                for m in NEW_BRANCH.finditer(line):
                    b = (m.group(1) or m.group(2)).decode()
                    if b not in c["branches"]:
                        c["branches"].append(b)
        c["offset"] += end
        cache[path] = c
        if c["related"]:
            ask = c.get("ask")
            waiting = ask if ask and is_waiting(ask.get("at"), c.get("user_at")) else None
            sessions[sid] = {"id": sid, "title": c["title"] or sid[:8], "cwd": c["cwd"], "prs": c["prs"],
                             "branches": c["branches"], "waiting": waiting,
                             "mtime": parse_time(c.get("active_at")) or dt.datetime.fromtimestamp(mtime, dt.timezone.utc)}
    # Keep only this repo's sessions in full; for other projects keep just the read offset.
    slim = {k: (v if v["related"] else {**EMPTY, "offset": v["offset"]})
            for k, v in cache.items() if os.path.exists(k)}
    os.makedirs(OUT, exist_ok=True)
    fd = os.open(CACHE, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as fh:
        json.dump(slim, fh)
    return sessions


DESKTOP = os.path.expanduser("~/Library/Application Support/Claude/claude-code-sessions")
LOCAL_ID = re.compile(r"^local_[A-Za-z0-9-]{1,64}$")


def session_link(local_id):
    """The Claude desktop app opens a Code session from claude://code/continue?session=local_<id>."""
    return f"claude://code/continue?session={local_id}" if local_id and LOCAL_ID.match(local_id) else None


def ms(value):
    try:
        return dt.datetime.fromtimestamp(int(value) / 1000, dt.timezone.utc)
    except (TypeError, ValueError):
        return None


def desktop_sessions():
    """The desktop app's own record of each Code session: its local id (for the deep link), title,
    archived flag, turn times, last report and its post-turn summary (status and needs_action),
    keyed by the Claude Code session id that names the transcript."""
    out = {}
    for path in glob.glob(os.path.join(DESKTOP, "*", "*", "local_*.json")):
        try:
            with open(path) as fh:
                d = json.load(fh)
        except (OSError, ValueError):
            continue
        summary = d.get("postTurnSummary") if isinstance(d.get("postTurnSummary"), dict) else {}
        rec = {"local": d.get("sessionId"), "title": d.get("title"), "archived": bool(d.get("isArchived")),
               "activity": ms(d.get("lastActivityAt")), "edge": ms(d.get("lastTurnEdgeAt")),
               "report": d.get("lastTurnReport") or "", "status": summary.get("status_detail") or "",
               "needs": summary.get("needs_action") or "", "awaiting": bool(d.get("interruptedAwaitingPerson"))}
        for key in (d.get("cliSessionId"), d.get("lastAssistantCliSessionId")):
            if key:
                out.setdefault(key, rec)
    return out


def is_waiting(asked_at, user_at):
    """A question waits when it came after the user's last own turn (ISO times; either may be missing)."""
    if not asked_at:
        return False
    return not user_at or asked_at > user_at


def session_state(s):
    """busy: inside a turn now; recent: a turn ended in the last 30 minutes; idle otherwise."""
    d = s.get("desk") or {}
    if d.get("activity") and d.get("edge"):
        if d["activity"] > d["edge"] + dt.timedelta(seconds=3) and (now() - d["activity"]).total_seconds() < 900:
            return "busy", "작업 중"
        return ("recent", "방금 턴을 마침") if (now() - d["edge"]).total_seconds() < 1800 else ("idle", "쉬는 중")
    idle = (now() - s["mtime"]).total_seconds()
    if idle < 120:
        return "busy", "작업 중"
    if idle < 1800:
        return "recent", "조금 전까지 작업"
    return "idle", "쉬는 중"


# ---------------------------------------------------------------- GitHub

PR_FIELDS = """
number title url headRefName headRefOid isDraft mergeable updatedAt createdAt
commits(last: 1) { nodes { commit { committedDate statusCheckRollup { state } } } }
reviews(last: 30) { nodes { submittedAt commit { oid } } }
reviewThreads(first: 100) { nodes { isResolved comments(last: 1) { nodes { createdAt } } } }
comments(last: 40) { nodes { body createdAt } }
files(first: 100) { nodes { path } }
"""


# GitHub is shared by every session and tool on this account (5,000 GraphQL points an hour, plus
# secondary limits on bursts). The page reloads every 15 s, so the board asks GitHub far less often
# than it rebuilds: open and recently merged PRs at most once a minute, the merged and closed history
# (for local branches' verdicts) every 10 minutes. A failed ask waits the same gap before the next
# one, and the board keeps showing what it last read.
OPEN_GAP, ENDED_GAP = 60, 600
_github = {"open": None, "open_at": 0.0, "read_at": 0.0, "ended": None, "ended_at": 0.0, "error": ""}


def graphql(slug, fields):
    owner, name = slug.split("/")
    code, out, err = run(["gh", "api", "graphql", "-f",
                          f'query=query {{ repository(owner: "{owner}", name: "{name}") {{ {fields} }} }}'])
    if code != 0:
        raise RuntimeError(err.strip() or "gh api graphql failed")
    return json.loads(out)["data"]["repository"]


def fetch_prs(slug):
    """(open PRs, recently merged PRs, {branch: (merged|closed, pr)}), from GitHub at most every
    OPEN_GAP / ENDED_GAP seconds and otherwise from the last answer. Raises only when nothing was
    ever read; a later failure keeps the last answer and leaves its message in _github["error"]."""
    t = time.time()
    _github["error"] = ""
    if t - _github["open_at"] > OPEN_GAP:
        _github["open_at"] = t
        try:
            repo = graphql(slug, f'open: pullRequests(states: OPEN, first: 40, orderBy: {{field: UPDATED_AT, direction: DESC}}) {{ nodes {{ {PR_FIELDS} }} }} '
                                 f'merged: pullRequests(states: MERGED, first: 15, orderBy: {{field: UPDATED_AT, direction: DESC}}) '
                                 f'{{ nodes {{ number title url headRefName mergedAt files(first: 100) {{ nodes {{ path }} }} }} }}')
            _github["open"], _github["read_at"] = (repo["open"]["nodes"], repo["merged"]["nodes"]), t
        except Exception as e:
            _github["error"] = str(e)
    # The history waits ENDED_GAP once read; until then it retries with the open PRs.
    if t - _github["ended_at"] > (ENDED_GAP if _github["ended"] is not None else OPEN_GAP):
        _github["ended_at"] = t
        try:
            repo = graphql(slug, 'allMerged: pullRequests(states: MERGED, last: 100) { nodes { number url headRefName headRefOid } } '
                                 'oldMerged: pullRequests(states: MERGED, first: 100) { nodes { number url headRefName headRefOid } } '
                                 'closed: pullRequests(states: CLOSED, last: 50) { nodes { number url headRefName headRefOid } }')
            ended = {p["headRefName"]: ("merged", p) for p in repo["oldMerged"]["nodes"] + repo["allMerged"]["nodes"]}
            ended.update({p["headRefName"]: ("closed", p) for p in repo["closed"]["nodes"] if p["headRefName"] not in ended})
            _github["ended"] = ended
        except Exception as e:
            _github["error"] = _github["error"] or str(e)
    if _github["open"] is None:
        raise RuntimeError(_github["error"] or "GitHub not read yet")
    return _github["open"][0], _github["open"][1], _github["ended"] or {}


def category(title, files):
    m = re.match(r"(\w+)(?:\(([^)]+)\))?!?:", title)
    chips = []
    if m:
        chips.append(TYPES.get(m.group(1), m.group(1)) + (f" · {m.group(2)}" if m.group(2) else ""))
    for label, prefixes in AREAS:
        if any(f.startswith(prefixes) for f in files):
            chips.append(label)
    return chips


def changes_screen(files):
    return any(f.startswith(SCREEN_DIRS) and "/Tests/" not in f and "SnapshotTests" not in f for f in files)


def classify(pr, author):
    """Where the PR stands on the review loop and who has to act next:
    (lane, actor, what, since, flags, screen). `actor` "리뷰 세션" is filled in by the caller."""
    head = pr["headRefOid"]
    files = [n["path"] for n in pr["files"]["nodes"]]
    commit = (pr["commits"]["nodes"] or [{}])[0].get("commit") or {}
    ci = ((commit.get("statusCheckRollup") or {}).get("state") or "NONE").upper()
    since = parse_time(commit.get("committedDate"))
    # Review events: formal reviews and LGTM comments, each tied to the head it covered.
    events = [(parse_time(r["submittedAt"]), (r.get("commit") or {}).get("oid", ""))
              for r in pr["reviews"]["nodes"] if r.get("submittedAt")]
    lgtm_sha = lgtm_at = None
    ipad_ok = False
    for c in pr["comments"]["nodes"]:
        m = LGTM.search(c["body"])
        if m:
            lgtm_sha, lgtm_at = m.group(1), parse_time(c["createdAt"])
            events.append((lgtm_at, lgtm_sha))
        m = IPAD_OK.search(c["body"])
        if m and head.startswith(m.group(1)):
            ipad_ok = True
    last = max(events, key=lambda e: e[0]) if events else None
    threads = [t for t in pr["reviewThreads"]["nodes"] if not t["isResolved"]]
    # The author answered every open thread after the last review: the reviewer's turn.
    replied = bool(threads) and last is not None and all(
        (t["comments"]["nodes"] or [{}])[-1].get("createdAt")
        and parse_time(t["comments"]["nodes"][-1]["createdAt"]) > last[0] + dt.timedelta(seconds=5)
        for t in threads)
    screen = changes_screen(files)
    lgtm_here = bool(lgtm_sha and head.startswith(lgtm_sha))
    flags = []
    if ci in ("FAILURE", "ERROR"):
        flags.append(("bad", "CI 실패"))
    elif ci == "PENDING":
        flags.append(("wait", "CI 진행 중"))
    elif ci == "SUCCESS":
        flags.append(("good", "CI 통과"))
    if pr["mergeable"] == "CONFLICTING":
        flags.append(("bad", "충돌"))
    if threads:
        flags.append(("wait", f"열린 스레드 {len(threads)}" + (" (작성자 답글 달림)" if replied else "")))
    if screen:
        flags.append(("info", "iPad 확인됨 (현재 헤드)" if ipad_ok else "iPad 확인 필요"))
    if lgtm_sha and not lgtm_here:
        flags.append(("wait", "LGTM 뒤 새 푸시"))

    if pr["isDraft"]:
        return "draft", author, "초안: 작성 중", since, flags, screen
    if ci in ("FAILURE", "ERROR") or pr["mergeable"] == "CONFLICTING":
        what = "CI 고치기" if ci in ("FAILURE", "ERROR") else "develop 충돌 해결"
        return "fixing", author, what, since, flags, screen
    if lgtm_here:
        if screen and not ipad_ok:
            return "user", "사용자", f"iPad에서 화면 확인 (확인되면 PR에 'iPad OK at {head[:7]}')", lgtm_at, flags, screen
        return "merge", author, "머지하기 (LGTM · CI 통과)" if ci == "SUCCESS" else "CI 끝나면 머지", lgtm_at, flags, screen
    if not last:
        return "review", "리뷰 세션", "첫 리뷰", parse_time(pr["createdAt"]), flags, screen
    if last[1] and not head.startswith(last[1]):
        return "rereview", "리뷰 세션", "새 커밋 재리뷰", since, flags, screen
    if replied:
        return "rereview", "리뷰 세션", f"작성자 답글 {len(threads)}개 확인", last[0], flags, screen
    if threads:
        return "fixing", author, f"리뷰 코멘트 {len(threads)}개 반영 또는 답글", last[0], flags, screen
    return "rereview", "리뷰 세션", "남은 지적 없음: LGTM 또는 다음 리뷰", last[0], flags, screen


# ---------------------------------------------------------------- git and the machine

def worktrees():
    out = git("worktree", "list", "--porcelain") or ""
    items, cur = [], {}
    for line in out.splitlines() + [""]:
        if not line:
            if cur:
                items.append(cur)
            cur = {}
        elif line.startswith("worktree "):
            cur["path"] = line[9:]
        elif line.startswith("branch "):
            cur["branch"] = line[7:].replace("refs/heads/", "")
        elif line.startswith("HEAD "):
            cur["head"] = line[5:]
        elif line == "detached":
            cur["branch"] = None
        elif line.startswith("prunable"):
            cur["prunable"] = True
    for w in items:
        if w.get("prunable") or not os.path.isdir(w["path"]):
            w["missing"] = True
            continue
        status = git("status", "--porcelain", cwd=w["path"]) or ""
        w["dirty"] = len([l for l in status.splitlines() if l.strip()])
        ahead = git("rev-list", "--count", "@{u}..HEAD", cwd=w["path"])
        w["ahead"] = int(ahead) if ahead is not None else None  # None: no upstream
    return items


_last_fetch = [0.0]
_base_tip = [""]


def fetch_origin():
    """Keep origin/develop and the gone-upstream marks fresh (at most every 5 minutes)."""
    if time.time() - _last_fetch[0] > 300:
        run(["git", "fetch", "-q", "--prune", "origin"], cwd=HERE, timeout=60)
        _last_fetch[0] = time.time()


_analysis = {}  # (branch tip, develop tip) -> analysis; a branch is re-read only when either moves


def analyze_branch(name, tip, base="origin/develop"):
    """What a local branch holds compared with develop: its last commit, size and whether its
    changes are already there (a squash merge leaves the branch's own commits out of develop)."""
    key = (tip, _base_tip[0])
    if key in _analysis:
        return _analysis[key]
    log = git("log", "-1", "--format=%s%x1f%ct", name) or "\x1f0"
    subject, when = log.split("\x1f")
    ahead = int(git("rev-list", "--count", f"{base}..{name}") or 0)
    mb = git("merge-base", base, name)
    files = (git("diff", "--name-only", f"{mb}..{name}") or "").splitlines() if mb else []
    # Pathspecs are relative to the working directory, and the diff names files from the repo top.
    same = bool(files) and run(["git", "diff", "--quiet", base, name, "--", *[":(top)" + f for f in files]], cwd=HERE)[0] == 0
    _analysis[key] = {"subject": subject, "when": int(when or 0), "ahead": ahead, "files": files, "in_develop": same}
    return _analysis[key]


def shipped(tip, pr_head):
    """The branch's tip is the merged PR's head, or an ancestor of it (nothing came after)."""
    if not pr_head:
        return False
    return tip == pr_head or run(["git", "merge-base", "--is-ancestor", tip, pr_head], cwd=HERE)[0] == 0


def branch_verdict(name, pr, dirty, end_state, end_pr, is_shipped, ahead, in_develop, nfiles):
    """In progress, decide, or safe to delete. Safe only when nothing local can be lost: the tip is
    in a merged PR, the branch has no commits beyond develop, or every file it changed matches develop."""
    if pr:
        return "active", f'PR #{pr["number"]} 진행 중'
    if dirty:
        return "decide", "커밋 안 된 변경이 있음: 살릴지 정해야 함"
    if is_shipped:
        return "delete", f'PR #{end_pr["number"]} 머지됨 (이 브랜치 끝이 그 PR에 들어감)'
    if ahead == 0:
        return "delete", "develop에 이미 포함 (새 커밋 없음)"
    if in_develop:
        return "delete", "바뀐 파일이 develop과 같음 (내용이 이미 들어감)"
    if end_state == "merged":
        why = f'PR #{end_pr["number"]}는 머지됐지만 그 뒤 커밋이 더 있음'
    elif end_state == "closed":
        why = f'PR #{end_pr["number"]} 머지 없이 닫힘'
    else:
        why = f"develop에 없는 변경: 커밋 {ahead} · 파일 {nfiles}"
    if name.startswith("backup/"):
        why += " (백업: 원본이 머지됐으면 삭제 가능)"
    return "decide", why


def local_work(wts, open_by_branch, ended, by_branch, owner_of, repo_root):
    """Every local branch with its story and a verdict: in progress, decide, or safe to delete."""
    fmt = "%(refname:short)|%(upstream:short)|%(upstream:track)|%(objectname)"
    refs = {}
    for line in (git("for-each-ref", "--format=" + fmt, "refs/heads") or "").splitlines():
        name, upstream, track, tip = line.split("|")
        refs[name] = (upstream, track, tip)
    _base_tip[0] = git("rev-parse", "origin/develop") or ""
    tree_of = {w.get("branch"): w for w in wts if w.get("branch") and not w.get("missing")}
    items = []
    for name, (upstream, track, tip) in refs.items():
        if name in ("main", "develop"):
            continue
        a = analyze_branch(name, tip)
        w = tree_of.get(name)
        dirty = (w or {}).get("dirty", 0)
        unpushed = None if not upstream or "gone" in track else int(re.sub(r"\D", "", track.split(",")[0]) or 0) if "ahead" in track else 0
        pr = open_by_branch.get(name)
        end_state, end_pr = ended.get(name, (None, None))
        notes = []
        if dirty:
            notes.append(f"커밋 안 된 변경 {dirty}")
        if not upstream:
            notes.append("push 안 함")
        elif "gone" in track:
            notes.append("원격 브랜치 삭제됨")
        elif unpushed:
            notes.append(f"push 안 된 커밋 {unpushed}")
        is_shipped = end_state == "merged" and shipped(tip, end_pr.get("headRefOid"))
        verdict, why = branch_verdict(name, pr, dirty, end_state, end_pr, is_shipped, a["ahead"],
                                      a["in_develop"], len(a["files"]))
        s_ = by_branch.get(name)
        who = (owner_of(w["path"]) if w and w["path"] != repo_root else "") or (s_["title"] if s_ else "")
        items.append({"branch": name, "tree": w, "notes": notes, "verdict": verdict, "why": why,
                      "areas": category("", a["files"]), "pr": pr or end_pr, **a, "who": who})
    for w in wts:  # worktrees whose folder is gone
        if w.get("missing"):
            items.append({"branch": w.get("branch") or "detached", "tree": w, "notes": ["폴더 없음"],
                          "verdict": "delete", "why": "worktree 폴더가 없음: git worktree prune", "areas": [],
                          "pr": None, "subject": "", "when": 0, "ahead": 0, "files": [], "who": ""})
    return sorted(items, key=lambda i: -i["when"])


def read_issues(repo_root):
    """Local issues (.claude/issues/*.md in the main checkout): title from the first `# ` line,
    `key: value` lines (owner, status, opened, area) before the first `##` section."""
    issues = []
    folder = os.path.join(repo_root, ".claude", "issues")
    for name in sorted(os.listdir(folder)) if os.path.isdir(folder) else []:
        if not name.endswith(".md"):
            continue
        number = re.match(r"(\d+)-", name)
        issue = {"file": name, "number": number.group(1) if number else "", "title": name[:-3], "owner": "",
                 "status": "open", "opened": "", "area": ""}
        with open(os.path.join(folder, name), encoding="utf-8") as f:
            for line in f:
                if line.startswith("## "):
                    break
                if line.startswith("# "):
                    issue["title"] = line[2:].strip()
                elif ":" in line:
                    key, value = line.split(":", 1)
                    if key.strip() in ("owner", "status", "opened", "area"):
                        issue[key.strip()] = value.strip()
        issues.append(issue)
    return issues


# Which local-issue owner a session is: the owner word that comes first in its title ("가족 플래너
# 구현 (…, 하네스·가드)" is main; "Family-planner 하네스 (…, 2차 리뷰)" is harness).
OWNER_WORDS = {"구현": "main", "리뷰": "review", "review": "review", "디자인": "design", "design": "design",
               "하네스": "harness", "harness": "harness"}


def owner_of_title(title):
    title = (title or "").lower()
    found = [(title.find(word), owner) for word, owner in OWNER_WORDS.items() if word in title]
    return min(found)[1] if found else None


def is_doing(issue):
    return (issue["status"].split() or [""])[0] == "doing"


def is_open(issue):
    return (issue["status"].split() or ["open"])[0] not in ("closed", "done")


def idle_with_issues(owners):
    """Owners whose sessions all rest (none busy, none asking the user) with open issues left but
    nothing in hand: no doing issue and no open PR. `owners` maps an owner to {"busy", "asking", "prs",
    "issues"}; returns [(owner, open issues)] for the user to look at."""
    out = []
    for owner, o in sorted(owners.items()):
        waiting = [i for i in o["issues"] if is_open(i) and not is_doing(i)]
        if o["busy"] or o["asking"] or o["prs"] or any(is_doing(i) for i in o["issues"]) or not waiting:
            continue
        out.append((owner, waiting))
    return out


def issue_line(i):
    # Sessions and the user name issues by number (scripts/issue.sh close <n>), so it leads.
    number = f'<b>이슈 {esc(i["number"])}</b> ' if i["number"] else ""
    return (f'<li>{number}{esc(i["title"])} <span class="soft">({esc(i["status"])}'
            f'{" · " + esc(i["opened"]) if i["opened"] else ""})</span></li>')


def issue_list(owner, items, shown=2):
    """One owner's waiting issues: the first `shown`, the rest behind "N건 더 보기" (a fold that
    keeps its state over the reload, like every fold)."""
    if not items:
        return '<div class="meta soft">남은 이슈 없음</div>'
    h = [f'<ul class="issues">{"".join(issue_line(i) for i in items[:shown])}</ul>']
    if len(items) > shown:
        h.append(f'<details data-id="issues-{esc(owner)}"><summary class="soft">{len(items) - shown}건 더 보기</summary>'
                 f'<ul class="issues">{"".join(issue_line(i) for i in items[shown:])}</ul></details>')
    return "".join(h)


def machine():
    info = {}
    code, out, _ = run(["pgrep", "-f", "A-server.jar"])
    servers = []
    for pid in out.split():
        _, ps, _ = run(["ps", "-o", "rss=,command=", "-p", pid])
        m = re.search(r"--workspace_directory=(\S+)", ps)
        rss = int(ps.split()[0]) // 1024 if ps.split() else 0
        servers.append((os.path.basename(m.group(1)) if m else pid, rss))
    info["bazel"] = servers
    code, out, _ = run(["xcrun", "simctl", "list", "devices", "booted", "--json"], timeout=20)
    sims = []
    if code == 0:
        for runtime, devs in json.loads(out).get("devices", {}).items():
            sims += [d["name"] for d in devs if d.get("state") == "Booted"]
    info["sims"] = sims
    code, out, _ = run(["memory_pressure", "-Q"], timeout=10)
    m = re.search(r"free percentage:\s*(\d+)%", out)
    info["free"] = int(m.group(1)) if m else None
    lessons = git("show", "origin/develop:.claude/lessons.md") or ""
    info["lessons"] = len([l for l in lessons.splitlines() if re.match(r"- 20\d\d-", l)])
    return info


# ---------------------------------------------------------------- page

LANES = [("review", "리뷰 대기"), ("fixing", "수정 중"), ("rereview", "재리뷰 대기"),
         ("user", "사용자 확인"), ("merge", "머지 대기"), ("merged", "최근 머지")]

CSS = """
:root{--bg:#f6f4ef;--card:#fff;--ink:#1f1d1a;--soft:#6b665e;--line:#e4dfd5;--good:#2f7d4f;--bad:#c2412d;
--wait:#a86a12;--info:#2f5fa8;--chip:#efeae0;--user:#7b3fa0}
@media (prefers-color-scheme:dark){:root{--bg:#191816;--card:#24221f;--ink:#efebe4;--soft:#a39d93;--line:#38342f;
--good:#5cbf84;--bad:#ef7a64;--wait:#e0a444;--info:#7aa7ef;--chip:#2f2c28;--user:#c08ae6}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:14px/1.45 -apple-system,system-ui,sans-serif}
header{padding:16px 20px 4px;display:flex;flex-wrap:wrap;gap:8px 20px;align-items:baseline}
h1{font-size:20px;margin:0}h2{font-size:15px;margin:0 0 8px}.soft{color:var(--soft)}a{color:inherit}
.wrap{padding:8px 20px 28px;display:grid;gap:16px}
.banner{background:var(--card);border:1px solid var(--bad);color:var(--bad);border-radius:10px;padding:10px 14px}
.who{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:10px}
.pair{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}@media (max-width:760px){.pair{grid-template-columns:1fr}}
.clamp{display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden}
.issues{margin:8px 0 0;padding-left:18px}.box details summary{cursor:pointer;margin-top:4px}
.box{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:12px 14px}
.box ul{margin:0;padding-left:18px}.box li{margin:3px 0}
.lanes{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:10px}
.lane{background:transparent;border-radius:12px;min-width:0}
details summary{cursor:pointer;margin-top:8px}.card.small{padding:6px 10px}.card.small .t{font-weight:500;font-size:13px}
.lane h2{display:flex;justify-content:space-between;padding:0 4px}
.card{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:10px 12px;margin-bottom:8px}
.card .t{font-weight:600}.card .t a{text-decoration:none}.card .meta{font-size:12px;color:var(--soft);margin-top:4px}
.blk{margin-top:6px;font-size:13px;padding:6px 8px;border-radius:8px;background:var(--chip)}
.blk b{color:var(--info)}.blk.user b{color:var(--user)}.blk.fix b{color:var(--wait)}
.chips{display:flex;flex-wrap:wrap;gap:4px;margin-top:6px}.chip{font-size:11px;padding:1px 7px;border-radius:999px;background:var(--chip)}
.f-good{color:var(--good)}.f-bad{color:var(--bad);font-weight:600}.f-wait{color:var(--wait)}.f-info{color:var(--info)}
.grid2{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:16px}
table{width:100%;border-collapse:collapse;font-size:13px}td,th{text-align:left;padding:5px 6px;border-top:1px solid var(--line);vertical-align:top}
th{color:var(--soft);font-weight:500;border-top:none}.dot{display:inline-block;width:8px;height:8px;border-radius:50%;margin-right:6px}
.busy{background:var(--good)}.recent{background:var(--wait)}.idle{background:var(--line)}
code{font-size:12px}
details.fold>summary{list-style:none;cursor:pointer}details.fold>summary::-webkit-details-marker{display:none}
details.fold>summary h2::before{content:"▾";color:var(--soft);margin-right:6px;display:inline-block;width:10px}
details.fold:not([open])>summary h2::before{content:"▸"}details.fold:not([open])>summary h2{margin-bottom:0}
.lane.fold>summary h2{justify-content:flex-start;gap:6px}.lane.fold>summary h2 .soft{margin-left:auto}
.box.wide{grid-column:1/-1}
.glance{display:flex;flex-wrap:wrap;align-items:center;gap:6px;font-size:12px}
.pill{display:inline-flex;gap:6px;align-items:baseline;background:var(--card);border:1px solid var(--line);
border-radius:999px;padding:2px 10px}.pill .pl{color:var(--soft)}.pill.good b{color:var(--good)}
.pill.wait{border-color:var(--wait)}.pill.wait b{color:var(--wait)}.pill.bad{border-color:var(--bad)}.pill.bad b{color:var(--bad)}a.sess{color:var(--info);text-decoration:none;border-bottom:1px dotted var(--info)}
a.sess::after{content:" ↗";font-size:11px}td.report{font-size:12px;color:var(--soft);max-width:520px}
.mine{background:var(--card);border:2px solid var(--user);border-radius:14px;padding:14px 16px;display:grid;gap:10px}
.mine.calm{border-color:var(--line)}.mine h2{font-size:18px;margin:0;display:flex;align-items:center;gap:8px}
.mine .count{background:var(--user);color:var(--card);border-radius:999px;padding:0 10px;font-size:14px}
.mine.calm .count{background:var(--line);color:var(--soft)}
.todo{border-left:5px solid var(--user);background:var(--chip);border-radius:10px;padding:10px 12px}
.todo.ipad{border-left-color:var(--info)}.todo.idle{border-left-color:var(--wait)}.todo.decide{border-left-color:var(--wait)}
.todo .k{font-weight:700;font-size:15px}.todo .b{margin-top:4px;font-size:15px}.todo .how{margin-top:6px;font-size:12px;color:var(--soft)}pre{white-space:pre-wrap;word-break:break-all;font-size:12px;background:var(--chip);padding:8px 10px;border-radius:8px}
.tools{margin-left:auto;display:flex;gap:6px}.tools button{font:inherit;font-size:12px;color:var(--ink);background:var(--card);
border:1px solid var(--line);border-radius:999px;padding:3px 10px;cursor:pointer}
"""

# Folds survive the 15 s reload: each <details data-id> keeps its open state in this viewer's
# localStorage (a convenience only; the page works without it).
FOLD_JS = """(function(){var K='board-folds',s={};try{s=JSON.parse(localStorage.getItem(K)||'{}')}catch(e){}
function save(){try{localStorage.setItem(K,JSON.stringify(s))}catch(e){}}
var all=document.querySelectorAll('details[data-id]');
all.forEach(function(d){var id=d.getAttribute('data-id');if(id in s)d.open=s[id];
d.addEventListener('toggle',function(){s[id]=d.open;save()})});
document.querySelectorAll('[data-fold]').forEach(function(b){b.addEventListener('click',function(){
var o=b.getAttribute('data-fold')==='open';all.forEach(function(d){d.open=o})})})})();"""


def esc(s):
    return html.escape(str(s or ""))


def build():
    toplevel = git("rev-parse", "--show-toplevel")
    common = git("rev-parse", "--path-format=absolute", "--git-common-dir") or ""
    repo_root = os.path.dirname(common) if common.endswith("/.git") else toplevel
    remote = git("remote", "get-url", "origin") or ""
    m = re.search(r"github\.com[:/]([^/]+/[^/.]+)", remote)
    slug = m.group(1) if m else ""
    sessions = scan_sessions(repo_root, slug)
    desk = desktop_sessions()
    for sid, s_ in list(sessions.items()):
        d = desk.get(sid)
        s_["desk"] = d
        if d:
            s_["title"] = d["title"] or s_["title"]
            if d["activity"]:
                s_["mtime"] = d["activity"]
            if d["archived"]:
                del sessions[sid]
    # Links by session id; a bare title links only when no other session has the same title.
    links_by_id = {sid: session_link((s_["desk"] or {}).get("local")) for sid, s_ in sessions.items()}
    titles = {}
    for sid, s_ in sessions.items():
        titles.setdefault(s_["title"], []).append(sid)
    actor_sid = {}  # an actor's name on a card -> the session it stands for

    def sess(title, label=None, sid=None):
        """A session's name, linked to open it in the desktop app when its id is known."""
        if sid is None and len(titles.get(title, [])) == 1:
            sid = titles[title][0]
        url = links_by_id.get(sid) if sid else None
        text = esc(label or title)
        return f'<a class="sess" href="{esc(url)}" title="앱에서 이 세션 열기">{text}</a>' if url else text
    rev = next((s for s in sessions.values() if "코드 리뷰" in s["title"] and "(fork)" not in s["title"]), None)
    reviewer = rev["title"] if rev else "리뷰 세션"
    if rev:
        actor_sid[reviewer] = rev["id"]
    by_pr = {n: s for s in sessions.values() for n in s["prs"]}
    by_branch = {b: s for s in sessions.values() for b in s["branches"]}

    error, open_prs, merged, ended = None, [], [], {}
    try:
        open_prs, merged, ended = fetch_prs(slug)
        if _github["error"]:  # shown with the last answer still on the board
            age = int(time.time() - _github["read_at"])
            error = f'GitHub을 읽지 못해 {age}초 전 내용을 보여줍니다: {_github["error"]}'
    except Exception as e:  # keep the local half of the board when GitHub can't be read
        error = str(e)

    cards = {k: [] for k, _ in LANES}
    who = {}
    pr_by_branch = {}
    for pr in open_prs:
        s = by_pr.get(pr["number"]) or by_branch.get(pr["headRefName"])
        author = s["title"] if s else "작성 세션 (모름)"
        if s:
            actor_sid[author] = s["id"]
        lane, actor, what, since, flags, screen = classify(pr, author)
        actor = reviewer if actor == "리뷰 세션" else actor
        lane = "fixing" if lane == "draft" else lane
        files = [n["path"] for n in pr["files"]["nodes"]]
        card = {"pr": pr, "author": author, "author_sid": s["id"] if s else None, "actor": actor, "what": what,
                "since": since, "flags": flags,
                "chips": category(pr["title"], files)}
        cards[lane].append(card)
        who.setdefault(actor, []).append(card)
        pr_by_branch[pr["headRefName"]] = pr
    cutoff = now() - dt.timedelta(hours=MERGED_HOURS)
    for pr in merged:
        t = parse_time(pr["mergedAt"])
        if t and t >= cutoff:
            s = by_pr.get(pr["number"]) or by_branch.get(pr["headRefName"])
            files = [n["path"] for n in pr["files"]["nodes"]]
            cards["merged"].append({"pr": pr, "author": s["title"] if s else "", "author_sid": s["id"] if s else None, "since": t,
                                    "chips": category(pr["title"], files), "flags": [], "actor": None})

    fetch_origin()
    wts = worktrees()
    mac = machine()

    def owner_of(path):
        for s in sessions.values():
            if s["id"] in path or s["cwd"] == path:
                return s["title"]
        return ""

    def blocker_class(actor):
        return "user" if actor == "사용자" else ("fix" if actor not in (reviewer,) else "")

    h = ['<!doctype html><html lang="ko"><head><meta charset="utf-8">',
         '<meta name="viewport" content="width=device-width,initial-scale=1">',
         '<meta http-equiv="refresh" content="15"><title>작업 현황판</title>', f"<style>{CSS}</style></head><body>",
         f'<header><h1>작업 현황판</h1><span class="soft">{esc(slug)} · {dt.datetime.now().strftime("%H:%M:%S")} 갱신 · 15초마다 새로고침</span>'
         '<span class="tools"><button type="button" data-fold="close">모두 접기</button>'
         '<button type="button" data-fold="open">모두 펼치기</button></span></header>',
         '<div class="wrap">']
    if error:
        h.append(f'<div class="banner">GitHub를 읽지 못했습니다: {esc(error)}. 로컬 정보만 보여 줍니다.</div>')

    # This Mac at a glance: one short strip of pills; red when an 8 GB limit is crossed.
    free, bz, sims = mac["free"], mac["bazel"], mac["sims"]
    busy = sum(1 for s_ in sessions.values() if session_state(s_)[0] == "busy")

    def pill(label, value, level="", tip=""):
        return (f'<span class="pill {level}" title="{esc(tip)}"><span class="pl">{label}</span>'
                f'<b>{value}</b></span>')

    pills = [
        pill("메모리 여유", f'{free if free is not None else "?"}%',
             "bad" if free is not None and free < 15 else ("wait" if free is not None and free < 30 else "good")),
        pill("Bazel", f"{len(bz)}개", "bad" if len(bz) > 1 else "",
             ", ".join(f"{n} {r} MB" for n, r in bz) + (" · 한 번에 하나만" if len(bz) > 1 else "")),
        pill("시뮬레이터", f"{len(sims)}대", "bad" if len(sims) > 1 else "", ", ".join(sims)),
        pill("작업 중인 세션", f"{busy}개"),
        pill("lessons", f'{mac["lessons"]}개', "wait" if mac["lessons"] >= 5 else "",
             "5개 이상이면 skill-retro" if mac["lessons"] >= 5 else ""),
    ]
    h.append('<div class="glance"><span class="soft">이 맥 (8 GB)</span>' + "".join(pills) + "</div>")

    # What only the user can do: answer a waiting session, check a screen PR on the iPad, decide
    # about local branches. Everything else moves between the sessions on its own.
    work = local_work(wts, pr_by_branch, ended, by_branch, owner_of, repo_root)
    mine = []
    for s_ in sorted(sessions.values(), key=lambda s_: (s_["waiting"] or {}).get("at") or ""):
        q, d = s_["waiting"], s_["desk"] or {}
        asks = [x for x in (q and q["text"], d.get("needs")) if x]
        if d.get("awaiting") and not asks:
            asks.append(d.get("report") or "세션이 멈춰 사람을 기다립니다")
        if asks:
            stopped = (q and q["blocked"]) or d.get("awaiting")
            mine.append(("ask", "세션이 내 답을 기다림" + (" · 멈춰 있음" if stopped else ""),
                         "<br>".join(esc(a) for a in dict.fromkeys(asks)),
                         f'{sess(s_["title"], s_["title"] + " 열기", sid=s_["id"])}'
                         + (f' · {esc(ago(parse_time(q["at"])))}' if q else "")))
    for c in cards["user"]:
        pr = c["pr"]
        mine.append(("ipad", "iPad에서 화면 확인",
                     f'<a href="{esc(pr["url"])}">#{pr["number"]} {esc(pr["title"])}</a>',
                     f'괜찮으면 {sess(c["author"], sid=c.get("author_sid"))} 세션에 "iPad OK"라고 알려 주기 · LGTM {esc(ago(c["since"]))}'))
    # A session that rests with issues left and nothing in hand needs a nudge from the user.
    issues = read_issues(repo_root)
    open_numbers = {p["number"]: p for p in open_prs}
    # Each open PR's session, as the lanes find it (its number or its branch in the transcript).
    held = {}
    for pr in open_prs:
        s_ = by_pr.get(pr["number"]) or by_branch.get(pr["headRefName"])
        if s_:
            held.setdefault(s_["id"], []).append(pr["number"])
    owners = {}
    for s_ in sessions.values():
        owner = owner_of_title(s_["title"])
        if not owner:
            continue
        o = owners.setdefault(owner, {"busy": False, "asking": False, "prs": 0, "sessions": [],
                                      "issues": [i for i in issues if i["owner"].split()[:1] == [owner]]})
        o["busy"] |= session_state(s_)[0] == "busy"
        d = s_["desk"] or {}
        o["asking"] |= bool(s_["waiting"] or d.get("needs") or d.get("awaiting"))
        o["prs"] += len(held.get(s_["id"], []))
        o["sessions"].append(s_)
    for owner, waiting in idle_with_issues(owners):
        s_ = max(owners[owner]["sessions"], key=lambda x: x["mtime"])
        mine.append(("idle", f"할 일이 남았는데 쉬는 중: {esc(owner)}",
                     "<br>".join(f'이슈 {esc(i["number"])} {esc(i["title"])}' for i in waiting[:4])
                     + (f"<br>… 외 {len(waiting) - 4}건" if len(waiting) > 4 else ""),
                     f'{sess(s_["title"], s_["title"] + " 열기", sid=s_["id"])}에 이슈를 집으라고 (<code>issue.sh start</code>) 알리거나, '
                     f'미뤄도 되면 그대로 두기 · {esc(ago(s_["mtime"]))} 쉬는 중'))
    decide = [i for i in work if i["verdict"] == "decide"]
    if decide:
        mine.append(("decide", f"로컬 브랜치 {len(decide)}개: 살릴지 지울지 정하기",
                     esc(", ".join(i["branch"] for i in decide[:4]) + (" …" if len(decide) > 4 else "")),
                     '<a href="#local">아래 로컬 작업</a>에서 내용 보기 · 정하면 세션에 맡기기'))
    h.append(f'<section class="mine{" calm" if not mine else ""}"><h2>내가 할 일 <span class="count">{len(mine)}</span></h2>')
    if not mine:
        h.append('<p>지금은 없습니다. 세션들이 알아서 진행 중입니다.</p>')
    for kind, title, body, how in mine:
        h.append(f'<div class="todo {kind}"><div class="k">{title}</div><div class="b">{body}</div>'
                 f'<div class="how">{how}</div></div>')
    h.append("</section>")

    # The sessions' own turns on the review loop (they act on these without the user)
    who.pop("사용자", None)
    h.append('<details class="fold" data-id="who" open><summary><h2>세션들의 차례 '
             '<span class="soft">(사용자 입력 없이 진행)</span></h2></summary><div class="who">')
    order = sorted(who.items(), key=lambda kv: (kv[0] != reviewer, kv[0]))
    if not order:
        h.append('<div class="box soft">세션 차례인 PR이 없습니다.</div>')
    for actor, items in order:
        h.append(f'<div class="box"><b>{sess(actor, sid=actor_sid.get(actor))}</b> <span class="soft">· {len(items)}건</span><ul>')
        for c in sorted(items, key=lambda c: c["since"] or now()):
            h.append(f'<li><a href="{esc(c["pr"]["url"])}">#{c["pr"]["number"]}</a> {esc(c["what"])} '
                     f'<span class="soft">({esc(ago(c["since"]))}부터)</span></li>')
        h.append("</ul></div>")
    h.append("</div></details>")

    # Lanes
    h.append('<section class="lanes">')
    for key, label in LANES:
        # Every lane folds; recently merged starts folded (it only grows).
        opened = "" if key == "merged" else " open"
        h.append(f'<details class="lane fold" data-id="lane-{key}"{opened}><summary><h2><span>{label}</span>'
                 f'<span class="soft">{len(cards[key])}</span></h2></summary>')
        for c in cards[key]:
            pr = c["pr"]
            if key == "merged":  # one compact line each: what landed, from which session, when
                h.append(f'<div class="card small"><div class="t"><a href="{esc(pr["url"])}">#{pr["number"]} {esc(pr["title"])}</a></div>'
                         f'<div class="meta">{sess(c["author"], sid=c.get("author_sid")) if c["author"] else "세션 모름"} · {esc(ago(c["since"]))}</div></div>')
                continue
            h.append(f'<div class="card"><div class="t"><a href="{esc(pr["url"])}">#{pr["number"]} {esc(pr["title"])}</a></div>')
            h.append('<div class="chips">' + "".join(f'<span class="chip">{esc(x)}</span>' for x in c["chips"]) + "</div>")
            if c["actor"]:
                h.append(f'<div class="blk {blocker_class(c["actor"])}"><b>{sess(c["actor"], sid=actor_sid.get(c["actor"]))}</b> · {esc(c["what"])} '
                         f'<span class="soft">· {esc(ago(c["since"]))}</span></div>')
            meta = [f'만든 세션: {sess(c["author"], sid=c.get("author_sid"))}', f'<code>{esc(pr["headRefName"])}</code>']
            if key == "merged":
                meta.append(f'머지 {esc(ago(c["since"]))}')
            h.append('<div class="meta">' + " · ".join(meta) + "</div>")
            if c["flags"]:
                h.append('<div class="meta">' + " · ".join(f'<span class="f-{k}">{esc(t)}</span>' for k, t in c["flags"]) + "</div>")
            h.append("</div>")
        h.append("</details>")
    h.append("</section>")

    # One card per issue owner (main, review, design, harness), two to a row: its newest session and
    # state, what it has in hand (doing issues, open PRs), its last status, then its issues waiting (two shown)
    # (scripts/issue.sh). An owner with issues but no session (an empty or unknown owner) gets a card
    # too. Older or side sessions that own no issues stay off the board (the app's sidebar has them).
    rank = {"main": 0, "design": 1, "review": 2, "harness": 3}  # two to a row: main · design, review · harness (user)
    by_owner = {}
    for i in issues:
        if is_open(i):
            by_owner.setdefault((i["owner"].split() or ["담당 없음"])[0], []).append(i)
    names = sorted(set(owners) | set(by_owner), key=lambda o: (rank.get(o, 9), o))
    waiting_all = sum(1 for items in by_owner.values() for i in items if not is_doing(i))
    h.append(f'<details class="fold" data-id="sessions" open><summary><h2>세션과 이슈 '
             f'<span class="soft">(남은 이슈 {waiting_all}건 · scripts/issue.sh)</span></h2></summary><div class="pair">')
    if not names:
        h.append('<div class="box soft">이슈 담당 세션도 열린 이슈도 없습니다.</div>')
    for owner in names:
        o = owners.get(owner)
        items = by_owner.get(owner, [])
        doing = [i for i in items if is_doing(i)]
        waiting = [i for i in items if not is_doing(i)]
        if o:
            newest = max(o["sessions"], key=lambda x: x["mtime"])
            busy = [x for x in o["sessions"] if session_state(x)[0] == "busy"]
            cls, label = session_state(busy[0] if busy else newest)
            prs = [n for x in o["sessions"] for n in held.get(x["id"], [])]
            d = newest.get("desk") or {}
            report = d.get("status") or d.get("report", "")
            head = (f'<b>{esc(owner)}</b> · {sess(newest["title"], newest["title"] + " 열기", sid=newest["id"])}'
                    f'<div class="meta"><span class="dot {cls}"></span>{label} '
                    f'<span class="soft">({esc(ago(newest["mtime"]))})</span> · 남은 이슈 {len(waiting)}건</div>')
        else:
            prs, report = [], ""
            head = (f'<b>{esc(owner)}</b> <span class="soft">· 담당 세션 없음</span>'
                    f'<div class="meta">남은 이슈 {len(waiting)}건</div>')
        hand = [f'<li><span class="f-info">이슈 {esc(i["number"])} 진행 중</span> {esc(i["title"])}</li>' for i in doing]
        hand += [f'<li><a href="{esc(open_numbers[n]["url"])}">#{n}</a> {esc(open_numbers[n]["title"])}</li>' for n in prs]
        h.append('<div class="box">' + head
                 + (f'<ul>{"".join(hand)}</ul>' if hand else '<div class="meta f-wait">집은 이슈도 열린 PR도 없음</div>')
                 + (f'<div class="meta report clamp">{esc(report)}</div>' if report else "")
                 + issue_list(owner, waiting) + "</div>")
    h.append("</div></details>")

    # Local-only work, machine
    h.append('<section class="grid2">')

    # Local work: each branch's story and a verdict; safe deletes fold away with their commands
    tag = {"active": ("f-info", "진행 중"), "decide": ("f-wait", "결정 필요"), "delete": ("f-good", "삭제 가능")}

    def row(i):
        w = i["tree"]
        where = f'<code>{esc(i["branch"])}</code>'
        if w:
            where += f'<br><span class="soft">{"공유 체크아웃" if w["path"] == repo_root else esc(os.path.basename(w["path"]))}</span>'
        what = esc(i["subject"]) or '<span class="soft">커밋 없음</span>'
        size = f'develop보다 커밋 {i["ahead"]} · 파일 {len(i["files"])}' if i["ahead"] else ""
        when = ago(dt.datetime.fromtimestamp(i["when"], dt.timezone.utc)) if i["when"] else ""
        detail = " · ".join(x for x in [size, when] + i["notes"] if x)
        chips = "".join(f'<span class="chip">{esc(c)}</span>' for c in i["areas"])
        cls, label = tag[i["verdict"]]
        link = f' <a href="{esc(i["pr"]["url"])}">#{i["pr"]["number"]}</a>' if i.get("pr") else ""
        return (f'<tr><td>{where}</td><td>{what}<div class="meta">{esc(detail)}</div>'
                f'{"<div class=chips>" + chips + "</div>" if chips else ""}</td>'
                f'<td><b class="{cls}">{label}</b>{link}<div class="meta">{esc(i["why"])}</div></td>'
                f'<td class="soft">{sess(i["who"]) if i["who"] else ""}</td></tr>')

    keep = [i for i in work if i["verdict"] != "delete"]
    drop = [i for i in work if i["verdict"] == "delete"]
    head_row = '<tr><th>브랜치</th><th>무슨 작업</th><th>판단</th><th>세션</th></tr>'
    h.append('<div class="box wide" id="local"><details class="fold" data-id="local" open><summary><h2>로컬 작업 '
             f'<span class="soft">진행 중 {sum(i["verdict"] == "active" for i in work)} · 결정 필요 '
             f'{sum(i["verdict"] == "decide" for i in work)} · 삭제 가능 {len(drop)}</span></h2></summary>')
    h.append(f'<table>{head_row}{"".join(row(i) for i in keep)}</table>' if keep else
             '<p class="soft">진행 중이거나 결정이 필요한 로컬 작업이 없습니다.</p>')
    if drop:
        trees = [i["tree"]["path"] for i in drop if i["tree"] and not i["tree"].get("missing") and i["tree"]["path"] != repo_root]
        names = [i["branch"] for i in drop if not (i["tree"] and i["tree"]["path"] == repo_root)]
        cmds = [f"git worktree remove {p}" for p in trees] + (["git worktree prune"] if any(i["tree"] and i["tree"].get("missing") for i in drop) else [])
        cmds += [f"git branch -D {' '.join(names)}"] if names else []
        h.append(f'<details data-id="drop"><summary class="soft">삭제 가능 {len(drop)}개: 내용이 develop에 있거나 PR이 머지됨</summary>'
                 f'<table>{head_row}{"".join(row(i) for i in drop)}</table>'
                 f'<p class="soft">정리할 때 쓰는 명령 (현황판은 지우지 않습니다. 세션에 맡기거나 직접 실행):</p>'
                 f'<pre>{esc(chr(10).join(cmds))}</pre></details>')
    h.append("</details></div>")

    h.append("</section>")

    h.append('<p class="soft">사용자 확인: 화면을 바꾼 PR은 LGTM 뒤 iPad 확인이 필요합니다. 확인되면 작성 세션이 PR에 '
             '<code>iPad OK at &lt;헤드 SHA&gt;</code>를 남기고, 그 헤드에서만 유효합니다 (새 push 뒤에는 다시 확인).</p>')
    h.append(f"</div><script>{FOLD_JS}</script></body></html>")
    os.makedirs(OUT, exist_ok=True)
    tmp = PAGE + ".tmp"
    with open(tmp, "w") as fh:
        # GitHub pages open in a new window; session links stay as they are (the app opens them).
        fh.write("\n".join(h).replace('<a href="https://github.com/', '<a target="_blank" rel="noopener" href="https://github.com/'))
    os.replace(tmp, PAGE)


REBUILD_GAP = 10  # seconds; below the page's 15 s refresh


def serve(port):
    """Serve the page alone on 127.0.0.1. Other paths get 404 (the session cache stays private), and
    a Host other than this address is refused, so a web page can't reach it by DNS rebinding."""
    lock, state = threading.Lock(), {"built": 0.0, "building": False}
    hosts = {f"127.0.0.1:{port}", f"localhost:{port}"}

    def rebuild():
        try:
            build()
        except Exception as e:  # keep serving the last page rather than nothing
            print("build failed:", e)
        with lock:
            state["built"], state["building"] = time.time(), False

    # A build takes several seconds (gh, git, the session files). A reload gets the last page at
    # once and starts the next build when that page is older than REBUILD_GAP, so with the page's
    # 15 s refresh every reload starts one and the page shown is at most one reload behind.
    # Builds run only while someone has the board open.
    def maybe_rebuild(wait):
        with lock:
            due = not state["building"] and time.time() - state["built"] > REBUILD_GAP
            if due:
                state["building"] = True
        if due and wait:
            rebuild()
        elif due:
            threading.Thread(target=rebuild, daemon=True).start()

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            if self.headers.get("Host", "") not in hosts:
                self.send_error(403)
                return
            if self.path.split("?")[0] not in ("/", "/index.html"):
                self.send_error(404)
                return
            maybe_rebuild(wait=not os.path.exists(PAGE))
            try:
                with open(PAGE, "rb") as fh:
                    body = fh.read()
            except OSError:  # no page built yet (the first build failed): ask the browser to retry
                self.send_response(503)
                self.send_header("Retry-After", "10")
                self.send_header("Content-Type", "text/plain; charset=utf-8")
                self.end_headers()
                self.wfile.write("작업 현황판을 만드는 중입니다. 잠시 뒤 새로고침하세요.".encode())
                return
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    try:
        build()
    except Exception as e:  # still serve; the next reload tries again and shows the last good page
        print("first build failed:", e, flush=True)
    state["built"] = time.time()
    print(f"작업 현황판: http://127.0.0.1:{port}/", flush=True)
    http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--serve", action="store_true", help="serve the board on 127.0.0.1 and rebuild on reload")
    ap.add_argument("--port", type=int, default=8765)
    args = ap.parse_args()
    if args.serve:
        serve(args.port)
    else:
        build()
        print(PAGE)
