#!/bin/bash
# Skills and CLAUDE.md name code in backticks, and a name that doesn't exist sends the next session
# the wrong way (2026-11-21: a lesson named `GrownupLayout.tabWidth`; the API is Sizing.tabWidth).
# This checks the backtick spans of .claude/skills/*/SKILL.md and CLAUDE.md (outside fenced blocks):
#   - a repo path (ios/…, scripts/…, a file with a known extension) must exist, from the repo root or
#     from the skill's own folder; a Bazel label //pkg:target needs pkg/BUILD.bazel;
#   - `Type.member` must name a member declared in a Swift file that declares or extends Type
#     (types not declared in this repo, from TCA or SwiftUI, are skipped);
#   - `CamelCaseName` must appear as a word in the code (ios/, scripts/, tools/, Makefile);
#   - `name()` must be a func declared in Swift.
# Placeholders (<board>, {path}), commands with spaces and flags are skipped. A name that is right
# but can't be checked goes on its own line in scripts/skill-refs-allow.txt.
# Usage: check-skill-refs.sh [repo root]
set -u
ROOT="${1:-$(git rev-parse --show-toplevel)}"

python3 -I - "$ROOT" <<'EOF'
import glob, os, re, sys

root = sys.argv[1]
allow_path = os.path.join(root, "scripts", "skill-refs-allow.txt")
allow = set()
if os.path.exists(allow_path):
    allow = {l.strip() for l in open(allow_path) if l.strip() and not l.startswith("#")}

docs = sorted(glob.glob(os.path.join(root, ".claude", "skills", "*", "SKILL.md")))
if os.path.exists(os.path.join(root, "CLAUDE.md")):
    docs.append(os.path.join(root, "CLAUDE.md"))

swift = {}
for path in glob.glob(os.path.join(root, "ios", "**", "*.swift"), recursive=True):
    try:
        swift[path] = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        pass
code_words = set()
for text in swift.values():
    code_words.update(re.findall(r"[A-Za-z_][A-Za-z0-9_]*", text))
for pattern in ("scripts/**/*", "tools/**/*.py", "tools/**/*.js", "Makefile", "**/BUILD.bazel", "*.bzl", "ios/*.bzl"):
    for path in glob.glob(os.path.join(root, pattern), recursive=True):
        if os.path.isfile(path) and "/node_modules/" not in path and "/.build/" not in path:
            try:
                code_words.update(re.findall(r"[A-Za-z_][A-Za-z0-9_]*", open(path, errors="replace").read()))
            except OSError:
                pass

# Every file in the tree (paths from the root), to resolve bare file names and suffixes.
SKIP_DIRS = {".git", "node_modules", ".build", ".swiftpm", "__pycache__"}
files = []
for base, dirs, names in os.walk(root):
    dirs[:] = [d for d in dirs if d not in SKIP_DIRS and not d.startswith("bazel-")]
    files += [os.path.relpath(os.path.join(base, n), root) for n in names]
    files += [os.path.relpath(os.path.join(base, d), root) + "/" for d in dirs]
top = {f.split("/")[0] for f in files}


def ignored(path):
    """Git-ignored paths (docs/private/, KitArt/Private/) exist only on the user's Mac."""
    import subprocess
    try:
        return subprocess.run(["git", "-C", root, "check-ignore", "-q", path],
                              capture_output=True).returncode == 0
    except OSError:
        return False


def path_exists(t, doc_dir):
    import fnmatch
    rel_doc = os.path.relpath(doc_dir, root)
    want = t.rstrip("/")
    for f in files:
        g = f.rstrip("/")
        if (fnmatch.fnmatch(g, want) or fnmatch.fnmatch(g, "*/" + want)
                or fnmatch.fnmatch(g, os.path.join(rel_doc, want))):
            return True
    return False


TYPE_DECL = r"\b(?:struct|enum|class|protocol|actor|typealias)\s+{}\b"
EXTENDS = r"\b(?:struct|enum|class|protocol|actor|typealias|extension)\s+{}\b"
MEMBER_DECL = (r"(?:\b(?:var|let|func|case|enum|struct|class|typealias|init)\s+{0}\b"
               r"|\bcase\b[^\n]*[\s,]{0}\s*(?:[,(=\n]|$))")
EXT = (".md", ".sh", ".swift", ".json", ".bzl", ".bazel", ".py", ".txt", ".yml", ".yaml", ".js", ".plist", ".xcstrings")


TOP_DECL = re.compile(r"^(?:@\w+\s+)*(?:(?:public|internal|private|fileprivate|final|open|nonisolated)\s+)*"
                      r"(?:struct|enum|class|protocol|actor|extension|func|let|var|typealias)\b", re.M)


def type_bodies(name):
    """The text of each top-level declaration or extension of a type declared in this repo, up to
    the next top-level declaration; [] for outside types (TCA, SwiftUI, Foundation)."""
    if not any(re.search(TYPE_DECL.format(re.escape(name)), t) for t in swift.values()):
        return []
    rx = re.compile(r"^(?:@\w+\s+)*(?:(?:public|internal|private|fileprivate|final|open)\s+)*"
                    + EXTENDS.format(re.escape(name)), re.M)
    bodies = []
    for text in swift.values():
        for m in rx.finditer(text):
            nxt = TOP_DECL.search(text, m.end())
            bodies.append(text[m.start(): nxt.start() if nxt else len(text)])
    return bodies


def check(token, doc_dir):
    """None when the token is fine or can't be checked, else why it fails."""
    t = re.sub(r":\d+$", "", token.strip())
    if (not t or " " in t or t.startswith(("-", "~", "/", "@", "\\", ".", "$")) or "://" in t
            or re.search(r"[<>{}\"'=|;,`]", t) or re.fullmatch(r"[\d.%x×·]+", t)):
        return None
    if t.startswith("//"):  # Bazel label
        pkg = t[2:].split(":")[0]
        return None if os.path.isfile(os.path.join(root, pkg, "BUILD.bazel")) or os.path.isfile(
            os.path.join(root, pkg, "BUILD")) else "no such Bazel package"
    # A path: a known extension, or a first segment that is a top-level entry of the repo
    # (`Asia/Singapore` and branch names like `feature/*` are not paths).
    if t.endswith(EXT) or t == "Makefile" or ("/" in t and t.split("/")[0] in top):
        if "(" in t or not re.fullmatch(r"[\w./*+-]+", t):
            return None
        if path_exists(t, doc_dir) or ignored(t):
            return None
        return "no such file or folder"
    call = re.fullmatch(r"([a-z]\w*)\(.*\)", t)
    if call:
        return None if re.search(r"\bfunc\s+{}\b".format(re.escape(call.group(1))), "\n".join(swift.values())) else "no such func in ios/"
    t = re.sub(r"\(.*\)$", "", t)
    dotted = re.fullmatch(r"([A-Z]\w*)\.([A-Za-z_]\w*)(?:\.\w+)*", t)
    if dotted:
        owner, member = dotted.groups()
        bodies = type_bodies(owner)
        if not bodies:
            return None  # not a type of this repo (TCA, SwiftUI, Foundation)
        rx = re.compile(MEMBER_DECL.format(re.escape(member)), re.M)
        return None if any(rx.search(b) for b in bodies) else f"{owner} declares no {member}"
    if re.fullmatch(r"[A-Z][a-z0-9]+[A-Z][A-Za-z0-9]*", t):
        return None if t in code_words else "not found in the code"
    return None


failures = 0
for doc in docs:
    rel = os.path.relpath(doc, root)
    fenced = False
    for n, line in enumerate(open(doc, encoding="utf-8"), 1):
        if line.lstrip().startswith("```"):
            fenced = not fenced
            continue
        if fenced:
            continue
        for token in re.findall(r"`([^`\n]+)`", line):
            if token in allow:
                continue
            why = check(token, os.path.dirname(doc))
            if why:
                failures += 1
                print(f"skill-refs: {rel}:{n}: `{token}`: {why}", file=sys.stderr)
if failures:
    print(f"skill-refs: {failures} reference(s) don't match the repo. Fix the name, or add a name that is "
          "right but uncheckable to scripts/skill-refs-allow.txt.", file=sys.stderr)
sys.exit(1 if failures else 0)
EOF
