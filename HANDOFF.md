# Developer Handoff — Taoist Wanderer (道行者) v0.4.0

This is the English entry point for a developer taking over the project. The design documents in `docs/` and most status notes are in Chinese; this file summarises what you need to build, test and continue the game.

| | |
| --- | --- |
| Version | **0.4.0** — pre-commercial prologue demo candidate |
| Source branch | `codex/demo-v0.4.0` (branched from `origin/claude/post-codex-continuation` @ `8eb690d`) |
| Release | [v0.4.0 pre-release](https://github.com/lsaac1208/mtdm/releases/tag/v0.4.0) |
| Previous release | [v0.3.1 pre-release](https://github.com/lsaac1208/mtdm/releases/tag/v0.3.1) |
| Based on | `claude/post-codex-continuation` @ `8eb690d` (`v0.3.1`), which built on `codex/visual-polish-v03` @ `451d4d3`. |
| Engine | Godot **4.7.2.stable.official.ed1daf0bf** (standard, non-.NET) |
| Change log | [CHANGELOG.md](CHANGELOG.md) |
| Evidence for 0.4.0 | [evidence/v0.4.0/README.md](evidence/v0.4.0/README.md) (Metal GPU captures, 5-zone readability, real-GPU perf & native macOS `.app` verification) |

`main` remains the lightweight design-pack homepage branch (its `README.md` top banner points here; game binaries/assets are not merged into `main`). The branches `claude/post-codex-continuation`, `codex/visual-polish-v03`, and `dev/vertical-slice-20261118`, and tags `v0.2.0`, `v0.3.0-rc.1`, and `v0.3.1`, are preserved intact.

## 1. Repository layout

| Path | Contents |
| --- | --- |
| `game/` | Godot project. Open `game/project.godot`. |
| `game/scripts/actors/` | `player.gd` (combat state machine), `rig_visual.gd` (selects the visual layer), `frame_anim.gd` (frame-by-frame sheets with 2.5D normal maps), `pose_sprite.gd` (painted key poses), `cutout_rig.gd` (fallback) |
| `game/scripts/enemies/` | `enemy.gd` base, plus `grunt`, `crawler`, `husk`, `spitter` and `elite` |
| `game/scripts/level/` | Route data, level builder, camera, encounters, barriers, painted stone Pailou end gate, checkpoints, `destructible.gd` + `spirit_wisp.gd`, painted route + foreground parallax |
| `game/scripts/ui/` | `title.gd`, `prologue.gd` (skippable 3-plate ink-scroll intro), `hud.gd` (6-mood portraits + non-blocking whispers), `pause_menu.gd`, `options_menu.gd`, `ending.gd` (Journey Ledger + Seal Rank); `ink_theme.gd` holds the shared UI skin |
| `game/shaders/` | `ink_sprite.gdshader` (2.5D character lighting), atmosphere, soil |
| `game/assets/anims/<actor>/` | Frame sheets plus `*_n.png` normal/thickness/AO maps and `anims.json` |
| `game/tests/test_runner.gd` | All automated checks, the playthrough bot and the screenshot capture modes |
| `tools/art/build_anim_sheets.py` | Slices `tools/art/anim_sheets/*.png` into runtime frames and bakes the normal maps |
| `tools/art/extract_portraits.py` | Extracts 6 expression bust portraits (`portrait*.png`) and 3 prologue ink plates (`prologue_01..03.webp`) from `concept_art/` |
| `tools/build/package.py` | Exports and zips the Linux, Windows and macOS builds |
| `tools/qa/` | `native_release.py` (package smoke test on its target OS), `review_media.py`, `smoke.sh` (one-command local verification) |
| `tools/acceptance.sh` | Older full acceptance gate (v0.2). It still works but takes about 25 minutes. |
| `evidence/` | Test logs, screenshots and comparison sheets for each version |
| `docs/`, `concept_art/`, `raw_chat/` | The original design specs, concept sheets and design conversation (Chinese) |

### Character rendering model (read this before touching the visuals)

`RigVisual` chooses one of three layers for every state:

1. **`FrameAnim`** handles **all 21 hero clips** — locomotion (`run`, `walk`, `jump`, `fall`, `land`, `idle`), combat stances (`guard_idle`, `guard_to_idle`, `block`, `hit`, `dead`), full frame-by-frame sword attacks (`slash1`, `slash2`, `slash3`, `dash`, `dash_attack`, `jump_attack`), and skills (`talisman`, `gourd`, `beads_a`, `beads_b`) — plus **all 41 enemy clips** across all five archetypes (`grunt` 6, `crawler` 7, `husk` 8, `spitter` 8, `elite` 12). Every frame is lit with baked 2.5D normal, thickness and AO maps (`*_n.png`).
2. **`PoseSprite`** remains as fallback for any actor pose without a `FrameAnim` clip, shaded identically by `ink_sprite.gdshader`.
3. **`CutoutRig`** draws skinned cut-outs only when a clip has neither a frame sheet nor a pose sprite.

The relaxed `idle` sheet is drawn three-quarter front while combat drawings are in profile. During combat the hero holds the animated `guard_idle` profile loop (`Player.guard_t`, DECISIONS D22/D25); once combat ends, `guard_to_idle` (3 frames) smoothly turns and sheathes back into `idle`.

## 2. Setup — exact versions used for 0.4.0

| Tool | Version | Needed for |
| --- | --- | --- |
| Godot | 4.7.2.stable.official.ed1daf0bf (standard, non-.NET) | Everything |
| Godot export templates | 4.7.2.stable | Exports |
| Python | 3.11+ (verified on 3.13) | Packaging, art/audio rebuilds and QA scripts |
| Pillow / numpy | 10+ / 2+ | Contact sheets, readability audit and media review |
| scipy / opencv-python / fonttools | optional | Regenerating art, audio and fonts only |
| FFmpeg | optional | Recording review videos only |
| OS used for 0.4.0 verification | macOS `27.2.1` arm64 (`Apple M6`, Metal `1280×720`) + GitHub Actions CI (`ubuntu-24.04`, `windows-2025`, `macos-15`) | — |

Install the export templates into `~/.local/share/godot/export_templates/4.7.2.stable/` (Linux) or `~/Library/Application Support/Godot/export_templates/4.7.2.stable/` (macOS). Do **not** override `XDG_DATA_HOME` when exporting on Linux, or Godot will not find them.

## 3. Build, run and test

```bash
git clone https://github.com/lsaac1208/mtdm.git && cd mtdm
git switch codex/demo-v0.4.0
export GODOT=/path/to/godot   # Godot 4.7.2.stable

$GODOT --headless --path game --import         # first time only
$GODOT --path game                              # play

tools/qa/smoke.sh                               # import + 63 checks + bot run (+ rendered title shot if xvfb-run exists)
$GODOT --headless --path game -- --test=all --nohitstop --mute                 # 63 engine checks
$GODOT --headless --fixed-fps 60 --path game -- --test=soak --nohitstop --mute # 2-run Normal clear + leak check
$GODOT --headless --fixed-fps 60 --path game -- --test=bot --mute              # input-only bot plays the whole route
$GODOT --headless --fixed-fps 60 --path game -- --test=bot --bot_skill=human --mute   # bot with reaction delay
python3 tools/audio/audio_review.py game/assets/audio /tmp/audio_review        # 75-file audio loudness/seam gate
GODOT=$GODOT python3 tools/build/package.py 0.4.0                              # build/TaoistWanderer-v0.4.0-*.zip
python3 tools/qa/native_release.py build/TaoistWanderer-v0.4.0-macos-universal.zip build/qa/native-mac
```

The rendered screenshot modes need a display or `xvfb-run`. Launch the game with `--rendering-driver opengl3 --resolution 1280x720 --fixed-fps 60`, then add `-- --test=<mode> --shots=<dir> --mute`. The available modes are `titlecap`, `showcase`, `gatecap`, `sealcap`, `platcap`, `combocap`, `elitecap`, `runcap`, `pausecap`, `optcap` and `ending_shot`. To record a full playthrough, add `--write-movie out.avi -- --test=bot`.

To compare against another commit, check that commit out in a `git worktree`, copy the current `game/tests/test_runner.gd` into it, and run the same capture modes. This is how `evidence/v0.3.1/comparison.jpg` was made.

## 4. Status of 0.4.0 — verified vs. pending

Automated source checks, real-GPU captures, and native macOS package checks ran on Apple Silicon (`macOS-27.2.1-arm64`, `Apple M6`, Metal `1280×720`). **Automated verification is not human approval of feel, art or audio.**

| Area | Status |
| --- | --- |
| Engine checks (`--test=all`) | **63/63 pass** with zero script errors/warnings (`spec_conformance` 21/21, `hero_anim_no_pops=12.4 px`, destructibles, diegetic enemy UI, 5-enemy `FrameAnim`, prologue, whispers, rank persistence) |
| Full route & soak (`--test=soak`) | **PASS** 0-death Normal clear (`rank=甲`) and 2-run soak (`nodes 86->86`, `orphans 0->0`) + `hero_footwork.gd` (`floor_gap_px=0.0`) |
| Audio audit (`audio_review.py`) | **75/75 files, 0 flagged** (`44.1 kHz`, 30 stereo / 45 mono, max peak `-1.00 dBFS`, max seam `0.0115`) |
| Five-zone readability (`readcap`) | **15/15 PASS** on real Metal GPU (`evidence/v0.4.0/readability/READABILITY.md`) |
| **Real-GPU performance** | **Verified** on Apple M6 Metal (`1280×720`): `village` `p50=2.38 ms / p99=4.56 ms`; `lowland` `p50=1.91 ms / p99=3.90 ms`; `elite` `p50=2.10 ms / p99=3.80 ms` |
| **macOS package** | **Built & verified on macOS** (`native_release.py` on `TaoistWanderer-v0.4.0-macos-universal.zip`: `ditto` unpack, `codesign --verify --deep --strict`, `engine`, `normal-route`, rendered `title` & `village` all PASS; ad-hoc signed, not notarized) |
| **Windows package** | Built (`build/TaoistWanderer-v0.4.0-windows-x86_64.zip`). **Not run on Windows — pending.** |
| **Linux package** | Built (`build/TaoistWanderer-v0.4.0-linux-x86_64.zip`). **Not run on Linux for v0.4.0 — pending.** |
| **Human playtest** | **Pending.** Use `evidence/v0.3/PLAYTEST.md`. |
| **Physical gamepad** | **Pending.** Bindings are tested only with injected joypad events. |
| **Audio listening** | **Pending.** Audio has only been checked numerically (levels and clipping). |

## 5. Known issues and next tasks

- Windows and Linux v0.4.0 package verification on target OSes.
- Human playtest, physical gamepad testing, and speaker audio audition before public Steam Next Fest / publisher distribution.
- Post-demo commercial roadmap: Chapter 2 route & faction encounters, expanded dialogue/NPC shrines, Apple notarization & Windows Authenticode code signing.
- The v0.2.0 acceptance logs (`evidence/acceptance-20261119/*.log`) contain the build machine's sandbox path `/workspace/mtdm`. They were left unchanged, as history.

See `ROADMAP.md` (Chinese) for the prioritised list and `DECISIONS.md` (D1–D31, English) for the architecture decisions.

## 6. Release assets

The release assets are the three platform ZIPs (`TaoistWanderer-v0.4.0-{macos-universal,windows-x86_64,linux-x86_64}.zip`), `mtdm-v0.4.0-source.zip`, `SHA256SUMS` and `MANIFEST.json`. The source archive is a `git archive` of the tagged `v0.4.0` commit. `MANIFEST.json` lists each asset's size and SHA-256 and the verification status per platform. Large binaries (built ZIPs, videos) live only on Releases, never in Git (`build/` is ignored).
