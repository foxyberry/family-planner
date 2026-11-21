#!/bin/bash
# Tests for scripts/test-affected.sh with stub bazel, make and pgrep (no Bazel needed; CI too).
set -u

SRC="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0
STUBS="$(mktemp -d)"
LOG="$STUBS/calls.log"
# bazel: logs its query and answers STUB_TARGETS; make: logs its TARGET; pgrep: STUB_BUSY=1 finds one.
cat > "$STUBS/bazel" <<'EOF'
#!/bin/bash
echo "bazel $*" >> "$STUB_LOG"
printf '%s\n' ${STUB_TARGETS:-}
EOF
cat > "$STUBS/make" <<'EOF'
#!/bin/bash
echo "make $*" >> "$STUB_LOG"
EOF
cat > "$STUBS/pgrep" <<'EOF'
#!/bin/bash
[ "${STUB_BUSY:-0}" = 1 ]
EOF
chmod +x "$STUBS"/*
export PATH="$STUBS:/usr/bin:/bin" STUB_LOG="$LOG"

new_repo() { # a repo with one commit; the change under test comes after it
  : > "$LOG"
  REPO="$(mktemp -d)"
  git -C "$REPO" init -q
  git -C "$REPO" config user.email t@example.com
  git -C "$REPO" config user.name t
  mkdir -p "$REPO/scripts" "$REPO/ios/Domain/Tests"
  cp "$SRC/scripts/test-affected.sh" "$REPO/scripts/"
  printf 'struct A {}\n' > "$REPO/ios/Domain/A.swift"
  printf 'x\n' > "$REPO/README.md"
  git -C "$REPO" add -A && git -C "$REPO" commit -q -m base
}

run() { OUT="$(cd "$REPO" && bash scripts/test-affected.sh "$@" 2>&1)"; CODE=$?; }

assert() {
  if [ "$2" -eq 0 ]; then PASS=$((PASS + 1)); echo "PASS $1"; else FAIL=$((FAIL + 1)); echo "FAIL $1 (code=$CODE out=$OUT log=$(cat "$LOG"))"; fi
}

new_repo; printf 'y\n' > "$REPO/README.md"; run HEAD
[ "$CODE" -eq 0 ] && [[ "$OUT" == *"no change under ios/"* ]] && ! grep -q bazel "$LOG"; assert "no iOS change runs nothing" $?

new_repo; printf 'struct A { var b = 1 }\n' > "$REPO/ios/Domain/A.swift"
STUB_TARGETS="//ios/Domain/Tests:DomainTests" run HEAD
grep -q 'rdeps(//ios/..., set(ios/Domain/A.swift))' "$LOG" && grep -q 'except attr("tags", "snapshot|ui|manual"' "$LOG" \
  && grep -q 'make test-one TARGET=//ios/Domain/Tests:DomainTests' "$LOG"
assert "a Swift change tests its reverse dependencies, without snapshot or ui tests" $?

new_repo; printf 'x\n' > "$REPO/ios/Domain/BUILD.bazel"; run HEAD
grep -q 'set(//ios/Domain:all)' "$LOG"; assert "a BUILD file stands for its package" $?

new_repo; printf 'm\n' > "$REPO/MODULE.bazel"; printf 'struct A { }\n' > "$REPO/ios/Domain/A.swift"; run HEAD
grep -q 'kind("ios_unit_test", //ios/...)' "$LOG"; assert "a MODULE.bazel change tests everything" $?

new_repo; printf 'struct A { var b = 1 }\n' > "$REPO/ios/Domain/A.swift"
STUB_TARGETS="//ios/Domain/Tests:DomainTests" run --print HEAD
[[ "$OUT" == *"//ios/Domain/Tests:DomainTests"* ]] && ! grep -q '^make' "$LOG"; assert "--print lists and runs nothing" $?

new_repo; printf 'struct A { var b = 1 }\n' > "$REPO/ios/Domain/A.swift"
STUB_BUSY=1 run --skip-if-busy HEAD
[ "$CODE" -eq 0 ] && [[ "$OUT" == *"Tests needed in the PR"* ]] && ! grep -q bazel "$LOG"
assert "busy Bazel: skip with a note, exit 0" $?

new_repo; printf 'struct A { var b = 1 }\n' > "$REPO/ios/Domain/A.swift"; git -C "$REPO" commit -qam change
git -C "$REPO" checkout -q HEAD~1; run --skip-if-busy HEAD~0 master
[ "$CODE" -eq 0 ] || [[ "$OUT" == *"not the checked-out commit"* ]]; assert "a commit that isn't checked out is skipped" $?

new_repo; printf 'struct A { var b = 1 }\n' > "$REPO/ios/Domain/A.swift"; run HEAD
[ "$CODE" -eq 0 ] && [[ "$OUT" == *"no test target depends"* ]] && ! grep -q '^make' "$LOG"
assert "no dependent test target runs nothing" $?

echo "test-affected: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
