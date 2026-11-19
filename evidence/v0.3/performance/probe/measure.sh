#!/usr/bin/env bash
# macOS arm64, Xcode Command Line Tools, Godot 4.7.2, Git and SCons (or uvx).
# Usage: ./evidence/v0.3/performance/probe/measure.sh /path/for/results
set -euo pipefail
out=${1:?Provide a directory for the two logs and replay screenshots}
mkdir -p "$out"
out=$(cd "$out" && pwd)
source_dir=$(cd "$(dirname "$0")" && pwd)
repo=$(git -C "$source_dir" rev-parse --show-toplevel)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/taoist-frame-probe.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
engine=${GODOT:-godot}

mkdir -p "$scratch/game/perf_probe"
rsync -a "$repo/game/" "$scratch/game/"
git init -q "$scratch/godot-cpp"
git -C "$scratch/godot-cpp" fetch --quiet --depth 1 https://github.com/godotengine/godot-cpp.git 27d9dd23c83871e0619fca5dc2cddfbfd69e926a
git -C "$scratch/godot-cpp" checkout --quiet --detach FETCH_HEAD
cp "$source_dir/build-profile.json" "$scratch/profile.json"
if command -v scons >/dev/null; then
    builder=(scons)
else
    builder=(uvx --from scons scons)
fi
"${builder[@]}" -C "$scratch/godot-cpp" -j3 platform=macos arch=arm64 target=template_debug build_profile=../profile.json
cpp="$scratch/godot-cpp"
clang++ -std=c++17 -dynamiclib -O2 -DDEBUG_ENABLED -DTHREADS_ENABLED -DHOT_RELOAD_ENABLED -DMACOS_ENABLED -DUNIX_ENABLED \
  -I"$cpp/include" -I"$cpp/gen/include" -I"$cpp/gdextension" "$source_dir/gpu_probe.cpp" \
  "$cpp/bin/libgodot-cpp.macos.template_debug.arm64.a" -framework OpenGL -framework Foundation \
  -o "$scratch/game/perf_probe/taoist_gpu_probe.dylib"
cp "$source_dir/monitor.gd" "$source_dir/probe.gdextension" "$scratch/game/perf_probe/"
python3 - "$scratch/game/project.godot" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
sfx = 'Sfx="*res://scripts/core/sfx.gd"'
settings = path.read_text()
if settings.count(sfx) != 1:
    raise SystemExit("Cannot locate the Sfx autoload in the copied game.")
path.write_text(settings.replace(sfx, sfx + '\nFrameTimer="*res://perf_probe/monitor.gd"'))
PY
"$engine" --headless --path "$scratch/game" --import > "$out/import.log" 2>&1
for scene in wave elite; do
    log="$out/gl-$scene.log"
    "$engine" --path "$scratch/game" --max-fps 60 --rendering-method gl_compatibility --rendering-driver opengl3 \
      --resolution 1280x720 --position 80,80 --single-window -- --test=visual_replay --scene="$scene" \
      --measure --qa-gl-timer --difficulty=1 --qa-settings="$scratch/settings.cfg" --evidence="$out" > "$log" 2>&1
    grep '^REPLAY_END' "$log"
    grep -E '^GPU_NATIVE_SUMMARY samples=[1-9][0-9]* .*p99=' "$log"
done
