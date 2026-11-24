# Changelog

All versions are pre-release vertical slices. Automated tests and GPU captures are not a substitute for human playtest approval.

## 0.4.0 — 2026-11-20## 0.6.0 — 2026-11-24 (release candidate, not published)

Branch `claude/autonomous-v05`. Packages built locally (`build/`), verification in [evidence/v0.6.0](evidence/v0.6.0/README.md). No GitHub Release published (needs the owner's approval). Includes the 0.7-track items below (low graphics mode, perfcap, combat-quiet fixes).

### Fixed (0.7 track)
- **Stele prompt on gamepad**: the 读碑 prompt was built once and kept showing keyboard keys after switching to a pad or rebinding; it now follows `Game.prompts_changed` (`W / Up 读碑` ↔ `D-pad ↑ 读碑`). Test `stele_prompt_follows_device` (fails on the previous code).
- **Quieter combat** (full rendered review of the current build): the temple stele's 读碑 prompt floated over the hero during the nearby husk fight — steles now hide the prompt and refuse to open while the mix state is combat; the boss intro card replayed on every retry and the respawn line landed on top of it — it now plays on the first meeting only (per run, kept in the campfire save). Test `combat_quiet`; `lore_read_and_close` now starts past the village lock, as in real play.

### Added (0.7 track)
- **Stele reactions**: after the first read of each stele the wanderer reacts in a non-blocking whisper with a matching mood portrait (alert at the sealed well, wistful at the temple — 「师兄……那枚镇尸铃，你带去了哪里？」 seeds the chapter-2 thread — and at the General's epitaph). Data: `react` on each LORE entry. `lore_read_and_close` now also checks the reaction; render `evidence/v0.6.0/stele_reaction_temple.png`.
- **Low graphics mode** (精简画质 in Options, applied live, persisted; `--quality=0` for QA): skips the full-screen atmosphere pass, ambient motes 220 → 72, transient FX particles halved. New `--test=perfcap` (rendered; wall-clock p50/p95/p99 in village / lowland / burial wave / elite). Software-GL (llvmpipe) result over two runs each: p50 village 13–16 → 11–12 ms, lowland 16–17 → 13 ms, burial wave 20–21 → 17–19 ms, elite 21–26 → 19–20 ms; fight cost is physics 5–7.5 ms (spread across actors, `--ablate=enemies|player|level`) plus software-GL fill-rate of the painted layers — not the character shader (D42). Look preserved (`shots/quality_high_vs_low.jpg`).

### Changed
- **Chapter-ready route data**: chapter 1's route data moved verbatim to `scripts/level/chapters/chapter1.gd`; `LevelData` is now an active-chapter facade (typed static vars with the same names, `LevelData.use_chapter(id)`), so all 76 existing call sites are unchanged. The run save records the chapter and Continue restores it. Test `chapter_facade`; 82/82 in source and inside the exported Linux build, soak clean.

### Added
- **Controller vibration**: `Game.rumble()` sends to the active pad only — hurt (stronger for heavy hits), parry (crisp high-frequency), heavy combo/down-slash connects, hero death, and the General's fall; 手柄震动 toggle in Options (persisted). Verified structurally (test `rumble_events_and_toggle`); **not felt on a physical pad**.
- **Boss rematch (post-clear challenge)**: after a first clear the title offers 再战尸将 · Rematch — start at the last campfire with only the General uncleared; the ending shows 尸将再战 · 已镇 with the run time and this difficulty's best (★ on a new record); Play Again restarts the rematch. Never touches the story save or the main rank; per-difficulty bests persist and show on the title status plate. Six-entry title layout tightened. Test `rematch_flow`.
- **Accessibility options**: 闪屏强度 Screen flashes (0–100 %) scales every full-screen flash and colour pulse (parry, hurt, phase-2, boss-defeat white flash) — 0 removes them; 教学提示 Tutorial hints toggles the roadside hint strips. Both persisted in `settings.cfg`. Test `accessibility_flash_and_hints`.
- **Campfire save + Continue**: resting at a campfire saves the run (`user://run.cfg`: checkpoint, cleared encounters, steles, whispers, learned hints, stats, time, difficulty). The title shows 继续 · <zone> <time> first when a save exists; New Game or finishing the demo deletes it. Tests write only with `--qa-run=PATH`. Test `run_save_and_continue`.

## 0.5.0 — 2026-11-23 (release candidate, not published)

Branch `claude/autonomous-v05`, built on `v0.4.0` (`codex/demo-v0.4.0` @ `bd25e07`). Packages built locally; no GitHub Release has been published (needs the owner's approval).

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
- **Adaptive music mix**: in-game recording showed a flat mix (boss only ~1.5 dB louder than empty exploration). Music/ambience now route through `MusicDyn`/`AmbDyn` sub-buses driven by a level mix state: exploration −4 dB music, combat (locked encounter or aggro enemy within 600 px) full music with ambience −5 dB; ~1 s swell, ~2.5 s release; menus neutral. User sliders untouched. Recorded mix: loudness spread 5.3 → 6.8 dB, peak −1.01 dBFS, 0 clipped. Not yet human-auditioned.
- **Boss defeat presentation**: the 镇 seal card sat at screen centre, covering the General's slow-motion fall and the hero for ~3 s; it now sits in the sky band above the action, and a still-visible intro title is dismissed so cards never stack. New capture mode `defeatcap` (real kill → fall → seal → dissolve).
- **Fairer crawler tell + difficulty-scaled telegraphs**: crawler crouch 0.26 → 0.32 s on Normal (was the shortest tell, ≈ human reaction time) with a low hiss as an off-focus audio cue; rank-and-file wind-ups (crawler, grunt, spitter) scale ×1.35 Story / ×1.0 Normal / ×0.88 Hard (elite spec windows unchanged). Measured 0.43 / 0.33 / 0.28 s; human-like pounce damage 51.7 → 38.8/run.
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
