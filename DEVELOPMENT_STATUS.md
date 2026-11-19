# DEVELOPMENT_STATUS — 道行者 / Taoist Wanderer

_Last updated: 2026-11-19 (session 3) · branch `dev/vertical-slice-20261118` · engine Godot 4.7.2 · version 0.1.3_

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

## v0.2.0 progress (in development)
- **M7 animation — done (verified by rendered captures + tests):** real cut-out rigs replace single-pose deformation. `tools/rig/make_rig.py` splits a concept pose into part layers (inpaints what each part hides, synthesizes hidden thigh fabric), builds grid meshes with inverse-distance bone weights; `CutoutRig` = `Skeleton2D`/`Bone2D` + skinned `Polygon2D` in a `CanvasGroup` (ink outline/flash/burn on the composite) + `AnimationPlayer` clips with crossfades + spring cloth (ribbon, robe panels). Rigs: hero, elite, grunt, husk, spitter, crawler (quadruped). Clips: hero idle/walk/run/jump/fall/land/hit/block/dash/dead + attack wind-ups/recovery; per-enemy locomotion and attack anticipation (elite chop/sweep wind-ups, rig-driven sweep, kneel, roar, death). Painted concept poses remain as attack contact frames (35 ms cut). Limits: one source pose per character — no turnaround, hands/fingers don't articulate, the hero's base pose is three-quarter front.
- **M6 gameplay — done:** options menu (Master/Music/SFX buses, shake strength, hit-stop, fullscreen, keyboard rebinding, persisted; live key names in hints); telemetry + balance pass (docs/BALANCE.md: deaths 21 → 6 over 10 human-like runs, elite 1.8 → 0.2/run); boss fairness gates (sweep jump window 0.36 s, dash windows 0.18 s).
- Next: M8 audio, M9 visuals, M10 packaging (see ROADMAP).

## Acceptance evidence
Run `GODOT=<godot> tools/acceptance.sh <version>` — it runs every executable gate and writes `evidence/acceptance-<date>/REPORT.md` (gates table, spec rows, test list, FPS, rendered frames, contact sheet). Latest: `evidence/acceptance-20261119/` at commit `556ec45` — **12/12 gates PASS**: 42 engine checks in source **and** inside the exported v0.1.3 Linux binary; 3 perfect + 3 human-like bot clears (human-like deaths 0/1/9 — the 9-death run died 8× at the elite, which has a campfire right before the arena); soak (2 full playthroughs in one process, nodes 37→37, 0 orphans); exported-build bot clear; 50 rendered frames; 61–73 FPS at 720p on software GL.

## Implemented and verified
**Flow:** title → level (5 zones, 6 campfires, 9 encounters) → elite boss → light gate → ending screen with time/deaths/kills/parries → back to title. Pause menu (resume / restart from campfire / title / volume slider). Death → "身陨" card → fade → respawn at last campfire; failed encounters reset, cleared ones stay cleared.

**Player (spec docs/02, docs/05):** run 260 px/s, variable jump, coyote + buffered input, dash 540 px/s with i-frames (+1 air dash), 3-hit combo 横斩→下劈→突刺, `S+J` down slash, dash slash (low), jump attack (low, small pogo on hit), hold-block with 0.17 s parry window (parry staggers enemies, +Qi, hit-stop), talisman (homing, 20 Qi, ignites), gourd (3 charges: +35 HP + knock-back gust), prayer beads (50 Qi, charge with super armour → 210 px ring AOE, purifies puddles), hit reaction, death. HP/Qi/gourd HUD.

**Enemies:** all five, each with a distinct FSM:
- Grunt — wander → alert → shamble → 0.4 s lean-forward wind-up (glint telegraph) → lunging claw → recovery; any hit staggers.
- Crawler — lurks (dimmed), 92×46 hurtbox, rears up, crawls 215 px/s, 0.26 s crouch telegraph + danger band, low pounce, scuttles back; flips on hit.
- Talisman-Bound Husk — stands sealed until approached/struck, awakens, slow armoured advance, sleeve strike; 4 melee hits → glowing seal → unblockable 符力溃散 burst. Ranged hits don't build pressure.
- Taint Spitter — keeps 220–520 px range, glowing throat-sac wind-up 0.9 s (interruptible by poise ≥ 12), parabolic glob → 4.5 s taint puddle (slow + corrosion), long recovery, weak swipe up close.
- Undead Warrior Elite — super armour + poise meter, 0.8 s chop (+ low ground shock to jump), 0.65 s sweep (40–128 px band), long recoveries, parry/poise break → 1.8 s kneel with bonus damage, phase 2 at 50 % (faster, chains, 2-grunt summon). Boss bar with armour meter.

**Presentation:** 50 concept-art pose sprites with ink contour + pale paper halo (figure/ground separation), shader skeletal rig per pose: two-bone legs (hip/knee) plus arm bones from `assets/sprites/rig.json` (shoulder pivot, hand, weapon tip; inpainted where the limb leaves) — legs, arms, torso move in walk/run/idle, the sword arm sweeps through every attack, enemy weapon arms raise and swing, knee-tuck airborne pose, hit jitter + ground ink splats + camera zoom-punch, cross-fades, lean/squash, stride/sway/breath shader, hit flash, ink-burn deaths; sword-qi brush arcs, telegraph glints, danger bands, rings, particles, hit-stop, screen shake; parallax ink-wash wasteland with per-zone tint + fog + vignette/grain + ambient particles (dust/ash/spores/embers), cracked-earth ground with debris; brush-font zone cards, boss intro card, tutorial hint strip from roadside steles; generated SFX + 4 pentatonic music loops + 5 zone ambience beds (wind, crows, bubbling taint, wind chimes, burial groans) with crossfades; title and ending screens.

### Verified results (this session)
- `--test=all`: **42/42 checks pass** (incl. settings persistence, soak/no-leak (separate gate), 21-row spec conformance vs docs/05, animation-continuity (no pose pops), enemies-cross-ledges, spawns-on-surfaces guard, flow: pause-restart keeps progress, ending→title→new run resets state, no stale actors) (movement, jump, dash, crawler band whiff/hit with slash vs down/dash slash, grunt stagger + combo kill, timed parry, husk seal burst + punishment + talisman no-pressure, spitter glob → puddle, talisman interrupts spitter wind-up, elite wind-up 0.80 s and armour vs light hits, death → respawn at campfire, encounter lock/barrier/clear, scripted clear of every encounter → ending scene). No script errors.
- `--test=bot` (input-only scripted player, full route from the title flow): completes the current route in 3 of 3 runs (0–1 deaths, 24–27 kills, ≈2:15–3:00 game time for the bot). Also passes **on the exported Linux binary**.
- Full-length rendered playthrough recorded (movie writer, 161 s) and reviewed as a contact sheet; found & fixed: enemy hit-flash whiting out the whole silhouette, spitter spawning inside a rock ledge (could soft-lock Group C).
- Audio integration verified by recording the mixed output with Godot's movie writer during a bot run (music + SFX present; peaks now limited by a master compressor/limiter). Not yet listened to by a human.
- Difficulty proxy: `--bot_skill=human` (≈180 ms reaction cadence, 25 % missed defensive reads) cleared 6/6 runs with 0–7 deaths (mean ≈2.8); most deaths are at the elite, the rest at Groups A/C. A real first-time player will likely die more (the bot reads enemy state perfectly).
- Performance: 55–65 FPS at 1280×720 on CPU software GL (llvmpipe) during the burial-mound wave.
- v0.1.2 exported Linux binary: 38/38 checks and full bot clear run *inside the exported build*.
- Re-verified after the latest polish commit: 33/33 checks, bot clears on source and on the re-exported Linux binary.
- Rendered captures under Xvfb (software GL): title, all five zones, every enemy's telegraph/attack, VFX, ending screen were inspected.
- Packages: `python3 tools/build/package.py 0.1.2` → `build/TaoistWanderer-v0.1.2-{linux,windows}-x86_64.zip` (41 / 50 MB).
- Exports: `build/linux/TaoistWanderer.x86_64` (verified: runs, renders, bot completes) and `build/windows/TaoistWanderer.exe` (**built but not run** — no Windows here; installing Wine was not permitted in this environment).

## Not verified / known limitations
- **No human playtest yet.** Feel (timing windows, difficulty, readability at speed) is tuned from specs and bot runs only. Bot clear time (~2 min) means a first-time human run is probably ~8–15 min.
- **Audio never heard by a human** — mix verified numerically/spectrally from a recorded run only.
- **Motion is single-pose rigging** (legs, arms, torso deformed from one painted pose per state; attacks blend 2 key poses + arm sweep). Hands and cloth don't deform independently and there are no painted in-betweens; it reads as cut-out animation, not frame-by-frame.
- Software GL only here; real-GPU frame rate untested (the game is light: sprites + a few shaders).
- Elite uses the V1.0 sheet images (V1.1 corrected sheet not produced yet).
- Environment art is procedural, not painted; ruins can look blocky up close.
- Some enemy cut-outs keep small parchment specks between rags; the crawler/husk sheets' pose rows are lower-resolution than the hero's.
- Gamepad: every binding verified by injecting joypad events in-engine (`gamepad_actions_fire`); not tried on a physical pad.
- Windows export unrun; macOS not built.

## Session-3 changes
Talisman pose was mirrored (threw away from facing) — fixed; arm bones for talisman/gourd/block; settings persistence; soak gate.
Arm bones (rig.json) for hero + grunt/husk/spitter/elite; attack arm curves; idle/run/air arm motion; elite cleaver raise/chop/sweep; ledge-hop for enemies (fixed crawler stall); spec-conformance, anim-continuity, ledge tests; outline sampling optimisation; acceptance.sh + evidence; v0.1.3.

## Session-2 changes (for reviewers)
Leg rig + torso twist + knee-tuck jumps; enemy cut-out cleanup; hit jitter/splats/zoom-punch/smears; topple/kneel deaths; elite chop two-beat wind-up; ground strata + debris; parallax seam fix; ambient particles; zone ambience beds with crossfades; master limiter; Road's Edge campfire; dash i-frames 0.24 s; spawn-on-surface fix (Group C soft-lock); opening epigraph; F11 fullscreen; package.py; RELEASE_NOTES.md.

## Next concrete tasks
See `ROADMAP.md` (M6 onward). Top three: human playtest + tuning pass; real locomotion animation (hero run cycle, grunt shamble) via Skeleton2D cut-outs or painted frames; audio audition/mix pass.
