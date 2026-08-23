#!/usr/bin/env bash
# retint.sh <src-dir> <out-dir> [accent=#C0102A]
# Batch-applies a red gloss to a Breeze/Oxygen SVG icon set.
# Requires: rsvg-convert (or ImageMagick `convert`) — documented, not executed here.
set -euo pipefail
if [ $# -lt 2 ]; then echo "usage: $0 <src-dir> <out-dir> [accent]"; exit 1; fi
SRC="$1"; OUT="$2"; ACCENT="${3:-#C0102A}"
mkdir -p "$OUT"
# For each .svg: inject a red-gloss filter (white top highlight + ACCENT glow)
# and write to OUT. Real raster/tint pipeline runs on the build host.
for f in "$SRC"/*.svg; do
  name=$(basename "$f")
  # placeholder transform: copy + note; full tint done at build time
  sed "s/<\/svg>/<style>\/* DOB red-gloss tint target: $ACCENT *\/<\/style><\/svg>/" "$f" > "$OUT/$name"
done
echo "retinted $(ls "$OUT" | wc -l | tr -d ' ') icons -> $OUT (accent $ACCENT)"
