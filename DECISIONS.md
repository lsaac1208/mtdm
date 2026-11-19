# DECISIONS — 道行者 / Taoist Wanderer vertical slice

Significant technical and production decisions, newest last. Each entry: decision, why, consequences.

## D1 · Engine: Godot 4.7.2 (GL Compatibility renderer)
- **Why:** 2D side-scroller; the handoff docs already assume Godot-style 2D workflows (`Skeleton2D` mentioned in docs/03); free, scriptable headless runs for tests; exports Linux/Windows from this box.
- **Compatibility renderer** so the game runs on low-end GPUs and on this box's software GL (llvmpipe) for screenshots.
- Project lives in `game/` so the original handoff material at the repo root stays untouched.

## D2 · Code-built scenes, data in GDScript constants
- Scenes (`scenes/*.tscn`) are one-node shells; everything else is built in code from `LevelData` and per-class tables.
- **Why:** reviewable diffs, no editor needed, fast iteration from the terminal. Tuning lives in obvious places: `player.gd` `ATK` table, enemy `_init()` stats, `level_data.gd` route.

## D3 · Combat = axis-aligned rects with a feet origin (not physics areas)
- Every actor's origin is bottom-centre (spec docs/05 §2.1). Hurtbox = `Rect2(x - w/2, y - h, w, h)`. Attacks are forward-facing local rects converted per facing.
- **The high/low rule is literal geometry**: horizontal slash covers 55–145 px above the feet; the crawler hurtbox is 46 px tall, so it whiffs with no special-case code. Down slash / dash slash / jump attack reach 0 px. Verified by `tests/test_runner.gd` (`hslash_whiffs_crawler`, `downslash_hits_crawler`).
- One resolver (`scripts/core/combat.gd`) handles melee, projectiles, AOE and hazards; a per-swing `hit_set` prevents multi-hits.
- Dimensions/speeds follow the spec table (player 44×138, 260/520 px/s; grunt 46×124; crawler 92×46; husk 50×138; spitter 52×130; elite 72×172).

## D4 · Art: key-pose cut-outs from the concept sheets + procedural motion
- The repository has concept sheets, not animation-ready assets. `tools/art/extract.py` segments individual poses off the parchment (colour/lightness mask → line removal → small-hole fill → largest components) and writes transparent PNGs with a foot anchor and a per-row scale so every character lands at its spec height (hero 150 px, elite ~180 px, crawler ~50 px).
- 50 sprites: the hero's 13 combat poses (sheet 02) + 4 effect icons, and 4–8 key poses per enemy (sheets 06–10).
- **Animation = pose switching + procedural layer**: short cross-fades, lean/squash/bob transforms, and `shaders/ink_sprite.gdshader` (hem flutter, lower-body stride shear, breathing, hit flash, ink-burn death dissolve).
- **Trade-off (documented limitation):** there are no frame-by-frame walk cycles; locomotion is a single pose with stride shear and bob. This preserves the exact concept-art look but reads as "puppet" motion. The production fix is real sequences or Spine/Skeleton2D cut-outs (crawler sheet 08 already defines the 10-part split).
- The concept sheets themselves are never shown as gameplay characters.

## D5 · Undead Warrior Elite visuals from the faction sheet (V1.0 design)
- Only sheet 06 contains the elite (main model, idle, heavy attack). The V1.1 corrected sheet (docs/04) has not been produced yet. The demo uses the V1.0 images; mechanics follow the spec (super armour, 0.65–0.85 s wind-ups, chop + ground shock, wide sweep, recovery windows).

## D6 · Environment art is procedurally generated ink-wash
- No environment paintings exist (Batch 3 is future work). `tools/art/make_env.py` generates parchment sky, three parallax ruin/mountain layers, foreground weeds, ground, ~15 props and the title/ending backdrops in the art-bible palette with rough ink outlines and dry-brush grain. Zones re-tint the layers + fog (`shaders/atmosphere.gdshader`).
- Replaceable: drop painted PNGs with the same names into `game/assets/env/`.

## D7 · Audio is synthesized offline (no third-party audio)
- `tools/audio/make_audio.py`: ~50 SFX (filtered noise, modal metal, Karplus-Strong plucks) and four 48 s pentatonic guqin-style loops + wind ambience. Licence-clean, reproducible.
- **Not yet auditioned by a human** (the build box has no audio device). Levels were checked numerically only.

## D8 · Fonts bundled and subset (OFL)
- Ma Shan Zheng (brush titles) and Noto Serif CJK SC Bold (UI), both SIL OFL 1.1, subset to ASCII + GB2312 level-1 + every character used in game scripts (`tools/build/make_fonts.py`). Avoids tofu on machines without CJK fonts.

## D9 · Combo and control mapping
- Spec FSM (docs/05 §2.3-A) combo order kept: 拔剑→横斩 (1) → 下劈 (2) → 突刺 (3). `S+J` starts directly with the down slash. Mashing therefore reaches the low hit on step 2; the crawler still punishes the whiffed first slash, which is the Group A lesson.
- Keys: A/D move, K/Space jump, J attack, L/Shift dash, I block (parry window 0.17 s), U talisman, O gourd, P prayer beads, Esc pause. Gamepad mapped in `game.gd`.
- Resource: 道力 (Qi) 0–100 — gained by hits (+5), parries (+15), kills (+8), slow regen; talisman 20, beads 50. Gourd: 3 charges, refilled at campfires (heal 35 + knock-back gust).

## D10 · Enemy rules chosen where the spec leaves room
- Grunt/crawler: max poise ≤ 10 ⇒ every hit staggers ("普攻即硬直").
- Husk: poise 60 so one full 3-hit combo does not stagger it; seal pressure +1 per *melee* hit (decays after 2.4 s); at 4 → 0.5 s telegraph → unblockable 110 px burst. Talismans do not add pressure (ranged is the intended answer).
- Spitter: wind-up 0.9 s is cancelled only by single hits with poise ≥ 12 (down slash, thrust, dash slash, talisman); light slash (8) does not.
- Elite: poise meter 110 (regenerates after 2.5 s without hits); parry = −45; break ⇒ 1.8 s kneel with +50 % damage taken. Phase 2 at 50 % HP: faster wind-ups, chop→sweep chains, one 2-grunt summon (Group D "1–2 grunts").

## D11 · Testing approach
- `tests/test_runner.gd` runs inside the real game (`--test=all`) and drives the player through `input_override` (one-shot presses consumed by exactly one physics step).
- `--test=bot` is a scripted player that clears the whole route; with `--fixed-fps 60` it runs ~30× faster than real time headless.
- `--test=showcase` / `--shots` produce rendered captures under Xvfb for visual review.
- GitHub CI is deliberately not required (per project directive).

## D12 · Scope of the slice
- One continuous level, 5 zones (荒村废墟 → 道路边缘 → 低洼污染区 → 废弃道观 → 乱葬岗), 4 campfires, 8 encounters using Groups A–D, elite finale, ending screen. No pits/falling deaths, no save files (a run is short; campfire progress persists within a run).

## D13 · Shader leg rig instead of new art (session 2)
- No new frames can be painted here, so locomotion is produced from the existing pose by an inverse-mapped two-bone leg rig in `ink_sprite.gdshader`: per pose the foot anchor gives the split line and the hip/knee heights come from `hip_frac`; front leg composited over back; pixels outside the leg bands (hanging sword, robe edges) stay rigid; the body drops by `L·(1−cos θ)` so feet stay planted. A `tuck` mode bends both knees for airborne frames.
- Sampling goes through an explicit `src_tex` uniform (passing `TEXTURE` into helper functions errors on the dummy renderer).

## D14 · Mix safety
- Master bus gets a compressor (−12 dB, 3:1) and hard limiter (−1 dB); SFX play 3 dB under their nominal level. Verified from a movie-writer recording.

## D15 · Arm bones from per-pose annotations (session 3)
- `game/assets/sprites/rig.json` lists, per pose, up to two arm bones in sprite UV: shoulder `s`, hand `h`, optional tool tip `t`, half-widths `w`/`tw`. The shader rotates each capsule about the shoulder; vacated pixels are inpainted by probing perpendicular to the bone (both sides inside the body → fill, otherwise leave transparent).
- Bone 0 is the weapon arm; gameplay code drives `vis.arm_rot`/`arm_off`. Attacks carry an `arm` curve `[wind-up, strike, off0, off1]` in the player `ATK` table; enemies call `swing_arm()`.
- Outline/halo now take 8 rig samples instead of 14 — the outline was the dominant cost (measured 63 vs 47 FPS on llvmpipe).

## D16 · Acceptance is a script, evidence is committed
- `tools/acceptance.sh` is the release gate: engine tests, 6 bot runs (perfect + human-like), export + package, the same tests and a bot inside the exported binary, rendered captures, FPS log. It writes `evidence/acceptance-<date>/REPORT.md` with compact JPG frames (≈2 MB) so claims in DEVELOPMENT_STATUS are traceable to logs in git.
- `package.py` deletes old binaries before exporting so a failed export can never be verified as stale.

## D17 · Real cut-out rigs from single concept poses (v0.2.0, M7)
- `tools/rig/make_rig.py` + `tools/rig/<char>_rig_def.py` (bones + part polygons in source pixels): pixels are assigned to parts; what each part hides is reconstructed (row-span inpaint under arms, synthesized trouser fabric under the skirt); each part gets a grid mesh with inverse-distance bone weights (per-part sharpness; smooth skirt/thigh coupling).
- Runtime: `CutoutRig` (CanvasGroup) → `Skeleton2D`/`Bone2D` + skinned `Polygon2D` parts; clips are keyframe tables (`HeroClips`, `EnemyClips`) compiled into `Animation` resources for an `AnimationPlayer` (manual advance, crossfade blending); spring bones for ribbon/robe panels; the group shader draws the ink contour/flash/burn on the composited figure.
- Why not new frames: no artist and no image-generation tool here; the rig keeps the exact concept-art look and gives continuous motion. Limits: one view per character, no hand articulation.

## D18 · Hybrid: rig in-betweens, painted contact frames
- `RigVisual` keeps the painted action poses (sheet 02, 06–10) as attack contact frames (35 ms cut) and uses the rig for anticipation, recovery, locomotion and reactions. `pose_map` routes existing AI `set_pose()` calls to clips; walk vs idle is chosen from actual speed and the cycle rate is scaled to ground speed.

## D19 · Balance by telemetry + fairness gates (M6)
- Every run records damage per attack source, death causes and per-encounter stats (`Game.telemetry`, printed by the bot). Tuning is justified in `docs/BALANCE.md`; boss heavies must be avoidable by their documented answer within a measured input window (`elite_fairness`).

## D20 · Audio normalized by category (M8)
- `save()` in the generator normalizes each file to a per-category loudest-400 ms RMS target and soft-limits to −1 dBFS; loops get no edge fades and a seam crossfade. `tools/audio/audio_review.py` is the gate (0 flagged). Music and SFX are separate buses (options menu).

## D21 · macOS export without Apple credentials (M10)
- Universal `.app`, ad-hoc signed by Godot's built-in signer; needs ETC2/ASTC import enabled. Not notarized → Gatekeeper requires right-click → Open. Not run on a Mac.

## D22 · Combat guard instead of relaxed idle between strikes (0.3.1)
- The relaxed idle sheet is drawn three-quarter front while every other hero drawing is in profile. `Player.guard_t` keeps the painted profile guard (`hero_strike_settle`) for 2.6 s after any combat action or while an aggro enemy is within 430 px; the relaxed idle only plays out of combat. Covered by `guard_stance`.

## D23 · One UI theme (0.3.1)
- `InkTheme.shared()` (code-built `Theme`) is set on the root window and on the pause/options roots (CanvasLayer children do not inherit the window theme). Screens keep their own font sizes/colours; only widget skins come from the theme.

## D24 · Enemy personal space (0.3.1)
- Upright enemies (hurtbox height ≥ 100) yield to the hero in neutral states only (chase/alert/idle/wander/detect/recover/stagger/retreat), to (hurt widths)·0.42 apart; never during the hero's dash/dash-attack or when heights differ (airborne), and never during enemy wind-ups/attacks. Attack timing windows are unchanged (`elite_fairness` passes). Crawlers are exempt (designed to be jumped over).
