#!/bin/bash
# Wraps the git-ignored private pictures (ios/KitArt/Private/<slot>.svg) into a local asset
# catalog that overrides the public kit picture of the same slot in development builds.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/ios/KitArt/Private"
OUT="$SRC/KitArtPrivate.xcassets"

rm -rf "$OUT"
mkdir -p "$OUT"
printf '{\n  "info" : { "author" : "xcode", "version" : 1 }\n}\n' > "$OUT/Contents.json"
count=0
for svg in "$SRC"/*.svg; do
  [ -e "$svg" ] || continue
  slot="$(basename "$svg" .svg)"
  mkdir -p "$OUT/$slot.imageset"
  cp "$svg" "$OUT/$slot.imageset/$slot.svg"
  cat > "$OUT/$slot.imageset/Contents.json" <<JSON
{
  "images" : [ { "filename" : "$slot.svg", "idiom" : "universal" } ],
  "info" : { "author" : "xcode", "version" : 1 },
  "properties" : { "preserves-vector-representation" : true }
}
JSON
  count=$((count + 1))
done
echo "private overrides: $count"
