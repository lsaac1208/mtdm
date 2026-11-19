#!/usr/bin/env bash
# One-command local verification: import, engine checks, full-route bot, and
# (when xvfb-run is available) one software-rendered title screenshot.
# Usage: GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64 tools/qa/smoke.sh [out_dir]
# Exit 0 = every step passed. Results are automated only, not human approval.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
G="${GODOT:-godot}"
OUT="${1:-$ROOT/build/qa/smoke}"
mkdir -p "$OUT"
fail=0
echo "godot: $("$G" --version)"
echo "commit: $(git -C "$ROOT" rev-parse HEAD)"

timeout 600 "$G" --headless --path "$ROOT/game" --import > "$OUT/import.log" 2>&1 < /dev/null

timeout 1200 "$G" --headless --path "$ROOT/game" -- --test=all --nohitstop --mute > "$OUT/tests.log" 2>&1 < /dev/null
line=$(grep "TESTS DONE" "$OUT/tests.log" || echo "TESTS DONE missing")
echo "engine checks: $line"
grep -Eq "^TESTS DONE pass=[0-9]+ fail=0$" <<< "$line" || fail=1
grep -q "SCRIPT ERROR" "$OUT/tests.log" && { echo "script errors in tests.log"; fail=1; }

timeout 900 "$G" --headless --fixed-fps 60 --path "$ROOT/game" -- --test=bot --mute > "$OUT/bot.log" 2>&1 < /dev/null
bot=$(grep "DEMO_COMPLETE" "$OUT/bot.log" || echo "bot did not finish")
echo "bot: $bot"
grep -q "TESTS DONE pass=1 fail=0" "$OUT/bot.log" || fail=1

if command -v xvfb-run > /dev/null; then
  mkdir -p "$OUT/shots"
  LIBGL_ALWAYS_SOFTWARE=1 timeout 300 xvfb-run -a -s "-screen 0 1280x720x24" "$G" --path "$ROOT/game" \
    --rendering-driver opengl3 --resolution 1280x720 -- --test=titlecap --shots="$OUT/shots" --mute \
    > "$OUT/render.log" 2>&1 < /dev/null
  [ -f "$OUT/shots/03_title_3.png" ] && echo "rendered: $OUT/shots/03_title_3.png" || { echo "rendered title missing"; fail=1; }
fi

[ $fail -eq 0 ] && echo "SMOKE PASS" || echo "SMOKE FAIL"
exit $fail
