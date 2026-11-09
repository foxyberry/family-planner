#!/bin/bash
# private-sync.sh (`make private`) must copy exactly the required school-data files into the
# git-ignored Private/ folder, leave other local files alone, refuse invalid or incomplete data,
# and skip quietly (exit 0) when the private repo is out of reach, so `make setup` works on a
# public clone while the Bazel check still stops the build. Uses fake data only.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/private-sync.sh"
FAIL=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; FAIL=1; }

# A fake app checkout (the script resolves its own location) and a fake private repo.
APP="$TMP/app"
mkdir -p "$APP/scripts" "$APP/ios/Clients/SchoolDirectoryLive/Private"
cp "$SCRIPT" "$APP/scripts/private-sync.sh"
git -C "$APP" init -q
PRIV="$TMP/private"
DATA="$PRIV/data/school-data"
mkdir -p "$DATA"
for f in international-schools-sg.json preschools-sg.json preschool-calendar-rules.json schools-sg.json; do
  echo "{\"name\": \"$f\"}" > "$DATA/$f"
done
printf 'import sys\nsys.exit(0)\n' > "$DATA/validate.py"
git -C "$PRIV" init -q
DEST="$APP/ios/Clients/SchoolDirectoryLive/Private"
echo '{"local": true}' > "$DEST/international-schools-local.json"

run() { PRIVATE_DIR="$1" bash "$APP/scripts/private-sync.sh" >"$TMP/out" 2>&1; }

if run "$PRIV" && [ -f "$DEST/international-schools-sg.json" ] && [ -f "$DEST/preschools-sg.json" ] && [ -f "$DEST/preschool-calendar-rules.json" ]; then
  pass "copies the three required files"
else
  fail "required files not copied: $(cat "$TMP/out")"
fi
[ ! -e "$DEST/schools-sg.json" ] && [ ! -e "$DEST/validate.py" ] && pass "copies nothing else" || fail "copied files that are not required"
[ -f "$DEST/international-schools-local.json" ] && pass "keeps other local files" || fail "removed a local file"

echo '{"name": "updated"}' > "$DATA/preschools-sg.json"
run "$PRIV" && cmp -s "$DATA/preschools-sg.json" "$DEST/preschools-sg.json" && pass "updates a changed file" || fail "did not update a changed file"

printf 'import sys\nsys.exit(1)\n' > "$DATA/validate.py"
echo '{"name": "bad"}' > "$DATA/preschools-sg.json"
if run "$PRIV"; then fail "accepted data that does not validate"; else
  grep -q '"updated"' "$DEST/preschools-sg.json" && pass "refuses data that does not validate (nothing copied)" || fail "copied invalid data"
fi
printf 'import sys\nsys.exit(0)\n' > "$DATA/validate.py"

rm "$DATA/preschool-calendar-rules.json"
run "$PRIV" && fail "accepted data with a required file missing" || pass "refuses data with a required file missing"

# Out of reach: no checkout and no gh on PATH -> notice, exit 0, nothing copied.
rm -f "$DEST"/preschools-sg.json
if PATH="/usr/bin:/bin" PRIVATE_DIR="$TMP/none" bash "$APP/scripts/private-sync.sh" >"$TMP/out" 2>&1; then
  grep -q "School data missing" "$TMP/out" && [ ! -e "$DEST/preschools-sg.json" ] && pass "skips when the private repo is out of reach, and says builds will stop" || fail "skip message or state wrong: $(cat "$TMP/out")"
else
  fail "exited non-zero when the private repo is out of reach"
fi

exit $FAIL
