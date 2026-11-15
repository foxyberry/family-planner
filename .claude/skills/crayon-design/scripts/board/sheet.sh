#!/bin/bash
# Contact sheet of <work>/preview/g-<BOARD>.png (from shots.sh), 3 per row at half size -> <work>/preview/<OUT>.png
# Usage: DESIGN_WORK=<work> bash sheet.sh OUT BOARD...
set -euo pipefail
: "${DESIGN_WORK:?set DESIGN_WORK=<work folder>}"
C="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
cd "$DESIGN_WORK/preview"; out=$1; shift
h="<body style='margin:0;display:grid;grid-template-columns:repeat(3,688px)'>"
for n in "$@"; do h+="<div style='position:relative'><img src='g-$n.png' width=688><b style='position:absolute;left:4px;top:0;background:#ff0;font:14px sans-serif'>$n</b></div>"; done
echo "$h" > "$out.html"; rows=$(( ($# + 2) / 3 ))
"$C" --headless=new --hide-scrollbars --window-size=2064,$((rows*516)) --screenshot="$PWD/$out.png" "file://$PWD/$out.html" >/dev/null 2>&1
echo "$PWD/$out.png"
