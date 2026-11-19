# Developer Handoff — Taoist Wanderer (道行者) v0.3.1

This is the English entry point for a developer taking over the project. The design documents in `docs/` and most status notes are in Chinese; this file summarises what you need to build, test and continue the game.

| | |
| --- | --- |
| Version | **0.3.1** — pre-release, not a stable build |
| Source branch | [`claude/post-codex-continuation`](https://github.com/lsaac1208/mtdm/tree/claude/post-codex-continuation) |
| Release | [v0.3.1 pre-release](https://github.com/lsaac1208/mtdm/releases/tag/v0.3.1) (three platform ZIPs, source archive, `SHA256SUMS`, `MANIFEST.json`) |
| Based on | `codex/visual-polish-v03` @ `451d4d3` (Codex visual pass). `v0.3.0-rc.1` was built from the earlier `93cee6d`. |
| Engine | Godot **4.7.2.stable.official.ed1daf0bf** (standard, non-.NET) |
| Change log | [CHANGELOG.md](CHANGELOG.md) |
| Evidence for 0.3.1 | [evidence/v0.3.1/README.md](evidence/v0.3.1/README.md) (same-harness before/after screenshots against `451d4d3`) |

`main` has not been merged into or modified. The branches `codex/visual-polish-v03` and `dev/vertical-slice-20261118`, and the tags `v0.2.0` and `v0.3.0-rc.1`, are preserved as they were.

## 1. Repository layout

| Path | Contents |
| --- | --- |
| `game/` | Godot project. Open `game/project.godot`. |
| `game/scripts/actors/` | `player.gd` (combat state machine), `rig_visual.gd` (selects the visual layer), `frame_anim.gd` (frame-by-frame sheets with 2.5D normal maps), `pose_sprite.gd` (painted key poses), `cutout_rig.gd` (fallback) |
| `game/scripts/enemies/` | `enemy.gd` base, plus `grunt`, `crawler`, `husk`, `spitter` and `elite` |
| `game/scripts/level/` | Route data, level builder, camera, encounters, barriers, end gate, painted route |
| `game/scripts/ui/` | Title, HUD, pause, options, ending; `ink_theme.gd` holds the shared UI skin |
| `game/shaders/` | `ink_sprite.gdshader` (2.5D character lighting), atmosphere, soil |
| `game/assets/anims/<actor>/` | Frame sheets plus `*_n.png` normal/thickness/AO maps and `anims.json` |
| `game/tests/test_runner.gd` | All automated checks, the playthrough bot and the screenshot capture modes |
| `tools/art/build_anim_sheets.py` | Slices `tools/art/anim_sheets/*.png` into runtime frames and bakes the normal maps |
| `tools/build/package.py` | Exports and zips the Linux, Windows and macOS builds |
| `tools/qa/` | `native_release.py` (package smoke test on its target OS), `review_media.py`, `smoke.sh` (one-command local verification) |
| `tools/acceptance.sh` | Older full acceptance gate (v0.2). It still works but takes about 25 minutes. |
| `evidence/` | Test logs, screenshots and comparison sheets for each version |
| `docs/`, `concept_art/`, `raw_chat/` | The original design specs, concept sheets and design conversation (Chinese) |

### Character rendering model (read this before touching the visuals)

`RigVisual` chooses one of three layers for every state:

1. **`FrameAnim`** handles run, walk, jump, fall, land, relaxed idle, block, hit and death for the hero, plus the locomotion and core poses of every enemy. These are painted sheets, lit with baked normal, thickness and AO maps.
2. **`PoseSprite`** draws painted key poses for attacks and skills (load, strike, settle). The 2.5D shader lights them the same way as the frame sheets.
3. **`CutoutRig`** draws skinned cut-outs. It is used only when a clip has no frame sheet.

The relaxed idle sheet is drawn three-quarter front. Every other hero drawing is in profile. So during combat the hero holds the profile guard pose (`hero_strike_settle`) instead of the relaxed idle (`Player.guard_t`, DECISIONS D22).

## 2. Setup — exact versions used for 0.3.1

| Tool | Version | Needed for |
| --- | --- | --- |
| Godot | 4.7.2.stable.official.ed1daf0bf, Linux x86_64 binary SHA-256 `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e` | Everything |
| Godot export templates | 4.7.2.stable | Exports |
| Python | 3.13.5 | Packaging and QA scripts |
| Pillow / numpy | 13.0.0 / 2.5.5 | Contact sheets and media review |
| scipy / opencv-python / fonttools | 1.18.1 / 5.1.0 / 4.68.0 | Regenerating art and fonts only |
| FFmpeg | 7.1.5 | Recording review videos only |
| Xvfb + Mesa llvmpipe | xvfb 21.1.16, Mesa 25.0.7 | Rendered runs on a headless Linux box |
| OS used for verification | Debian GNU/Linux 13 (trixie), x86_64, no GPU | — |

Install the templates into `~/.local/share/godot/export_templates/4.7.2.stable/`. Do **not** override `XDG_DATA_HOME` when exporting, or Godot will not find them.

## 3. Build, run and test

```bash
git clone https://github.com/lsaac1208/mtdm.git && cd mtdm
git switch claude/post-codex-continuation
export GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64

$GODOT --headless --path game --import         # first time only
$GODOT --path game                              # play

tools/qa/smoke.sh                               # import + 54 checks + bot run (+ rendered title shot if xvfb-run exists)
$GODOT --headless --path game -- --test=all --nohitstop --mute                 # 54 engine checks
$GODOT --headless --fixed-fps 60 --path game -- --test=bot --mute              # input-only bot plays the whole route
$GODOT --headless --fixed-fps 60 --path game -- --test=bot --bot_skill=human --mute   # bot with reaction delay
GODOT=$GODOT python3 tools/build/package.py 0.3.1                              # build/TaoistWanderer-v0.3.1-*.zip
python3 tools/qa/native_release.py build/TaoistWanderer-v0.3.1-linux-x86_64.zip build/qa/native-linux
```

The rendered screenshot modes need a display or `xvfb-run`. Launch the game with `--rendering-driver opengl3 --resolution 1280x720 --fixed-fps 60`, then add `-- --test=<mode> --shots=<dir> --mute`. The available modes are `titlecap`, `showcase`, `gatecap`, `sealcap`, `platcap`, `combocap`, `elitecap`, `runcap`, `pausecap`, `optcap` and `ending_shot`. To record a full playthrough, add `--write-movie out.avi -- --test=bot`.

To compare against another commit, check that commit out in a `git worktree`, copy the current `game/tests/test_runner.gd` into it, and run the same capture modes. This is how `evidence/v0.3.1/comparison.jpg` was made.

## 4. Status of 0.3.1 — verified vs. pending

All automated results below come from software rendering (Mesa llvmpipe under Xvfb) on one Linux machine. **They are not human approval of feel, art or audio.**

| Area | Status |
| --- | --- |
| Engine checks (`--test=all`) | 54/54 pass, both from source and inside the exported Linux build |
| Full route (playthrough bot) | Cleared from source in several runs at both perfect and human-like skill, 0–1 deaths. Also cleared inside the exported Linux build. |
| Rendered review | A full software-rendered playthrough was recorded and reviewed frame by frame for all five zones and the elite. Before/after screenshots against `451d4d3` were taken with the same capture harness. |
| Linux package (`native_release.py`, Xvfb) | The archive, engine checks, Normal route and soak all pass. The `title` and `village` steps are flagged only because the test container has no audio device (Godot logs an ALSA `ERROR` and falls back to the dummy driver). Their screenshots render correctly. |
| **Windows package** | Built. **Not run on Windows — pending.** |
| **macOS package** | Built (universal, ad-hoc signed, not notarized). **Not run on a Mac — pending.** |
| **Human playtest** | **Pending.** Use `evidence/v0.3/PLAYTEST.md`. |
| **Physical gamepad** | **Pending.** Bindings are tested only with injected joypad events. |
| **Audio listening** | **Pending.** Audio has only been checked numerically (levels and clipping). |
| **Real-GPU performance** | **Pending** for 0.3.1. Software-rendered movie writer averages were 9.9 ms CPU and 10.6 ms GPU per frame. That is not a real-GPU figure. |

## 5. Known issues and next tasks

- After a fight ends, the hero still switches in a single frame from the profile guard to the three-quarter relaxed idle. Within combat this no longer happens.
- Attacks are painted key poses (load → strike → settle) with slash effects, not full frame-by-frame swings.
- The HUD bars and skill icons could use more size and spacing work.
- An enemy pinned against a platform cannot be pushed away, so the two figures can still overlap there.
- The v0.2.0 acceptance logs (`evidence/acceptance-20261119/*.log`) contain the build machine's sandbox path `/workspace/mtdm`. They were left unchanged, as history.
- The CI workflow `.github/workflows/native-release.yml` runs automatically when a `v0.3.*` tag is pushed. Whether it ran for v0.3.1 is recorded on the release page and in `CHANGELOG.md`. It is not part of the verification claimed here.

See `ROADMAP.md` (Chinese) for the prioritised list and `DECISIONS.md` (D1–D24, English) for the architecture decisions.

## 6. Release assets

The release assets are the three platform ZIPs, `mtdm-v0.3.1-source.zip`, `SHA256SUMS` and `MANIFEST.json`. The source archive is a `git archive` of the tagged commit. `MANIFEST.json` lists each asset's size and SHA-256 and the verification status per platform. Large binaries (built ZIPs, videos) live only on Releases, never in Git (`build/` is ignored).
