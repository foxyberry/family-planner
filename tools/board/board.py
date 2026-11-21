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
LOCAL_BRANCH_DAYS = 7     # unpushed branches older than this are hidden
SCREEN_DIRS = ("ios/Features/", "ios/AppCore/", "ios/DesignSystem/", "ios/KitArt/")
LGTM = re.compile(r"^\s*LGTM at ([0-9a-f]{7,40})", re.I | re.M)
IPAD_OK = re.compile(r"^\s*(iPad (OK|checked|check (done|ok|waived))|iPad 확인 (완료|생략))", re.I | re.M)

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
        if not c or size < c["offset"]:
            c = {"offset": 0, "title": None, "cwd": None, "prs": [], "branches": [], "related": False}
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
            if b'"tool_use"' in line and (b"-b " in line or b"-c " in line):
                for m in NEW_BRANCH.finditer(line):
                    b = (m.group(1) or m.group(2)).decode()
                    if b not in c["branches"]:
                        c["branches"].append(b)
        c["offset"] += end
        cache[path] = c
        if c["related"]:
            sessions[sid] = {"id": sid, "title": c["title"] or sid[:8], "cwd": c["cwd"], "prs": c["prs"],
                             "branches": c["branches"], "mtime": dt.datetime.fromtimestamp(mtime, dt.timezone.utc)}
    os.makedirs(OUT, exist_ok=True)
    with open(CACHE, "w") as fh:
        json.dump({k: v for k, v in cache.items() if os.path.exists(k)}, fh)
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
labels(first: 20) { nodes { name } }
"""


def fetch_prs(slug):
    owner, name = slug.split("/")
    query = (f'query {{ repository(owner: "{owner}", name: "{name}") {{ '
             f'open: pullRequests(states: OPEN, first: 40, orderBy: {{field: UPDATED_AT, direction: DESC}}) {{ nodes {{ {PR_FIELDS} }} }} '
             f'merged: pullRequests(states: MERGED, first: 15, orderBy: {{field: UPDATED_AT, direction: DESC}}) '
             f'{{ nodes {{ number title url headRefName mergedAt files(first: 100) {{ nodes {{ path }} }} }} }} }} }}')
    code, out, err = run(["gh", "api", "graphql", "-f", "query=" + query])
    if code != 0:
        raise RuntimeError(err.strip() or "gh api graphql failed")
    repo = json.loads(out)["data"]["repository"]
    return repo["open"]["nodes"], repo["merged"]["nodes"]


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
    """Where the PR stands on the review loop and who has to act next."""
    head = pr["headRefOid"]
    files = [n["path"] for n in pr["files"]["nodes"]]
    commit = (pr["commits"]["nodes"] or [{}])[0].get("commit") or {}
    ci = ((commit.get("statusCheckRollup") or {}).get("state") or "NONE").upper()
    reviews = [r for r in pr["reviews"]["nodes"] if r.get("submittedAt")]
    last_review = max(reviews, key=lambda r: r["submittedAt"]) if reviews else None
    open_threads = sum(1 for t in pr["reviewThreads"]["nodes"] if not t["isResolved"])
    lgtm_sha, lgtm_at, ipad_ok = None, None, False
    for c in pr["comments"]["nodes"]:
        m = LGTM.search(c["body"])
        if m:
            lgtm_sha, lgtm_at = m.group(1), parse_time(c["createdAt"])
        if IPAD_OK.search(c["body"]):
            ipad_ok = True
    labels = {l["name"].lower() for l in pr["labels"]["nodes"]}
    ipad_ok = ipad_ok or "ipad-ok" in labels
    screen = changes_screen(files)
    lgtm_here = bool(lgtm_sha and head.startswith(lgtm_sha))
    since = parse_time(commit.get("committedDate"))
    flags = []
    if ci == "FAILURE" or ci == "ERROR":
        flags.append(("bad", "CI 실패"))
    elif ci == "PENDING":
        flags.append(("wait", "CI 진행 중"))
    elif ci == "SUCCESS":
        flags.append(("good", "CI 통과"))
    if pr["mergeable"] == "CONFLICTING":
        flags.append(("bad", "충돌"))
    if open_threads:
        flags.append(("wait", f"열린 스레드 {open_threads}"))
    if screen:
        flags.append(("info", "iPad 확인 필요" if not ipad_ok else "iPad 확인됨"))
    if lgtm_sha and not lgtm_here:
        flags.append(("wait", "LGTM 뒤 새 푸시"))

    if pr["isDraft"]:
        return "draft", author, "초안: 작성 중", since, flags, screen
    if ci in ("FAILURE", "ERROR") or pr["mergeable"] == "CONFLICTING":
        what = "CI 고치기" if ci in ("FAILURE", "ERROR") else "develop 충돌 해결"
        return "fixing", author, what, since, flags, screen
    if lgtm_here:
        if screen and not ipad_ok:
            return "user", "사용자", "iPad에서 화면 확인 (확인 후 PR에 'iPad OK')", lgtm_at, flags, screen
        return "merge", author, "머지하기 (LGTM · CI 통과)" if ci == "SUCCESS" else "CI 끝나면 머지", lgtm_at, flags, screen
    if not last_review:
        return "review", "리뷰 세션", "첫 리뷰", parse_time(pr["createdAt"]), flags, screen
    if last_review["commit"] and not head.startswith(last_review["commit"]["oid"]):
        return "rereview", "리뷰 세션", "새 커밋 재리뷰", since, flags, screen
    if open_threads:
        return "fixing", author, f"리뷰 코멘트 {open_threads}개 반영 또는 답글", parse_time(last_review["submittedAt"]), flags, screen
    return "rereview", "리뷰 세션", "남은 지적 없음: LGTM 또는 다음 리뷰", parse_time(last_review["submittedAt"]), flags, screen


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


def local_branches(checked_out):
    fmt = "%(refname:short)|%(upstream:short)|%(upstream:track)|%(committerdate:unix)"
    out = git("for-each-ref", "--format=" + fmt, "refs/heads") or ""
    cutoff = time.time() - LOCAL_BRANCH_DAYS * 86400
    items = []
    for line in out.splitlines():
        name, upstream, track, when = line.split("|")
        if name in ("main", "develop") or name in checked_out:
            continue
        if not upstream:
            if int(when) >= cutoff:
                items.append({"branch": name, "kind": "push 안 함", "when": int(when)})
        elif "gone" in track:
            items.append({"branch": name, "kind": "원격 삭제됨 (머지 뒤 정리 가능)", "when": int(when)})
        elif "ahead" in track:
            items.append({"branch": name, "kind": "push 안 된 커밋 " + re.sub(r"\D", "", track.split(",")[0]), "when": int(when)})
    return sorted(items, key=lambda b: -b["when"])


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
"""


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

    error, open_prs, merged = None, [], []
    try:
        open_prs, merged = fetch_prs(slug)
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
    merged_branches = set()
    for pr in merged:
        merged_branches.add(pr["headRefName"])
        t = parse_time(pr["mergedAt"])
        if t and t >= cutoff:
            s = by_pr.get(pr["number"]) or by_branch.get(pr["headRefName"])
            files = [n["path"] for n in pr["files"]["nodes"]]
            cards["merged"].append({"pr": pr, "author": s["title"] if s else "", "since": t,
                                    "chips": category(pr["title"], files), "flags": [], "actor": None})

    wts = worktrees()
    checked_out = {w.get("branch") for w in wts if w.get("branch")}
    branches = local_branches(checked_out)
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
         f'<header><h1>작업 현황판</h1><span class="soft">{esc(slug)} · {dt.datetime.now().strftime("%H:%M:%S")} 갱신 · 30초마다 새로고침</span></header>',
         '<div class="wrap">']
    if error:
        h.append(f'<div class="banner">GitHub를 읽지 못했습니다: {esc(error)}. 로컬 정보만 보여 줍니다.</div>')

    # Who has to act now
    h.append('<section><h2>지금 누가 무엇을 해야 하나</h2><div class="who">')
    order = sorted(who.items(), key=lambda kv: (kv[0] != "사용자", kv[0] != reviewer, kv[0]))
    if not order:
        h.append('<div class="box soft">열린 PR이 없습니다.</div>')
    for actor, items in order:
        h.append(f'<div class="box"><b>{esc(actor)}</b> <span class="soft">· {len(items)}건</span><ul>')
        for c in sorted(items, key=lambda c: c["since"] or now()):
            h.append(f'<li><a href="{esc(c["pr"]["url"])}">#{c["pr"]["number"]}</a> {esc(c["what"])} '
                     f'<span class="soft">({esc(ago(c["since"]))}부터)</span></li>')
        h.append("</ul></div>")
    h.append("</div></section>")

    # Lanes
    h.append('<section class="lanes">')
    for key, label in LANES:
        h.append(f'<div class="lane"><h2><span>{label}</span><span class="soft">{len(cards[key])}</span></h2>')
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
        h.append("</div>")
    h.append("</section>")

    # Sessions, local-only work, machine
    h.append('<section class="grid2">')
    h.append('<div class="box"><h2>세션</h2><table><tr><th>세션</th><th>상태</th><th>만든 PR</th></tr>')
    open_numbers = {p["number"]: p for p in open_prs}
    for s in sorted(sessions.values(), key=lambda s: s["mtime"], reverse=True):
        cls, label = session_state(s)
        prs = " ".join(f'<a href="{esc(open_numbers[n]["url"])}">#{n}</a>' for n in s["prs"] if n in open_numbers)
        h.append(f'<tr><td>{esc(s["title"])}</td><td><span class="dot {cls}"></span>{label} '
                 f'<span class="soft">({esc(ago(s["mtime"]))})</span></td><td>{prs or "<span class=soft>열린 PR 없음</span>"}</td></tr>')
    h.append("</table></div>")

    # Local work: what still needs a push or a PR first, then what can be cleaned up (folded)
    attention, cleanup = [], []
    for w in wts:
        if w.get("missing"):
            cleanup.append((esc(w["path"]), "폴더 없음: <code>git worktree prune</code>", ""))
            continue
        b = w.get("branch")
        shared = w["path"] == repo_root
        name = "공유 체크아웃" if shared else os.path.basename(w["path"])
        where = f'{esc(name)}<br><code>{esc(b or "detached")}</code>'
        who_ = "여러 세션이 함께 씀" if shared else owner_of(w["path"])
        notes = []
        if w.get("dirty"):
            notes.append(f'<span class="f-wait">커밋 안 된 변경 {w["dirty"]}</span>')
        if b and b not in ("develop", "main"):
            if w.get("ahead") is None:
                notes.append('<span class="f-wait">push 안 함</span>')
            elif w["ahead"]:
                notes.append(f'<span class="f-wait">push 안 된 커밋 {w["ahead"]}</span>')
            if b in pr_by_branch:
                notes.append(f'<a href="{esc(pr_by_branch[b]["url"])}">PR #{pr_by_branch[b]["number"]}</a> 작업 폴더')
            elif b in merged_branches and not w.get("dirty") and not w.get("ahead"):
                cleanup.append((where, '<span class="f-good">머지됨: worktree 정리 가능</span>', esc(who_)))
                continue
            elif b in merged_branches:
                notes.append('<span class="f-bad">머지된 브랜치에 남은 작업</span>')
            else:
                notes.append('<span class="f-info">PR 없음</span>')
        if notes:
            attention.append((where, " · ".join(notes), esc(who_)))
    for br in branches:
        if br["branch"] in pr_by_branch:
            continue
        s = by_branch.get(br["branch"])
        row = (f'<code>{esc(br["branch"])}</code>', esc(br["kind"]), esc(s["title"] if s else ""))
        (cleanup if "정리" in br["kind"] else attention).append(row)

    def table(rows):
        return "".join(f'<tr><td>{a}</td><td>{b}</td><td class="soft">{c}</td></tr>' for a, b, c in rows)

    h.append('<div class="box"><h2>로컬에만 있는 작업</h2><table><tr><th>위치</th><th>상태</th><th>세션</th></tr>')
    h.append(table(attention) or '<tr><td colspan="3" class="soft">push나 PR을 기다리는 로컬 작업이 없습니다.</td></tr>')
    h.append("</table>")
    if cleanup:
        h.append(f'<details><summary class="soft">정리 가능 {len(cleanup)}개 (머지됨, 원격 삭제됨)</summary><table>'
                 f'{table(cleanup)}</table></details>')
    h.append("</div>")

    free = mac["free"]
    h.append('<div class="box"><h2>이 맥 (8 GB)</h2><ul>')
    h.append(f'<li>메모리 여유: <b class="{"f-bad" if free is not None and free < 15 else ""}">{free if free is not None else "?"}%</b></li>')
    bz = mac["bazel"]
    h.append(f'<li>Bazel 서버 {len(bz)}개' + (": " + ", ".join(f"{esc(n)} {r} MB" for n, r in bz) if bz else "") +
             (' <span class="f-bad">(한 번에 하나만)</span>' if len(bz) > 1 else "") + "</li>")
    sims = mac["sims"]
    h.append(f'<li>켜진 시뮬레이터 {len(sims)}대' + (": " + esc(", ".join(sims)) if sims else "") +
             (' <span class="f-bad">(하나만)</span>' if len(sims) > 1 else "") + "</li>")
    h.append(f'<li>lessons inbox: {mac["lessons"]}개' + (' <span class="f-wait">(5개 이상: skill-retro)</span>' if mac["lessons"] >= 5 else "") + "</li>")
    h.append("</ul></div></section>")

    h.append('<p class="soft">사용자 확인: 화면을 바꾼 PR은 LGTM 뒤 iPad 확인이 필요합니다. 확인하면 PR에 '
             '"iPad OK" 코멘트(또는 <code>ipad-ok</code> 라벨)를 남기면 머지 대기로 넘어갑니다.</p>')
    h.append("</div></body></html>")
    os.makedirs(OUT, exist_ok=True)
    tmp = PAGE + ".tmp"
    with open(tmp, "w") as fh:
        fh.write("\n".join(h))
    os.replace(tmp, PAGE)


def serve(port):
    lock, state = threading.Lock(), {"built": 0.0}

    class Handler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *a, **k):
            super().__init__(*a, directory=OUT, **k)

        def do_GET(self):
            if self.path in ("/", "/index.html"):
                with lock:
                    if time.time() - state["built"] > 25:
                        try:
                            build()
                        except Exception as e:  # serve the last page rather than nothing
                            print("build failed:", e)
                        state["built"] = time.time()
            super().do_GET()

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
