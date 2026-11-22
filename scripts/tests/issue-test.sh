#!/bin/bash
# Tests for scripts/issue.sh (new / list / close) and the board's reader of the same files.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ISSUE="$HERE/../issue.sh"
BOARD="$HERE/../../tools/board/board.py"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export ISSUES_DIR="$tmp/.claude/issues"
failed=0
check() { if [ "$2" = "$3" ]; then echo "ok: $1"; else echo "FAIL: $1: want [$3], got [$2]"; failed=1; fi; }

first="$(bash "$ISSUE" new main "Keyboard shift with a hardware keyboard" "ios/Clients")"
check "first issue is 001 with a slug" "$(basename "$first")" "001-keyboard-shift-with-a-hardware-keyboard.md"
second="$(bash "$ISSUE" new design "버스 그림 정리")"
check "a title with no ASCII gets a plain slug" "$(basename "$second")" "002-issue.md"
check "fields are written" "$(sed -n 's/^owner: //p' "$first")|$(sed -n 's/^status: //p' "$first")" "main|open"

check "list shows both" "$(bash "$ISSUE" list | wc -l | tr -d ' ')" "2"
check "list filters by owner" "$(bash "$ISSUE" list design | cut -c1-3)" "002"

bash "$ISSUE" start 2 > /dev/null
check "start marks it doing" "$(sed -n 's/^status: //p' "$second" | cut -d' ' -f1)" "doing"
check "list marks a doing issue" "$(bash "$ISSUE" list design | grep -c '(doing)')" "1"
bash "$ISSUE" stop 2 > /dev/null
check "stop puts it back to open" "$(sed -n 's/^status: //p' "$second")" "open"
bash "$ISSUE" start x > /dev/null 2>&1
check "start needs a number" "$?" "2"
bash "$ISSUE" close 1 > /dev/null
check "close marks it done" "$(sed -n 's/^status: //p' "$first" | cut -d' ' -f1)" "done"
check "a closed issue leaves the list" "$(bash "$ISSUE" list | cut -c1-3)" "002"
check "numbers keep counting after a close" "$(basename "$(bash "$ISSUE" new main "Next")")" "003-next.md"
bash "$ISSUE" close 9 > /dev/null 2>&1
check "closing a missing issue fails" "$?" "1"
bash "$ISSUE" close foo > /dev/null 2>&1
check "closing a non-number is a usage error" "$?" "2"
printf '# Blank status\n\nowner: main\nstatus:\n' > "$ISSUES_DIR/004-blank.md"

board="$(python3 -I - "$BOARD" "$tmp" <<'EOF'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("board", sys.argv[1])
board = importlib.util.module_from_spec(spec)
spec.loader.exec_module(board)
for i in board.read_issues(sys.argv[2]):
    print(i["file"][:3], i["owner"], (i["status"].split() or ["-"])[0], i["title"])
print(len(board.read_issues(sys.argv[2] + "/missing")))
blank = [{"file": "004-blank.md", "number": "004", "title": "Blank", "owner": "main", "status": "",
          "opened": "", "area": ""}]
print("number shown" if "이슈 004" in board.issue_list("main", blank) else "number missing")
print("blank status renders" if "Blank" in board.issue_list("main", blank) else "blank status lost")
many = [dict(blank[0], number=f"00{n}", title=f"Issue {n}") for n in range(1, 6)]
html = board.issue_list("main", many)
shown = html.split("<details")[0]
print("two shown, three folded" if shown.count("<li>") == 2 and "3건 더 보기" in html and html.count("<li>") == 5
      else "fold wrong")
print("no fold for two" if "<details" not in board.issue_list("main", many[:2]) else "fold for two")
EOF
)"
check "board reads every issue with its fields" "$(printf '%s\n' "$board" | head -3 | cut -d' ' -f1-3 | tr '\n' ',')" \
  "001 main done,002 design open,003 main open,"
check "board reads no folder as no issues" "$(printf '%s\n' "$board" | tail -5 | head -1)" "0"
check "the board leads each issue with its number" "$(printf '%s\n' "$board" | tail -4 | head -1)" "number shown"
check "a blank status still renders" "$(printf '%s\n' "$board" | tail -3 | head -1)" "blank status renders"
check "a card shows two issues and folds the rest" "$(printf '%s\n' "$board" | tail -2 | head -1)" "two shown, three folded"
check "two issues need no fold" "$(printf '%s\n' "$board" | tail -1)" "no fold for two"

[ "$failed" = 0 ] && echo "issue: all passed"
exit "$failed"
