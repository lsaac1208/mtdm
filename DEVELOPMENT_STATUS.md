# DEVELOPMENT_STATUS — 道行者 / Taoist Wanderer

_Last updated: 2026-11-18 (session 2) · branch `dev/vertical-slice-20261118` · engine Godot 4.7.2 · version 0.1.0_

## Where things are
| Path | What |
|---|---|
| `game/` | Godot project (open `game/project.godot`) |
| `game/scripts/actors/` | `actor.gd` (shared body), `player.gd` (13-pose combat FSM), `pose_sprite.gd` (key-pose renderer) |
| `game/scripts/enemies/` | `enemy.gd` base + `grunt`, `crawler`, `husk`, `spitter`, `elite` |
| `game/scripts/core/` | autoloads: `game.gd` (input map, flow, hit-stop, dev flags), `combat.gd` (hit resolver), `sfx.gd` |
| `game/scripts/level/` | `level_data.gd` (route, encounters, signs), `level.gd` (builder, camera, parallax, respawn), `encounter.gd`, `barrier.gd`, `checkpoint.gd`, `end_gate.gd` |
| `game/scripts/fx/`, `game/shaders/` | slash/ring/telegraph VFX, talisman + taint projectiles, puddles, sprite + atmosphere shaders |
| `game/scripts/ui/` | title, HUD, pause menu, ending |
| `game/tests/test_runner.gd` | engine-level checks, playthrough bot, showcase captures |
| `tools/art/` | `extract.py` + `sprites.json` (pose cut-outs), `make_env.py` (environment art), `segment.py` |
| `tools/audio/make_audio.py`, `tools/build/make_fonts.py` | audio + font generation |
| `build/` (git-ignored) | exported binaries and zips |

## Implemented and verified
**Flow:** title → level (5 zones, 5 campfires, 9 encounters) → elite boss → light gate → ending screen with time/deaths/kills/parries → back to title. Pause menu (resume / restart from campfire / title / volume slider). Death → "身陨" card → fade → respawn at last campfire; failed encounters reset, cleared ones stay cleared.

**Player (spec docs/02, docs/05):** run 260 px/s, variable jump, coyote + buffered input, dash 540 px/s with i-frames (+1 air dash), 3-hit combo 横斩→下劈→突刺, `S+J` down slash, dash slash (low), jump attack (low, small pogo on hit), hold-block with 0.17 s parry window (parry staggers enemies, +Qi, hit-stop), talisman (homing, 20 Qi, ignites), gourd (3 charges: +35 HP + knock-back gust), prayer beads (50 Qi, charge with super armour → 210 px ring AOE, purifies puddles), hit reaction, death. HP/Qi/gourd HUD.

**Enemies:** all five, each with a distinct FSM:
- Grunt — wander → alert → shamble → 0.4 s lean-forward wind-up (glint telegraph) → lunging claw → recovery; any hit staggers.
- Crawler — lurks (dimmed), 92×46 hurtbox, rears up, crawls 215 px/s, 0.26 s crouch telegraph + danger band, low pounce, scuttles back; flips on hit.
- Talisman-Bound Husk — stands sealed until approached/struck, awakens, slow armoured advance, sleeve strike; 4 melee hits → glowing seal → unblockable 符力溃散 burst. Ranged hits don't build pressure.
- Taint Spitter — keeps 220–520 px range, glowing throat-sac wind-up 0.9 s (interruptible by poise ≥ 12), parabolic glob → 4.5 s taint puddle (slow + corrosion), long recovery, weak swipe up close.
- Undead Warrior Elite — super armour + poise meter, 0.8 s chop (+ low ground shock to jump), 0.65 s sweep (40–128 px band), long recoveries, parry/poise break → 1.8 s kneel with bonus damage, phase 2 at 50 % (faster, chains, 2-grunt summon). Boss bar with armour meter.

**Presentation:** 50 concept-art pose sprites with ink contour + pale paper halo (figure/ground separation), shader two-bone leg rig (thighs rotate at hip pivots, knees bend, feet stay planted, hanging props stay rigid) for every character's walk/run, knee-tuck airborne pose, hit jitter + ground ink splats + camera zoom-punch, cross-fades, lean/squash, stride/sway/breath shader, hit flash, ink-burn deaths; sword-qi brush arcs, telegraph glints, danger bands, rings, particles, hit-stop, screen shake; parallax ink-wash wasteland with per-zone tint + fog + vignette/grain; brush-font zone cards, boss intro card, tutorial hint strip from roadside steles; generated SFX + 4 pentatonic music loops + wind ambience; title and ending screens.

### Verified results (this session)
- `--test=all`: **36/36 checks pass** (incl. flow: pause-restart keeps progress, ending→title→new run resets state, no stale actors) (movement, jump, dash, crawler band whiff/hit with slash vs down/dash slash, grunt stagger + combo kill, timed parry, husk seal burst + punishment + talisman no-pressure, spitter glob → puddle, talisman interrupts spitter wind-up, elite wind-up 0.80 s and armour vs light hits, death → respawn at campfire, encounter lock/barrier/clear, scripted clear of every encounter → ending scene). No script errors.
- `--test=bot` (input-only scripted player, full route from the title flow): completes the current route in 3 of 3 runs (0–1 deaths, 24–27 kills, ≈2:15–3:00 game time for the bot). Also passes **on the exported Linux binary**.
- Audio integration verified by recording the mixed output with Godot's movie writer during a bot run (music + SFX present; peaks now limited by a master compressor/limiter). Not yet listened to by a human.
- Performance: 55–65 FPS at 1280×720 on CPU software GL (llvmpipe) during the burial-mound wave.
- Re-verified after the latest polish commit: 33/33 checks, bot clears on source and on the re-exported Linux binary.
- Rendered captures under Xvfb (software GL): title, all five zones, every enemy's telegraph/attack, VFX, ending screen were inspected.
- Exports: `build/linux/TaoistWanderer.x86_64` (verified: runs, renders, bot completes) and `build/windows/TaoistWanderer.exe` (**built but not run** — no Windows/Wine here).

## Not verified / known limitations
- **No human playtest yet.** Feel (timing windows, difficulty, readability at speed) is tuned from specs and bot runs only. Bot clear time (~2 min) means a first-time human run is probably ~8–15 min.
- **Audio never heard by a human** — mix verified numerically/spectrally from a recorded run only.
- **Motion is single-pose rigging**: legs are rigged in the shader, but arms/torso don't animate during locomotion and attacks are key-pose cross-fades (no in-betweens). Still the main visual gap versus hand-animated frames.
- Software GL only here; real-GPU frame rate untested (the game is light: sprites + a few shaders).
- Elite uses the V1.0 sheet images (V1.1 corrected sheet not produced yet).
- Environment art is procedural, not painted; ruins can look blocky up close.
- Some enemy cut-outs keep small parchment specks between rags; the crawler/husk sheets' pose rows are lower-resolution than the hero's.
- Gamepad bindings exist but were not tested with a physical pad.
- Windows export unrun; macOS not built.

## Next concrete tasks
See `ROADMAP.md` (M6 onward). Top three: human playtest + tuning pass; real locomotion animation (hero run cycle, grunt shamble) via Skeleton2D cut-outs or painted frames; audio audition/mix pass.
