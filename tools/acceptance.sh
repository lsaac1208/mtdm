#!/usr/bin/env bash
# One-shot acceptance run for the Taoist Wanderer vertical slice.
# Usage: GODOT=/path/to/Godot_v4.7.2 tools/acceptance.sh [version]
# Writes evidence/acceptance-<date>/ (logs, screenshots, REPORT.md). Exit 0 = all gates passed.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
G="${GODOT:-godot}"
VER="${1:-dev}"
OUT="$ROOT/evidence/acceptance-$(date +%Y%m%d)"
PY="${PYTHON:-python3}"
mkdir -p "$OUT/shots"
cd "$ROOT/game"
fail=0
gate() { # name, status
  echo "| $1 | $2 |" >> "$OUT/gates.md"
  [ "$2" = "PASS" ] || fail=1
}
: > "$OUT/gates.md"

echo "== import"
timeout 600 "$G" --headless --path . --import > "$OUT/import.log" 2>&1

echo "== engine tests"
timeout 1200 "$G" --headless --path . -- --test=all --nohitstop --mute > "$OUT/tests.log" 2>&1
line=$(grep "TESTS DONE" "$OUT/tests.log")
grep -q "fail=0" <<< "$line" && gate "Engine tests ($line)" PASS || gate "Engine tests ($line)" FAIL
grep -E "^SPEC" "$OUT/tests.log" > "$OUT/spec.txt"

echo "== bots"
for i in 1 2 3; do
  timeout 1200 "$G" --headless --fixed-fps 60 --path . -- --test=bot --mute --bot_limit=1500 > "$OUT/bot_$i.log" 2>&1 &
done
for i in 1 2 3; do
  timeout 1500 "$G" --headless --fixed-fps 60 --path . -- --test=bot --mute --nohitstop --bot_skill=human --bot_limit=2400 > "$OUT/bot_human_$i.log" 2>&1 &
done
wait
for f in "$OUT"/bot_*.log; do
  r=$(grep "^TEST bot_completes_demo" "$f" | sed 's/  */ /g')
  grep -q PASS <<< "$r" && gate "$(basename "$f" .log): $r" PASS || gate "$(basename "$f" .log): $r" FAIL
done

echo "== export"
mkdir -p "$ROOT/build"
if GODOT="$G" $PY "$ROOT/tools/build/package.py" "$VER" > "$OUT/package.log" 2>&1; then gate "Export + package Linux/Windows ($VER)" PASS; else gate "Export + package" FAIL; fi
ls -la "$ROOT"/build/*.zip >> "$OUT/package.log" 2>&1

echo "== exported linux build"
(cd "$ROOT/build/linux" && timeout 1200 ./TaoistWanderer.x86_64 --headless --fixed-fps 60 -- --test=all --nohitstop --mute > "$OUT/exported_tests.log" 2>&1)
line=$(grep "TESTS DONE" "$OUT/exported_tests.log")
grep -q "fail=0" <<< "$line" && gate "Exported Linux build tests ($line)" PASS || gate "Exported Linux build tests ($line)" FAIL
(cd "$ROOT/build/linux" && timeout 1200 ./TaoistWanderer.x86_64 --headless --fixed-fps 60 -- --test=bot --mute --bot_limit=1500 > "$OUT/exported_bot.log" 2>&1)
r=$(grep "^TEST bot_completes_demo" "$OUT/exported_bot.log" | sed 's/  */ /g')
grep -q PASS <<< "$r" && gate "Exported Linux build bot: $r" PASS || gate "Exported Linux build bot: $r" FAIL

echo "== rendered captures"
if command -v xvfb-run > /dev/null; then
  export LIBGL_ALWAYS_SOFTWARE=1
  run_x() { timeout 300 xvfb-run -a -s "-screen 0 1280x720x24" "$G" --path . --rendering-driver opengl3 --resolution 1280x720 "$@"; }
  run_x -- --shots="$OUT/shots/title" --shot_times=2.5 --quit_after=3 > "$OUT/r_title.log" 2>&1
  for x in 600 3050 5000 7300 9300 10300; do
    run_x -- --autostart --startx=$x --skip_cleared --shots="$OUT/shots/x$x" --shot_times=3 --quit_after=4 > "$OUT/r_$x.log" 2>&1
  done
  run_x -- --test=showcase --shots="$OUT/shots/showcase" --nohitstop --noshake > "$OUT/r_showcase.log" 2>&1
  run_x -- --test=ending_shot --shots="$OUT/shots/ending" > "$OUT/r_end.log" 2>&1
  run_x --fixed-fps 60 -- --test=combocap --shots="$OUT/shots/combo" --nohitstop --noshake --frames=48 > "$OUT/r_combo.log" 2>&1
  timeout 120 xvfb-run -a -s "-screen 0 1280x720x24" "$G" --path . --rendering-driver opengl3 --resolution 1280x720 -- --autostart --startx=9150 --skip_cleared --fpslog --quit_after=14 > "$OUT/fps.log" 2>&1
  n=$(find "$OUT/shots" -name "*.png" | wc -l)
  [ "$n" -ge 20 ] && gate "Rendered captures under Xvfb ($n frames)" PASS || gate "Rendered captures ($n frames)" FAIL
  if command -v "$PY" > /dev/null; then
    $PY - "$OUT/shots" "$OUT/contact.jpg" <<'EOF' 2>/dev/null || true
import sys, glob
from PIL import Image
fs = sorted(glob.glob(sys.argv[1] + "/**/*.png", recursive=True))
fs = [f for f in fs if "/combo/" not in f][:24]
cols = 4
ims = [Image.open(f).convert("RGB").resize((480, 270)) for f in fs]
c = Image.new("RGB", (480 * cols, 270 * ((len(ims) + cols - 1) // cols)))
for i, im in enumerate(ims):
    c.paste(im, ((i % cols) * 480, (i // cols) * 270))
c.save(sys.argv[2])
EOF
  fi
else
  gate "Rendered captures (no xvfb-run on this machine)" SKIPPED
fi

# keep the evidence compact for git: downscaled JPGs instead of full PNGs
if command -v "$PY" > /dev/null; then
  $PY - "$OUT/shots" <<'EOF2' 2>/dev/null || true
import sys, glob, os
from PIL import Image
for f in glob.glob(sys.argv[1] + "/**/*.png", recursive=True):
    im = Image.open(f).convert("RGB")
    im.thumbnail((640, 360))
    im.save(f[:-4] + ".jpg", quality=80)
    os.remove(f)
EOF2
fi
rm -f "$OUT"/import.log

{
  echo "# Acceptance report — $(date -u +%Y-%m-%dT%H:%MZ)"
  echo
  echo "Commit: \`$(git -C "$ROOT" rev-parse --short HEAD)\` on \`$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)\` · Godot: \`$("$G" --version 2>/dev/null | head -1)\`"
  echo
  echo "| Gate | Result |"
  echo "|---|---|"
  cat "$OUT/gates.md"
  echo
  echo "## Spec conformance (docs/05 §2.1–2.3, docs/03)"
  echo '```'
  cat "$OUT/spec.txt"
  echo '```'
  echo
  echo "## Engine checks"
  echo '```'
  grep -E "^TEST" "$OUT/tests.log"
  echo '```'
  echo
  echo "## Rendered performance (1280x720, software GL / llvmpipe, busiest wave)"
  echo '```'
  grep FPS "$OUT/fps.log" 2>/dev/null | tail -5
  echo '```'
  echo
  echo "## Not verifiable here"
  echo "- Human playtest (feel, difficulty, first-time readability)."
  echo "- Listening test of audio (mix verified numerically from a movie-writer recording only)."
  echo "- Windows runtime (export built; no Windows/Wine available)."
  echo "- Physical gamepad (bindings verified by injected joypad events)."
  echo "- Real-GPU frame rate."
} > "$OUT/REPORT.md"
echo "report: $OUT/REPORT.md"
cat "$OUT/gates.md"
exit $fail
