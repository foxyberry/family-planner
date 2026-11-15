#!/bin/bash
# Render boards and screenshot them to <work>/preview/g-<BOARD>.png (1376 x 1032, device scale $SCALE, default 2).
# Usage: DESIGN_WORK=<work> bash shots.sh BOARD...
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
: "${DESIGN_WORK:?set DESIGN_WORK=<work folder>}"
C="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
python3 "$here/local-render.py" --work "$DESIGN_WORK" "$@"
cd "$DESIGN_WORK/preview"
for f in "$@"; do
  "$C" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor="${SCALE:-2}" --window-size=1376,1032 \
    --screenshot="$PWD/g-$f.png" "file://$PWD/r-$f.html" >/dev/null 2>&1
  echo "$DESIGN_WORK/preview/g-$f.png"
done
