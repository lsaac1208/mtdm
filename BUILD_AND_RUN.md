# BUILD_AND_RUN — 道行者 / Taoist Wanderer

## 0.3 release verification

The three ZIPs come from one game-source commit. Run the native smoke suite on the corresponding OS after exporting. It extracts the archive into a temporary directory, starts its executable, runs the engine checks and a Normal route, and captures the actual title and village viewport. On macOS it opens the extracted app bundle through Launch Services for the title check. The suite passes an isolated settings file to each launch.

```sh
python3 tools/build/package.py 0.3.0
python3 tools/qa/native_release.py build/TaoistWanderer-v0.3.0-macos-universal.zip build/qa/native-mac
```

For reproducible visual review, import the project first, then run the following with a display. Choose `village`, `lowland`, or `elite`. Normal gameplay HUD and sound remain enabled in the movies. Compare two recording directories with `tools/qa/review_media.py compare BEFORE AFTER village village.mp4`. The export ZIP contains the same game and test entry points. Pin Godot 4.7.2, FFmpeg with libx264, and Python with Pillow and NumPy for media review.

```sh
godot --headless --path game --import
python3 tools/qa/review_media.py record game village build/replay evidence/v0.3/after
godot --path game --resolution 1280x720 --fixed-fps 60 -- --test=readcap --shots="$PWD/build/qa/masks" --mute
python3 tools/readability.py build/qa/masks build/qa/readability
```


## 1. Requirements
- **Godot 4.7.2 stable** (standard build, not .NET). Download: https://godotengine.org/download/archive/4.7.2-stable/
- For exports: the matching **export templates** (Editor → Manage Export Templates, or unpack `Godot_v4.7.2-stable_export_templates.tpz` into `~/.local/share/godot/export_templates/4.7.2.stable/`).
- Optional, only to regenerate assets: Python 3.11+ with `numpy pillow scipy opencv-python-headless fonttools`.

## 2. Play from source
```bash
git clone https://github.com/lsaac1208/mtdm.git
cd mtdm && git switch codex/visual-polish-v03
godot --path game            # or open game/project.godot in the editor and press F5
```
The first launch imports assets (~10 s).

### Controls
| Action | Keyboard | Gamepad |
|---|---|---|
| Move | A / D (← →) | Left stick / D-pad |
| Jump (hold = higher) | K / Space | A |
| Attack (3-hit: 横斩→下劈→突刺) | J | X |
| Down slash (hits crawlers) | S + J | Down + X |
| Dash (i-frames) / dash slash | L / Shift, then J | B / RB |
| Block (hold) / parry (tap on impact) | I | LB |
| Talisman 符箓 (20 Qi) | U | Y |
| Yin-Yang gourd 葫芦 (heal + push) | O | LT |
| Prayer beads 念珠 (50 Qi AOE) | P | RT |
| Pause | Esc | Start |
| Fullscreen | F11 / Alt+Enter | — |

## 3. Tests (headless, no window)
```bash
G=godot   # path to the 4.7.2 binary
# Engine-level gameplay checks (~2 min)
$G --headless --path game -- --test=all --nohitstop --mute
# input-driven bot plays the full route to the ending (~30 s with fixed fps)
$G --headless --fixed-fps 60 --path game -- --test=bot --mute
```
Exit code 0 = all passed. Each check prints `TEST <name> PASS|FAIL <detail>`; the bot prints `BOT ...` progress lines and `DEMO_COMPLETE ...`.

Single checks: `--test=movement | crawler_bands | grunt_hit_and_stagger | parry | husk_backlash | spitter_puddle | elite_telegraph | death_respawn | encounter_lock | full_route`.

### Rendered captures (needs a display; on a headless Linux box use Xvfb)
```bash
xvfb-run -a -s "-screen 0 1280x720x24" $G --path game --rendering-driver opengl3 --resolution 1280x720 \
  -- --test=showcase --shots=/tmp/tw_shots --nohitstop --noshake
# or a bot playthrough with a frame every 4 simulated seconds:
xvfb-run -a -s "-screen 0 1280x720x24" $G --fixed-fps 60 --path game --rendering-driver opengl3 \
  -- --test=bot --shots=/tmp/tw_bot --shot_every=4 --mute
```
Other dev flags (after `--`): `--autostart` (skip title), `--startx=<px> [--skip_cleared]` (spawn further along the route), `--shots=<dir> --shot_times=1,2.5`, `--quit_after=<s>`, `--nohitstop`, `--noshake`, `--mute`.

## 3b. Full acceptance run (release gate)
```bash
GODOT=$G PYTHON=python3 tools/acceptance.sh 0.3.0   # ~25 min; exit 0 = all gates passed
```
Needs Pillow for the contact sheet and `xvfb-run` for rendered frames (skipped otherwise). Do not override `XDG_DATA_HOME` when running it — Godot looks for export templates there.

Extra single checks: `elite_fairness`, `boss_music`, `options`, `spec`, `anim_continuity`, `enemy_ledge`, `spawn_surface`, `gamepad_map`, `flow`. Capture modes (Xvfb): `rigcap` (`--clips=run:8,idle:2`, `--tintparts`), `deathcap`, `optcap`, `readcap`, `showcase`, `combocap`, `chopcap`, `crawlcap`, `walkcap`, `runcap`, `jumpcap`, `pausecap`, `ending_shot`.

## 4. Export
```bash
mkdir -p build/linux build/windows
$G --headless --path game --export-release "Linux" ../build/linux/TaoistWanderer.x86_64
$G --headless --path game --export-release "Windows" ../build/windows/TaoistWanderer.exe
```
One command does both exports and the zips (with `RELEASE_NOTES.md` as the player README):
```bash
GODOT=$G python3 tools/build/package.py 0.3.0   # -> build/TaoistWanderer-v0.3.0-*.zip
```
Both presets embed the PCK (single file). Run the Linux build with `./build/linux/TaoistWanderer.x86_64`. The exported binary accepts the same test flags, e.g. `./TaoistWanderer.x86_64 --headless --fixed-fps 60 -- --test=bot --mute`.

## 4b. macOS (from Linux, no Apple account)
The `macOS` preset exports a universal (x86_64 + arm64) `.app`, ad-hoc signed by Godot's built-in signer, not notarized. Requires `rendering/textures/vram_compression/import_etc2_astc=true` (set). `tools/build/package.py` builds it alongside Linux/Windows. Users must right-click → Open the first time (Gatekeeper). A Developer ID + notarization is needed for a frictionless install — not available here.

## 5. Regenerating assets (optional)
```bash
PY="python3 -I"
$PY tools/art/extract.py tools/art/sprites.json game/assets/sprites   # pose cut-outs from concept_art/
$PY tools/art/make_env.py game/assets/env                             # ink-wash backgrounds, props, title/ending, portrait
$PY tools/audio/make_audio.py game/assets/audio                       # SFX + music
$PY tools/build/make_fonts.py game/assets/fonts
# cut-out rigs (parts, meshes, bone weights) from the concept poses
for r in hero elite grunt husk spitter crawler; do $PY tools/rig/make_rig.py tools/rig/${r}_rig_def.py game/assets/rig/$r; done
$PY tools/art/make_env.py game/assets/env zones          # per-zone parallax skylines only
$PY tools/audio/audio_review.py game/assets/audio docs/audio_review   # automated audio review                       # needs Noto Serif CJK + Ma Shan Zheng installed
```
`make_env.py` also writes `title_sky.png` / `ending_sky.png` intermediates; they are not used by the game and can be deleted.

## 6. Balance telemetry
```bash
for i in $(seq 10); do $G --headless --fixed-fps 60 --path game -- --test=bot --mute --nohitstop --bot_skill=human > /tmp/tel_$i.log & done; wait
python3 tools/telemetry_report.py /tmp/tel_*.log    # damage per attack, death causes, per-encounter stats
```
