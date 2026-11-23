# Changelog

All versions are pre-release vertical slices. Automated tests and GPU captures are not a substitute for human playtest approval.

## 0.4.0 — 2026-11-20## 0.5.0-dev — in progress (branch `claude/autonomous-v05`)

Built on `v0.4.0` (`codex/demo-v0.4.0` @ `bd25e07`). Not released.

### Fixed
- **Crawler soft-lock** (pre-existing since v0.4.0): a pounce that overshot the hero made the crawler retreat back *under* him and re-pounce point-blank forever (soak run: 29 deaths at one spot). It now faces the hero before retreating and backs off while recovering. Test `crawler_retreats_after_pounce`: camping frames 284 → 0.
- **Unlimited air dash**: `air_dash` was set but never checked; now one air dash per airtime (`air_dash_once`).
- **Dropped inputs**: dash / talisman / gourd / beads pressed during attack active frames, landing or hit-stun were ignored; now buffered 0.18 s (`dash_buffered_from_attack`).
- **Enemy pile-ups**: crawlers and grunts no longer stack into one silhouette at slabs/walls; they queue behind an ally nearer the hero and a pinned enemy shoves its neighbour (`pack_spreads_at_ledge`: 54 % → 0 % stacked frames).
- **Boss body overlap**: the hero no longer sinks into the Undead General's painted armour (`boss_body_block`: 1 px → 79 px), timing windows unchanged.

### Added
- **Lore steles (残碑)**: five readable inscribed steles, one per zone, with an ink-scroll reading card; the General's epitaph rises in the boss arena once he is sealed. Journey Ledger shows `拓得碑文 n/5`.
- **Contextual tutorial**: roadside hint strips close 1.2 s after the player performs the taught move and are not repeated.
- **Burial-wave finale variety**: a Taint Spitter rises at the far end 2.2 s in, mixing ranged pressure and taint puddles with the crawler rush (6/6 human-like clears, 0 deaths; rendered check `evidence/v0.5.0/shots/burial_wave_spitter.jpg`).
- **Temple husk duo**: group B is now two sealed husks (entrance + far end) and one grunt — two seal-pressure meters to manage. Human-like telemetry: dmg 16.9 → 36.7/run, 6.5 → 14.2 s, 0 deaths in 6 runs; curve still peaks at the elite.
- **Held-frame life (animation)**: enemy combat clips are mostly 1–2 painted frames held up to ~1.8 s; held frames now coil and tremble during wind-ups (tension rising to the strike) and heave-breathe in recoveries/kneel/hit. Visual-only (pivot + shader breathe), enemies only; hitboxes, timings and `hero_anim_no_pops` unchanged. Test `held_frames_alive`.
- **UI**: Journey Ledger button row follows the ledger's laid-out height (lore row no longer overlaps buttons); controls card lists 读碑.
- QA: `lorecap` capture mode; 11 new engine checks (74 total).

 (Pre-Commercial Prologue Demo)

Branch `codex/demo-v0.4.0`, built on `v0.3.2` (branched from `origin/claude/post-codex-continuation` @ `8eb690d`).

### Added & Upgraded
- **World depth, painted stone Pailou gate & destructible wasteland props:**
  - Replaced the procedural end gate with a hand-painted weathered Taoist stone Pailou archway (`end_gate_pailou.webp`) featuring behind-archway golden god-rays and rising spirit motes once `e8_elite` is sealed.
  - Added 10 painted destructible props across all 5 zones (`urn`, `crate`, `brazier` — intact + shattered `.webp` states) in `game/scripts/level/destructible.gd` and `spirit_wisp.gd`, dropping homing spirit wisps that restore Qi (and live flickering warm point-lights on intact temple/burial braziers).
  - Added 4 zone-matched ink-wash foreground parallax clusters (`fg_village`, `fg_lowland`, `fg_temple`, `fg_burial` on layer 2 at 1.22x parallax, strictly anchored below the ground feet line) and upgraded campfire checkpoints with dramatic first-rest golden hearth ignition pillars.
- **Multi-frame hand-painted enemy combat animations & combat game-feel:**
  - Generated, sliced, and baked 2.5D normal/thickness/AO maps for all 5 enemy archetypes' combat states (`grunt` 6 clips, `crawler` 7 clips, `husk` 8 clips, `spitter` 8 clips, `elite` 12 clips), wired via `Enemy.play_pose_or_clip` without altering any hitboxes, hurtboxes, damage/poise values, or wind-up windows.
  - Added diegetic world-space enemy mini HP/poise/burn bars (`MiniBar`, hidden at full HP and hidden on Elite Boss) and Husk's escalating chest talisman crack warning (`SealCrackIndicator`).
  - Upgraded Elite Boss Phase 2 (`二相 · 狂煞`) with persistent crimson-gold aura rings, dark-crimson smoke/ember emitters, trailing blade sparks, and heavy stomp dust; upgraded player Parry (`Fx.parry_burst`), painterly `FrameAnim` afterimages, grounded skid/launch/landing dust, hurt crimson edge pulse, and gourd heal spiral.
- **Narrative framing, 6-mood whispers & commercial UI flow:**
  - Extracted all 6 expression portraits (`calm`, `alert`, `fierce`, `combat`, `hurt`, `wistful`) and 3 full-bleed ink-scroll story plates (`prologue_01..03.webp`).
  - Added a skippable 3-plate **Ink-Scroll Prologue** (`game/scenes/prologue.tscn`, auto-bypassed in automated `--test=` runs) and non-blocking top-right **Zone Whisper** cards across all 5 zones plus boss seal.
  - Unified Title (with boxed Controls overlay and persisted best rank/time badge), Pause, Options, and Ending (**Journey Ledger · 行旅录** with animated vermilion **甲 / 乙 / 丙** Seal Stamp, persisted best rank in `settings.cfg`, and interactive Play Again / Title buttons).
- **44.1 kHz stereo audio overhaul:**
  - Upgraded `tools/audio/make_audio.py`, `tools/audio/audio_review.py`, and `game/scripts/core/sfx.gd` to 75 broadcast-clean 44.1 kHz WAV assets (30 stereo music/ambience/stinger/climax + 45 mono SFX, max peak `-1.00 dBFS`, max loop seam `0.0115`, `0 flagged`), including 10 new v0.4.0 SFX (`pot_break`, `wood_break`, `brazier_clang`, `wisp_pickup`, `hearth_ignite`, `ui_hover`, `ui_click`, `ui_back`, `seal_stamp`, `whisper_chime`).

### Verification
- **Engine checks:** **63/63 PASS** (`--test=all --nohitstop --mute`) with **zero** script errors, warnings, or leaks, including `spec_conformance` (21/21), `hero_anim_no_pops` (`12.4 px`), `destructibles_*`, `diegetic_mini_bar`, `diegetic_husk_seal_fx`, `enemy_frame_anims_loaded`, `prologue_advance_and_skip`, `whisper_non_blocking`, and `rank_and_persist`.
- **Playthrough bot & soak:** 0-death Normal playthrough (`rank=甲`) and 2-run soak (`soak_no_leak PASS`, `nodes 86->86`, `orphans 0->0`), plus `hero_footwork.gd` (`floor_gap_px=0.0` left & right).
- **Five-zone Metal readability (`1280×720`):** **15/15 PASS** (`evidence/v0.4.0/readability/READABILITY.md`).
- **Real-GPU performance (`Apple M6` Metal `1280×720`):** `village` melee `p50=2.38 ms / p99=4.56 ms`; `lowland` `p50=1.91 ms / p99=3.90 ms`; `elite` boss `p50=2.10 ms / p99=3.80 ms`.
- **Packaging & native macOS verification:** Exported `v0.4.0` macOS / Windows / Linux desktop ZIPs and verified unpacked macOS `.app` via `tools/qa/native_release.py` (`evidence/v0.4.0/native/macos/native.json`).

### Pending
- Windows and Linux `v0.4.0` packages have not been executed on their target OSes.
- Human playtest, physical controller feel, and speaker audio audition remain to do.

## 0.3.2 — 2026-11-19 (pre-release)

Intermediate milestone integrated into branch `codex/demo-v0.4.0`, based on `origin/claude/post-codex-continuation` @ `8eb690d` (`v0.3.1`).

### Added & Improved (presentation, animation & feel; combat hitboxes & timing unchanged)
- **Full frame-by-frame hero combat & skill animations (`FrameAnim`):** painted transparent RGBA sheets (`hero_guard_idle_sheet.png`, `hero_slash12_sheet.png`, `hero_slash3_dash_sheet.png`, `hero_skills_sheet.png`) with baked 2.5D normal/thickness/AO maps covering `guard_idle`, `guard_to_idle`, `slash1` (4f), `slash2` (4f), `slash3` (4f), `dash`, `dash_attack` (3f), `jump_attack`, `talisman` (2f), `gourd` (2f), `beads_a`, and `beads_b`. Reduced `hero_anim_no_pops` worst-case body-centre jump from `32.9 px` to `16.7 px`.
- **Smooth combat-to-idle sheathing transition:** `Player` holds the animated `guard_idle` profile loop during combat and plays the 3-frame `guard_to_idle` transition (`0.34 s`) before returning to the three-quarter relaxed `idle`, removing the single-frame turn snap.
- **Upgraded ink-and-brass HUD & 3-state portraits:** added `tools/art/extract_portraits.py` to cut three centered circular expression busts (`portrait.png`, `portrait_combat.png`, `portrait_hurt.png`) from `concept_art/03_protagonist_expressions_mood.png`. Upgraded `hud.gd` with antialiased `StyleBoxFlat` brass-bracket plaques, HP damage-lag trail & low-HP heartbeat, Qi cost notches (`20`/`50`), warm-parchment skill medallions (`葫芦`/`符箓`/`念珠`), and a matching Boss Bar with 50% phase notch and recessed poise gauge.
- **Wall-pinned personal-space separation:** `Enemy._safe_nudge_x` checks geometry/leash collisions when yielding; if an enemy is pinned against a wall, platform, barrier, or leash, the grounded hero cleanly absorbs the remaining separation while keeping dash-through, jump-over, and enemy attack windows intact.
- **Sprite-sheet bleed cleanup:** `tools/art/build_anim_sheets.py` now filters detached gutter-bleed fragments touching cell edges and supports `--actors` / `--skip-legacy` flags.

### Verified (real Apple Silicon Metal GPU & native macOS package)
- Clean import + `54/54` engine checks (`hero_anim_no_pops=16.7 px`, extended `guard_stance` and wall-pinned `personal_space` `open=33 pinned=34 dash_past=true`) + 0-death Normal bot clear (`02:17`, 24 kills, 3 parries) + `hero_footwork.gd` (`floor_gap_px=0.0`).
- Five-zone Metal `1280×720` figure readability: **15/15 PASS** (`evidence/v0.3.2/readability/READABILITY.md`).
- Real-GPU frame time on Apple M6 Metal (`1280×720`): multi-enemy `wave` `p50=2.45 ms / p99=4.48 ms`; `elite` boss fight `p50=2.14 ms / p99=3.42 ms`.
- Exported three platform ZIPs (`v0.3.2`) and verified the unpacked **native macOS `.app`** with `tools/qa/native_release.py` (`ditto`, `codesign --verify --deep --strict`, `engine`, `normal-route`, rendered `title` & `village` — all PASS; `evidence/v0.3.2/native/macos/native.json`).

### Pending
- Windows and Linux v0.3.2 packages have not been executed on their target OSes.
- Human playtest, physical controller feel, and speaker audio audition remain to do.

## 0.3.1 — 2026-11-19 (pre-release)

Branch `claude/post-codex-continuation`, based on `codex/visual-polish-v03` @ `451d4d3`.

### Verified baseline
- Before any changes, `451d4d3` passed a clean import, 52/52 engine checks and a full bot clear. A full rendered playthrough of it was reviewed.

### Fixed (presentation only; combat rules and hitboxes unchanged)
- **Guard stance:** between strikes, and while an enemy is near, the hero holds the profile sword guard. Previously the hero snapped to the three-quarter-front relaxed idle for one beat between strikes.
- **Boss-fight hint:** the hint strip moves under the boss title card instead of covering both fighters' feet.
- **Personal space:** enemies in neutral states are pushed back when the hero walks into them, so the two painted figures no longer stack. There is no push while the hero dashes or is airborne, or while an enemy attacks, so all dodge windows are unchanged.
- **Damage numbers:** numbers on the same target stack upward instead of overprinting.
- **End gate:** the flat black rectangles are replaced by a shaded stone pailou (archway) with eaves, a plaque and ground mist.
- **Encounter ward:** the full-height "ladder" is replaced by light rising from a ground seal and fading upward, with four hanging talismans.
- **Particles:** particles are soft round dabs instead of hard squares.
- **Hit stains:** stains are translucent and soaked into the ground instead of opaque black ellipses.
- **Platforms:** each platform takes its zone's light tone, has a contact shadow and keeps the painting's proportions instead of being squashed horizontally.
- **Taint pools:** a taint pool no longer dyes the whole costume olive. The point light is halved and desaturated, with a light tint and vapour wisps instead.
- **Menus:** one ink-and-cinnabar UI skin (`InkTheme`) now covers the title, pause and options screens.
- **HUD portrait:** the portrait is cut to a disc so it sits inside its ring.
- **Boss-sealed card:** the English line uses the body serif. The brush font has no proper Latin glyphs.

### Tests and tooling
- New engine checks `guard_stance` and `personal_space` (54 in total).
- New capture modes `titlecap`, `gatecap`, `sealcap` and `platcap`.
- New script `tools/qa/smoke.sh` runs a local verification in one command.
- Evidence is in `evidence/v0.3.1/`. Handoff notes are in `HANDOFF.md`.

### Pending
- Windows and macOS packages have not been run on their target systems.
- Human playtest, physical controller and audio listening are still to do.
- Real-GPU performance has not been measured.

## 0.3.0-rc.1 — 2026-11-19 (pre-release, Codex)
Visual polish: painted zones, new hero poses, three difficulties and dynamic key prompts. Built from `93cee6d`. The later Codex commit `451d4d3` added frame-by-frame animation, 2.5D lighting, combat feel work and new title and ending screens. Those changes ship for the first time in 0.3.1.

## 0.2.0 — 2026-11-19 (pre-release)
Skinned cut-out rigs, options menu, telemetry-based balance, boss music and the macOS universal export.
