#!/bin/bash
# Tests for scripts/check-skill-refs.sh: names in skills and CLAUDE.md must exist in the repo.
set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/check-skill-refs.sh"
PASS=0
FAIL=0

new_tree() {
  TREE="$(mktemp -d)"
  git -C "$TREE" init -q
  mkdir -p "$TREE/.claude/skills/demo/references" "$TREE/ios/DesignSystem" "$TREE/scripts" "$TREE/docs"
  printf 'docs/private/\n' > "$TREE/.gitignore"
  cat > "$TREE/ios/DesignSystem/Layout.swift" <<'EOF'
public struct GrownupLayout { public var labelWidth: CGFloat }
public struct Sizing { public var s: CGFloat }
extension Sizing { func tabWidth(_ board: CGFloat) -> CGFloat { board } }
public enum CrayonPart { case inset, pickRing }
extension View { func drawnRow() -> some View { self } }
struct KidCard {}
EOF
  printf '#!/bin/bash\n' > "$TREE/scripts/check-demo.sh"
  printf '# guide\n' > "$TREE/.claude/skills/demo/references/guide.md"
  printf '# Demo\n' > "$TREE/CLAUDE.md"
}

run_with() { # skill text
  printf -- '---\nname: demo\n---\n%s\n' "$1" > "$TREE/.claude/skills/demo/SKILL.md"
  ERR="$(bash "$SCRIPT" "$TREE" 2>&1 >/dev/null)"; CODE=$?
}

assert() {
  if [ "$2" -eq 0 ]; then PASS=$((PASS + 1)); echo "PASS $1"; else FAIL=$((FAIL + 1)); echo "FAIL $1 (code=$CODE err=$ERR)"; fi
}

passes() { new_tree; run_with "$2"; [ "$CODE" -eq 0 ]; assert "$1" $?; }
blocks() { new_tree; run_with "$2"; [ "$CODE" -eq 1 ] && [[ "$ERR" == *"$3"* ]]; assert "$1" $?; }

blocks "a member the type doesn't declare (the tabWidth lesson)" 'Use `GrownupLayout.tabWidth`.' "GrownupLayout declares no tabWidth"
passes "a member declared in an extension" 'Use `Sizing.tabWidth`.'
passes "an enum case" 'Use `CrayonPart.inset`.'
passes "a type from outside the repo is skipped" 'Use `DependencyValues._current`.'
blocks "a misspelt type" 'Use `KidCrad`.' "not found in the code"
passes "a type that exists" 'Use `KidCard`.'
passes "a func that exists" 'Call `drawnRow()`.'
blocks "a func that doesn't exist" 'Call `captionRow()`.' "no such func"
blocks "a missing repo path" 'Run `scripts/check-nope.sh`.' "no such file"
passes "a path that exists" 'Run `scripts/check-demo.sh`.'
passes "a bare file name found anywhere" 'Run `check-demo.sh`.'
passes "a path from the skill's folder" 'Read `references/guide.md`.'
passes "a git-ignored path" 'Keep it in `docs/private/`.'
passes "branch patterns and time zones are not paths" 'Branch `feature/*`, zone `Asia/Singapore`.'
passes "commands and placeholders are skipped" 'Run `make test-one TARGET=x` on `docs/<board>.json`.'
passes "fenced blocks are skipped" $'```\n`GrownupLayout.tabWidth`\n```'
passes "a dot path that exists" 'Read `.claude/skills/demo/references/guide.md`.'
blocks "a dot path that doesn't exist" 'Read `.claude/lessons.md`.' "no such file"
passes "a leading-dot Swift call is skipped" 'Call `.drawnRow()` on the row.'
blocks "a Bazel label without its package" 'Test `//ios/Nope/Tests:NopeTests`.' "no such Bazel package"
new_tree; mkdir -p "$TREE/ios/Demo"; printf 'x\n' > "$TREE/ios/Demo/BUILD.bazel"; run_with 'Build `//ios/Demo:Demo` and `//ios/...`.'
[ "$CODE" -eq 0 ]; assert "a Bazel label with its package, and a wildcard" $?
new_tree; printf 'GrownupLayout.tabWidth\n' > "$TREE/scripts/skill-refs-allow.txt"; run_with 'Use `GrownupLayout.tabWidth`.'
[ "$CODE" -eq 0 ]; assert "the allow-list lets a name through" $?

echo "check-skill-refs: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
