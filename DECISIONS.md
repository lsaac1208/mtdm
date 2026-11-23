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

## D25 · Full frame-by-frame hero combat & sheathing transition (0.3.2)
- Replaced legacy static key-pose combat swaps (`PoseSprite`) with hand-painted transparent RGBA `FrameAnim` sheets (`hero_guard_idle_sheet.png`, `hero_slash12_sheet.png`, `hero_slash3_dash_sheet.png`, `hero_skills_sheet.png`) and paired baked 2.5D normal/thickness/AO maps (`*_n.png`).
- `FrameAnim.set_frame(clip, index)` lets the combat FSM drive exact frame indices in sync with existing hit windows and slash VFX without altering any attack duration or hitbox.
- `guard_idle` loops continuously during combat; when `guard_t` expires in `idle`, `guard_to_idle` (3 frames, `0.34 s`) bridges cleanly into the three-quarter relaxed `idle`.
- `tools/art/build_anim_sheets.py` strips detached small connected components touching cell borders so adjacent-cell weapon tips cannot bleed across sprite-sheet gutters.

## D26 · Wall-aware mutual personal space (0.3.2)
- Extended D24 with `Enemy._safe_nudge_x`: enemies test horizontal geometry and leash limits before stepping back. When pinned against a solid wall, platform, arena barrier, or leash, the grounded hero absorbs the un-yielded remainder (never during `hit`, `dash`, `dash_attack`, or while airborne). Tested against the solid `x=880` stone wall in `personal_space`.

## D27 · Ink-and-brass HUD & 3-state expression portraits (0.3.2)
- `tools/art/extract_portraits.py` crops three eye-aligned `256×256` RGBA bust portraits (`portrait`, `portrait_combat`, `portrait_hurt`) from `concept_art/03_protagonist_expressions_mood.png` with soft ink-over-parchment unmixing.
- `hud.gd` swaps portraits by live combat/health state inside a double-ring aged-brass medallion, uses cached antialiased `StyleBoxFlat` ink plaques, adds HP damage-lag and Qi threshold pins (`20` / `50`), sets skill icons on warm parchment medallions so dark ink symbols (`icon_beads`) stay legible, and matches the Boss Bar to the same plaque language with a 50% phase marker and recessed poise bar.

## D28 · Painted stone Pailou gate, destructible props & bottom-anchored foreground parallax (0.4.0)
- Replaced the procedural end-gate geometry with a hand-painted weathered Taoist stone Pailou archway (`end_gate_pailou.webp`) backed by volumetric gold god-rays and rising spirit motes once `e8_elite` is cleared.
- Placed 10 painted breakable props (`urn`, `crate`, `brazier` intact/shattered states) in `game/scripts/level/destructible.gd` off all `readcap` camera coordinates; sword swings shatter them and spawn homing `SpiritWisp` pickups that restore Qi, while intact temple/burial braziers emit flickering warm point lights.
- Added 4 dark ink-wash foreground parallax clusters on layer 2 (`1.22x` scroll) strictly anchored in the bottom soil band below screen `y = 550` so combat readability and `readcap` contrast are never occluded.

## D29 · Full 5-enemy multi-frame `FrameAnim` & diegetic combat feedback (0.4.0)
- Extended `tools/art/build_anim_sheets.py` and `game/assets/anims/{grunt,crawler,husk,spitter,elite}/` to cover all 41 enemy combat/reaction states with transparent RGBA frame sequences and baked 2.5D normal/thickness/AO maps (`*_n.png`), routed safely via `Enemy.play_pose_or_clip` with zero changes to hitboxes, hurtboxes, poise, damage, or telegraph windows.
- Added world-space `MiniBar` (HP/poise/burn, hidden at full HP and suppressed for Elite Boss), Husk's 3-hit chest `SealCrackIndicator`, Elite Phase-2 crimson-gold aura & embers, and player parry Bagua burst, `FrameAnim` afterimages, footstep dust, hurt vignette, and gourd heal spiral.

## D30 · Skippable ink-scroll prologue, 6-mood non-blocking whispers & Journey Ledger rank (0.4.0)
- Expanded `tools/art/extract_portraits.py` to all 6 mood busts (`calm`, `alert`, `fierce`, `combat`, `hurt`, `wistful`) and 3 full-bleed ink-scroll prologue plates (`prologue_01..03.webp`).
- Added `game/scenes/prologue.tscn` (`prologue.gd`) on New Game (anytime skippable, auto-bypassed whenever `--test=` is active) and one-shot non-blocking top-right zone/boss whispers in `hud.gd` that never pause or capture input.
- Upgraded Title (Controls overlay + persisted best rank/time badge), Pause, Options, and Ending (`行旅录` Journey Ledger with animated vermilion `甲 / 乙 / 丙` Seal Stamp and persisted best rank in `settings.cfg`).

## D31 · 44.1 kHz stereo audio mastering & automated review gate (0.4.0)
- Upgraded `tools/audio/make_audio.py` and `tools/audio/audio_review.py` to 44.1 kHz across all 75 WAV assets (30 stereo music/ambience/stinger/climax + 45 mono SFX, including 10 new v0.4.0 UI/destructible/ignition/whisper/stamp cues), enforcing `-1.00 dBFS` ceiling, seam continuity (`<= 0.0115`), and stereo correlation checks (`0 flagged`).

## D32 · Input buffer for dash and skills (0.5.0)
- `Player._act_buf` keeps dash/talisman/gourd/beads presses for 0.18 s; `_wants()` replaces `_pressed()` at every decision point and `_start_dash/_start_skill` consume. Air dash gated by `_can_dash()` (one per airtime).

## D33 · Pack queueing and body blocking (0.5.0)
- `Enemy.ally_ahead()` makes chasers hold their slot behind an ally already nearer the hero (crawler, grunt). Same-team separation splits exact ties by instance id and pushes the neighbour when pinned.
- `Enemy.body_space` / `body_block` (elite: 84 px): during wind-up/strike/recovery only the grounded hero is eased out; dash, jump and hit-stun are exempt so `elite_fairness` windows are unchanged.

## D34 · Lore steles and contextual hints (0.5.0)
- `LevelData.LORE` entries (`after` gates a stele behind an encounter). Reading pauses the tree (player-initiated); `LoreReader` handles close in `_input` so Esc doesn't also open the pause menu. Interaction check runs in `_physics_process` because Props tick before Actors (harness one-shot presses).
- Signs declare `learn` actions (+`need`); the HUD shortens the strip once performed and `Game.hints_learned` suppresses repeats.

## D35 · Crawler retreat faces the hero (0.5.0)
- Pre-existing soft-lock: retreat used the stale pre-pounce facing. Retreat now re-faces the hero; recovering crawlers inside 90 px back off.

## D36 · Held-frame life for enemy frame sheets (0.5.0)
- `FrameAnim.hold_life` (set by `RigVisual.hold_life`, enabled in `Enemy._make_visual`) adds motion once a frame has been held > 0.12 s, by clip role: `windup*/prep/alert/awaken/roar` coil (≤3 % squash build over 0.6 s) + tremble (≤1.45 px); `recover*/kneel/hit/recoil/stagger/retreat` heave-breathe; others gentle breathe; `walk/run` untouched. Reset on every frame change. Painted in-betweens remain the long-term fix (needs new art).

## D37 · Difficulty scales rank-and-file telegraphs (0.5.0)
- `Game.DIFF_TELEGRAPH = [1.35, 1.0, 0.88]` via `Game.tele(sec)` for crawler prep (base 0.32 s), grunt wind-up (0.4 s) and spitter wind-up (0.9 s); Story previously only reduced damage. The elite's 0.65–0.85 s windows are spec-locked and not scaled (`elite_windup_readable`). Crawler prep start plays `hiss` (−9 dB) as an audio tell.

## D38 · Adaptive mix on sub-buses (0.5.0)
- `Sfx.MIX_DB` states neutral / explore / combat applied to `MusicDyn` (→ Music) and `AmbDyn` (→ SFX) bus gains, smoothed in `Sfx._process` on unscaled time. `Level._update_mix()` sets combat while an encounter is locked or an aggro enemy is within 600 px; `Level._exit_tree` restores neutral. Chosen over per-player volume offsets because crossfade tweens own player `volume_db`, and over the Music/SFX buses because those belong to the user's sliders.

## D39 · Campfire save, not autosave anywhere (0.6.0)
- The run saves only in `Game.set_checkpoint` (campfire rest), matching the death/respawn model: Continue always resumes at a campfire with full HP/gourd, encounters cleared before it stay cleared. Broken props and lit campfires are not persisted (cosmetic). Tests never touch the player's save unless `--qa-run` is given.

## D40 · Rematch mode is isolated from story progress (0.6.0)
- `Game.mode` ("story" / "rematch"). `start_rematch()` marks every encounter except `e8_elite` cleared and spawns at `REMATCH_CP` (5). In rematch: `save_run()` is a no-op, `finish_demo()` keeps the story save, the ending calls `record_rematch()` (per-difficulty `best_rematch`, persisted under `[progress]`) instead of `record_clear()`. Gated behind `cleared_once` so it reads as a reward.

## D41 · LevelData as an active-chapter facade (0.6.0)
- Route data per chapter lives in `scripts/level/chapters/<id>.gd` (plain consts, same names as before) and is registered in `LevelData.CHAPTERS`. `LevelData` exposes typed `static var`s filled by `use_chapter(id)` (`_static_init` selects `ch1`). Chosen over rewriting 76 call sites to pass a chapter object: zero behavioural change, and a chapter 2 only needs a data file + registry entry (plus its own painted zone art). Run saves store `chapter`.
