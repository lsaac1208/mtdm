# ROADMAP — 道行者 / Taoist Wanderer

Priorities follow the project directive: launchable → core combat → distinct enemies → full level + elite + ending → polish/packaging.

## Done (v0.1.0, 2026-11-18)
- **M0 Assessment** — read README, docs/01–05, raw chat, MANIFEST; audited 10 concept sheets (all are parchment-backed reference sheets; no runtime assets; elite only on sheet 06; no environment art).
- **M1 Foundation** — Godot 4.7.2 project in `game/`, input map (keyboard + pad), autoloads, scene flow, fonts.
- **M2 Asset pipeline** — pose extraction from sheets (50 sprites, spec heights), procedural environment + audio generators.
- **M3 Core combat** — player 13-pose FSM, rect hit/hurt with literal high/low bands, poise/stagger, parry, skills, hit-stop/shake.
- **M4 Enemies** — grunt, crawler, husk, spitter, elite with signature mechanics and telegraphs.
- **M5 Level & flow** — 5-zone route, Group A–D encounters + burial wave, arena barriers, campfires, death/respawn, boss bar, ending, title, pause.
- **M5.5 Verification** — 33 engine checks, input-only bot clears the route (source + exported Linux build), rendered capture modes, Linux/Windows exports.

## Done in session 2 (v0.1.1–v0.1.2)
- Shader leg rig (walk/run/jump), torso twist, motion smears, hit jitter/splats/zoom punch, death motions, elite chop readability.
- Ground/debris/parallax seam fixes, ambient particles, zone ambience beds + crossfades, master limiter.
- Human-like bot difficulty proxy, Road's Edge campfire, dash i-frame tuning, spawn soft-lock fix, gamepad mapping test, flow tests, package.py.

## Done in session 3 (v0.1.3)
- Arm bones + attack arm curves (hero and enemies), enemy ledge hop, spec-conformance/continuity/ledge tests, acceptance.sh with committed evidence.

## v0.2.0 (done — acceptance 14/14 at e312e39)
- [x] M7 skinned cut-out rigs + clips for hero and all five enemies
- [x] M6 options menu, telemetry, balance pass, fairness tests
- [x] M8 audio normalization, boss music + stingers, audio review evidence
- [x] M9 zone skylines, material hit effects, boss defeat cinematic, readability gate, 5-zone comparison
- [x] M10 Linux/Windows/macOS packages, v0.2.0 acceptance

## After v0.2.0
- Human playtest + listening test (cannot be done here).
- Windows/macOS runtime checks on real machines; Developer ID signing + notarization (needs Apple account).
- Second source pose per character (back/turn) and hand poses — needs new art.
- Painted environment layers to replace procedural skylines.

## Next
### M6 · Playtest & tuning (highest value)
- Human playtest of the full route; record time-to-clear, deaths per encounter, confusing moments.
- Tune: parry window (0.17 s), elite damage (34/26) and recovery lengths, spitter cadence, crawler pounce range, campfire spacing.
- Add an options menu (volume sliders, screen shake toggle, key rebinding).

### M7 · Animation quality
- (Legs, arms, torso now rigged in-shader.) Remaining: painted in-betweens / hand poses if an artist is available. Hero locomotion: cut the ready pose into Skeleton2D parts (torso, arms, legs, robe panels, ribbons) or paint 6–8 run frames; same for grunt shamble and crawler crawl (sheet 08 already defines the 10-part split).
- Add in-between frames for combo transitions; hair-ribbon/sword-tassel secondary motion as separate bones.
- Produce the elite V1.1 sheet (docs/04 prompt) and cut its poses (raise, chop, sweep, kneel, collapse).

### M8 · Audio pass
- Audition every SFX/music loop on real speakers; rebalance; add per-zone ambience beds (crows in the village, bubbling taint, temple wind chimes, burial-mound drones); boss music layer.

### M9 · Visual polish
- Painted environment layers (Batch 3) to replace procedural ruins; foreground occluders per zone; better ground edge and campfire art.
- Hit sparks per material (flesh / armour / paper seal); boss death cinematic beat.
- Readability at 50 % scale (Tier 3) check per the art bible.

### M10 · Packaging
- Windows build test on real hardware; macOS export (needs signing decision); app icons; GitHub Release (needs owner's go-ahead — repo is public).

### Later production (out of slice scope)
- Batch 2 enemies (重型亡秽体, 小BOSS, 秽骨之王), other factions, more chapters, save system, story/dialogue using the expression sheet.
