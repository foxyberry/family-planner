#!/usr/bin/env python3
"""Local status board for the sessions that work on this repo at the same time.

It reads three things on this Mac and writes one HTML page (tools/board/out/index.html, git-ignored):
  - GitHub, through `gh`: open PRs on the pr-review-handoff loop (review, fixes, re-review, LGTM,
    iPad check, merge) and the PRs merged lately;
  - Claude Code transcripts (~/.claude/projects): each session's title, the PRs and branches it
    created and the folder it works in;
  - git and the machine: worktrees, local-only branches and commits, Bazel servers, simulators.

  python3 tools/board/board.py            # write the page once
  python3 tools/board/board.py --serve    # http://127.0.0.1:8765, rebuilt at most every 25 s

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
EMPTY = {"v": 2, "offset": 0, "title": None, "cwd": None, "prs": [], "branches": [], "related": False,
         "ask": None, "user_at": None}
# Messages that reach a session as a user turn but are not the user's own words.
NOT_USER = ("<ci-monitor-event", "<cross-session-message", "<side-sessions-event", "<system-reminder",
            "<task-notification", "<command-", "<local-command", "Another Claude session sent a message")
NEW_BRANCH = re.compile(rb'(?:checkout|switch)\s+-[bcBC]\s+([A-Za-z0-9._/-]+)|worktree add[^"]*?\s-b\s+([A-Za-z0-9._/-]+)')


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
                d = json.loads(line)
                for part in d.get("message", {}).get("content", []):
                    if isinstance(part, dict) and part.get("name") == "mcp__ccd_turn__wrap_up":
                        inp = part.get("input", {})
                        c["ask"] = ({"text": inp["ask"], "blocked": bool(inp.get("blocked")),
                                     "at": d.get("timestamp"), "recap": inp.get("recap", "")}
                                    if inp.get("ask") else None)
            elif b'"type":"user"' in line and b"tool_result" not in line:
                d = json.loads(line)
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
            waiting = ask if ask and (not c.get("user_at") or ask["at"] > c["user_at"]) else None
            sessions[sid] = {"id": sid, "title": c["title"] or sid[:8], "cwd": c["cwd"], "prs": c["prs"],
                             "branches": c["branches"], "waiting": waiting,
                             "mtime": dt.datetime.fromtimestamp(mtime, dt.timezone.utc)}
    # Keep only this repo's sessions in full; for other projects keep just the read offset.
    slim = {k: (v if v["related"] else {**EMPTY, "offset": v["offset"]})
            for k, v in cache.items() if os.path.exists(k)}
    os.makedirs(OUT, exist_ok=True)
    fd = os.open(CACHE, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as fh:
        json.dump(slim, fh)
    return sessions


def session_state(s):
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


def fetch_prs(slug):
    owner, name = slug.split("/")
    query = (f'query {{ repository(owner: "{owner}", name: "{name}") {{ '
             f'open: pullRequests(states: OPEN, first: 40, orderBy: {{field: UPDATED_AT, direction: DESC}}) {{ nodes {{ {PR_FIELDS} }} }} '
             f'merged: pullRequests(states: MERGED, first: 15, orderBy: {{field: UPDATED_AT, direction: DESC}}) '
             f'{{ nodes {{ number title url headRefName mergedAt files(first: 100) {{ nodes {{ path }} }} }} }} '
             f'allMerged: pullRequests(states: MERGED, last: 100) {{ nodes {{ number url headRefName }} }} '
             f'oldMerged: pullRequests(states: MERGED, first: 100) {{ nodes {{ number url headRefName }} }} '
             f'closed: pullRequests(states: CLOSED, last: 50) {{ nodes {{ number url headRefName }} }} }} }}')
    code, out, err = run(["gh", "api", "graphql", "-f", "query=" + query])
    if code != 0:
        raise RuntimeError(err.strip() or "gh api graphql failed")
    repo = json.loads(out)["data"]["repository"]
    ended = {p["headRefName"]: ("merged", p) for p in repo["oldMerged"]["nodes"] + repo["allMerged"]["nodes"]}
    ended.update({p["headRefName"]: ("closed", p) for p in repo["closed"]["nodes"] if p["headRefName"] not in ended})
    return repo["open"]["nodes"], repo["merged"]["nodes"], ended


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
        if pr:
            verdict, why = "active", f'PR #{pr["number"]} 진행 중'
        elif dirty:
            verdict, why = "decide", "커밋 안 된 변경이 있음: 살릴지 정해야 함"
        elif end_state == "merged" and not unpushed:
            verdict, why = "delete", f'PR #{end_pr["number"]} 머지됨'
        elif a["ahead"] == 0:
            verdict, why = "delete", "develop에 이미 포함 (새 커밋 없음)"
        elif a["in_develop"]:
            verdict, why = "delete", "바뀐 파일이 develop과 같음 (내용이 이미 들어감)"
        elif end_state == "merged":
            verdict, why = "decide", f'PR #{end_pr["number"]} 머지 뒤 남은 커밋 {unpushed}'
        elif end_state == "closed":
            verdict, why = "decide", f'PR #{end_pr["number"]} 머지 없이 닫힘'
        else:
            verdict, why = "decide", f'develop에 없는 변경: 커밋 {a["ahead"]} · 파일 {len(a["files"])}'
        if name.startswith("backup/") and verdict == "decide":
            why += " (백업: 원본이 머지됐으면 삭제 가능)"
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
.mine{background:var(--card);border:2px solid var(--user);border-radius:14px;padding:14px 16px;display:grid;gap:10px}
.mine.calm{border-color:var(--line)}.mine h2{font-size:18px;margin:0;display:flex;align-items:center;gap:8px}
.mine .count{background:var(--user);color:var(--card);border-radius:999px;padding:0 10px;font-size:14px}
.mine.calm .count{background:var(--line);color:var(--soft)}
.todo{border-left:5px solid var(--user);background:var(--chip);border-radius:10px;padding:10px 12px}
.todo.ipad{border-left-color:var(--info)}.todo.decide{border-left-color:var(--wait)}
.todo .k{font-weight:700;font-size:15px}.todo .b{margin-top:4px;font-size:15px}.todo .how{margin-top:6px;font-size:12px;color:var(--soft)}pre{white-space:pre-wrap;word-break:break-all;font-size:12px;background:var(--chip);padding:8px 10px;border-radius:8px}
.tools{margin-left:auto;display:flex;gap:6px}.tools button{font:inherit;font-size:12px;color:var(--ink);background:var(--card);
border:1px solid var(--line);border-radius:999px;padding:3px 10px;cursor:pointer}
"""

# Folds survive the 30 s reload: each <details data-id> keeps its open state in this viewer's
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
    reviewer = next((s["title"] for s in sessions.values() if "코드 리뷰" in s["title"] and "(fork)" not in s["title"]), "리뷰 세션")
    by_pr = {n: s for s in sessions.values() for n in s["prs"]}
    by_branch = {b: s for s in sessions.values() for b in s["branches"]}

    error, open_prs, merged, ended = None, [], [], {}
    try:
        open_prs, merged, ended = fetch_prs(slug)
    except Exception as e:  # keep the local half of the board when GitHub can't be read
        error = str(e)

    cards = {k: [] for k, _ in LANES}
    who = {}
    pr_by_branch = {}
    for pr in open_prs:
        s = by_pr.get(pr["number"]) or by_branch.get(pr["headRefName"])
        author = s["title"] if s else "작성 세션 (모름)"
        lane, actor, what, since, flags, screen = classify(pr, author)
        actor = reviewer if actor == "리뷰 세션" else actor
        lane = "fixing" if lane == "draft" else lane
        files = [n["path"] for n in pr["files"]["nodes"]]
        card = {"pr": pr, "author": author, "actor": actor, "what": what, "since": since, "flags": flags,
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
            cards["merged"].append({"pr": pr, "author": s["title"] if s else "", "since": t,
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
         '<meta http-equiv="refresh" content="30"><title>작업 현황판</title>', f"<style>{CSS}</style></head><body>",
         f'<header><h1>작업 현황판</h1><span class="soft">{esc(slug)} · {dt.datetime.now().strftime("%H:%M:%S")} 갱신 · 30초마다 새로고침</span>'
         '<span class="tools"><button type="button" data-fold="close">모두 접기</button>'
         '<button type="button" data-fold="open">모두 펼치기</button></span></header>',
         '<div class="wrap">']
    if error:
        h.append(f'<div class="banner">GitHub를 읽지 못했습니다: {esc(error)}. 로컬 정보만 보여 줍니다.</div>')

    # What only the user can do: answer a waiting session, check a screen PR on the iPad, decide
    # about local branches. Everything else moves between the sessions on its own.
    work = local_work(wts, pr_by_branch, ended, by_branch, owner_of, repo_root)
    mine = []
    for s_ in sorted(sessions.values(), key=lambda s_: (s_["waiting"] or {}).get("at") or ""):
        q = s_["waiting"]
        if q:
            mine.append(("ask", "질문에 답하기" + (" · 세션이 멈춰 있음" if q["blocked"] else ""),
                         esc(q["text"]), f'{esc(s_["title"])} 세션에서 답하기 · {esc(ago(parse_time(q["at"])))}'))
    for c in cards["user"]:
        pr = c["pr"]
        mine.append(("ipad", "iPad에서 화면 확인",
                     f'<a href="{esc(pr["url"])}">#{pr["number"]} {esc(pr["title"])}</a>',
                     f'괜찮으면 {esc(c["author"])} 세션에 "iPad OK"라고 알려 주기 · LGTM {esc(ago(c["since"]))}'))
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
        h.append(f'<div class="box"><b>{esc(actor)}</b> <span class="soft">· {len(items)}건</span><ul>')
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
                         f'<div class="meta">{esc(c["author"]) or "세션 모름"} · {esc(ago(c["since"]))}</div></div>')
                continue
            h.append(f'<div class="card"><div class="t"><a href="{esc(pr["url"])}">#{pr["number"]} {esc(pr["title"])}</a></div>')
            h.append('<div class="chips">' + "".join(f'<span class="chip">{esc(x)}</span>' for x in c["chips"]) + "</div>")
            if c["actor"]:
                h.append(f'<div class="blk {blocker_class(c["actor"])}"><b>{esc(c["actor"])}</b> · {esc(c["what"])} '
                         f'<span class="soft">· {esc(ago(c["since"]))}</span></div>')
            meta = [f'만든 세션: {esc(c["author"]) or "모름"}', f'<code>{esc(pr["headRefName"])}</code>']
            if key == "merged":
                meta.append(f'머지 {esc(ago(c["since"]))}')
            h.append('<div class="meta">' + " · ".join(meta) + "</div>")
            if c["flags"]:
                h.append('<div class="meta">' + " · ".join(f'<span class="f-{k}">{esc(t)}</span>' for k, t in c["flags"]) + "</div>")
            h.append("</div>")
        h.append("</details>")
    h.append("</section>")

    # Sessions, local-only work, machine
    h.append('<section class="grid2">')
    h.append('<div class="box"><details class="fold" data-id="sessions" open><summary><h2>세션</h2></summary>'
             '<table><tr><th>세션</th><th>상태</th><th>만든 PR</th></tr>')
    open_numbers = {p["number"]: p for p in open_prs}
    for s in sorted(sessions.values(), key=lambda s: s["mtime"], reverse=True):
        cls, label = session_state(s)
        prs = " ".join(f'<a href="{esc(open_numbers[n]["url"])}">#{n}</a>' for n in s["prs"] if n in open_numbers)
        h.append(f'<tr><td>{esc(s["title"])}</td><td><span class="dot {cls}"></span>{label} '
                 f'<span class="soft">({esc(ago(s["mtime"]))})</span></td><td>{prs or "<span class=soft>열린 PR 없음</span>"}</td></tr>')
    h.append("</table></details></div>")

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
                f'<td class="soft">{esc(i["who"])}</td></tr>')

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

    free = mac["free"]
    h.append('<div class="box"><details class="fold" data-id="machine" open><summary><h2>이 맥 (8 GB)</h2></summary><ul>')
    h.append(f'<li>메모리 여유: <b class="{"f-bad" if free is not None and free < 15 else ""}">{free if free is not None else "?"}%</b></li>')
    bz = mac["bazel"]
    h.append(f'<li>Bazel 서버 {len(bz)}개' + (": " + ", ".join(f"{esc(n)} {r} MB" for n, r in bz) if bz else "") +
             (' <span class="f-bad">(한 번에 하나만)</span>' if len(bz) > 1 else "") + "</li>")
    sims = mac["sims"]
    h.append(f'<li>켜진 시뮬레이터 {len(sims)}대' + (": " + esc(", ".join(sims)) if sims else "") +
             (' <span class="f-bad">(하나만)</span>' if len(sims) > 1 else "") + "</li>")
    h.append(f'<li>lessons inbox: {mac["lessons"]}개' + (' <span class="f-wait">(5개 이상: skill-retro)</span>' if mac["lessons"] >= 5 else "") + "</li>")
    h.append("</ul></details></div></section>")

    h.append('<p class="soft">사용자 확인: 화면을 바꾼 PR은 LGTM 뒤 iPad 확인이 필요합니다. 확인되면 작성 세션이 PR에 '
             '<code>iPad OK at &lt;헤드 SHA&gt;</code>를 남기고, 그 헤드에서만 유효합니다 (새 push 뒤에는 다시 확인).</p>')
    h.append(f"</div><script>{FOLD_JS}</script></body></html>")
    os.makedirs(OUT, exist_ok=True)
    tmp = PAGE + ".tmp"
    with open(tmp, "w") as fh:
        fh.write("\n".join(h))
    os.replace(tmp, PAGE)


def serve(port):
    """Serve the page alone on 127.0.0.1. Other paths get 404 (the session cache stays private), and
    a Host other than this address is refused, so a web page can't reach it by DNS rebinding."""
    lock, state = threading.Lock(), {"built": 0.0}
    hosts = {f"127.0.0.1:{port}", f"localhost:{port}"}

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            if self.headers.get("Host", "") not in hosts:
                self.send_error(403)
                return
            if self.path.split("?")[0] not in ("/", "/index.html"):
                self.send_error(404)
                return
            with lock:
                if time.time() - state["built"] > 25:
                    try:
                        build()
                    except Exception as e:  # serve the last page rather than nothing
                        print("build failed:", e)
                    state["built"] = time.time()
            with open(PAGE, "rb") as fh:
                body = fh.read()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    build()
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
