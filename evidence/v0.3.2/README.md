# Evidence — Taoist Wanderer (道行者) v0.3.2

Branch: `codex/v032-continuation` (branched from `origin/claude/post-codex-continuation` @ `8eb690d`).  
Engine: Godot `4.7.2.stable.official.ed1daf0bf` (GL Compatibility on Apple Silicon Metal).  
Hardware: Apple Silicon Mac (`macOS-27.2.1-arm64`, `Apple M6`, `OpenGL API 4.1 Metal - 91.7`).

## Summary of v0.3.2 changes

1. **Full frame-by-frame hero combat, guard & skill animations (`FrameAnim`)** — generated transparent RGBA sheets (`hero_guard_idle_sheet.png`, `hero_slash12_sheet.png`, `hero_slash3_dash_sheet.png`, `hero_skills_sheet.png`), added connected-component gutter-bleed cleanup in `tools/art/build_anim_sheets.py`, and baked paired 2.5D normal/thickness/AO maps (`*_n.png`) for all 21 hero clips (`guard_idle`, `guard_to_idle`, `slash1`, `slash2`, `slash3`, `dash`, `dash_attack`, `jump_attack`, `talisman`, `gourd`, `beads_a`, `beads_b`). Worst-case body-centre jump in `hero_anim_no_pops` dropped from `32.9 px` to `16.7 px`.
2. **Seamless combat-to-idle sheathing transition** — `Player` now plays animated `guard_idle` between strikes and `guard_to_idle` (3 frames, `0.34 s`) when combat ends before returning to `idle`, eliminating the single-frame angle snap.
3. **Upgraded ink-and-brass HUD & 3-state dynamic portraits** — extracted centered `256×256` RGBA bust portraits (`portrait.png`, `portrait_combat.png`, `portrait_hurt.png`) from `concept_art/03_protagonist_expressions_mood.png` via `tools/art/extract_portraits.py`; rebuilt HUD plaques with `StyleBoxFlat` brass brackets, HP damage-lag trail & low-HP pulse, Qi threshold pins (`20` / `50`), warm-parchment skill medallions (`葫芦` / `符箓` / `念珠`), and matching Boss Bar with 50% phase tick and poise gauge.
4. **Wall-pinned personal-space separation** — `Enemy._safe_nudge_x` prevents pushing enemies into walls/leashes and transfers the un-yielded remainder to the grounded hero while leaving dash-through, jump-over, and enemy attack timings unchanged (`open=33 px, pinned=34 px, dash_past=true`).

## Verified results (real Metal GPU & native macOS `.app`)

| Check | Scope | Result |
| --- | --- | --- |
| `tools/qa/smoke.sh` (source) | Clean import + 54 engine checks + Normal bot | **54/54 PASS**, `DEMO_COMPLETE time=02:17 deaths=0 kills=24 parries=3`, zero script/leak errors |
| `tools/qa/hero_footwork.gd` | Right & left locomotion | **PASS** (`floor_gap_px=0.0`, `frame_anim=true`) |
| `hero_anim_no_pops` | Full combo/jump/run continuity | **PASS** (`16.7 px < 40.0 px`) |
| `guard_stance` | `slash1` FrameAnim + `guard_idle` → `guard_to_idle` → `idle` | **PASS** (`slash=true guard=true relax=true idle=true stack_dy=26`) |
| `personal_space` | Open ground + real `x=880` wall pin + dash-through | **PASS** (`open=33 pinned=34 dash_past=true`) |
| Five-zone readability (`readcap` + `tools/readability.py`) | Metal `1280×720` across all 5 zones | **15/15 PASS** (see [readability/READABILITY.md](readability/READABILITY.md)) |
| Real-GPU frame time (`wave`, Metal `1280×720`) | Multi-enemy burial brawl (`3501` frames) | `p50=2.45 ms`, `p95=3.70 ms`, `p99=4.48 ms` |
| Real-GPU frame time (`elite`, Metal `1280×720`) | Boss fight (`2997` frames) | `p50=2.14 ms`, `p95=2.74 ms`, `p99=3.42 ms` |
| Native macOS `.app` (`tools/qa/native_release.py`) | `ditto` unpack, `codesign --verify --deep --strict`, `engine` (54/54), `normal-route`, rendered `title` & `village` | **ALL PASS** (see [native/macos/native.json](native/macos/native.json)) |

## Visual artifacts

- [comparison.jpg](comparison.jpg) — `66db6bc` vs `v0.3.2` (Metal `1280×720`) across village entry, lowland taint pool, and elite boss fight with upgraded Boss Bar.
- [hero_combat_sheet.jpg](hero_combat_sheet.jpg) — anchored frame audit of `guard_idle`, `guard_to_idle`, `slash1`–`slash3`, `dash_attack`, `jump_attack`, `talisman`, `gourd`, and `beads`.
- [readability/READABILITY.md](readability/READABILITY.md) — 5-zone independent hero/enemy readability metrics.
- [native/macos/title/shot_00.png](native/macos/title/shot_00.png) & [native/macos/village/village.png](native/macos/village/village.png) — rendered output from the exported macOS `.app`.

## Build artifacts (`build/`, git-ignored)

| Archive | Size | SHA-256 | Native verification |
| --- | ---: | --- | --- |
| `TaoistWanderer-v0.3.2-macos-universal.zip` | 109 MB | `787b5371f4a7a95eff0a95b13a8331770a51d89d7d050e93072f1d2e87158109` | **PASS on Apple Silicon macOS** |
| `TaoistWanderer-v0.3.2-windows-x86_64.zip` | 86 MB | `bf380b129067591669897bf852abfb49f09fae2ac5fb3c6bbc9384fb995e2259` | Pending (needs Windows) |
| `TaoistWanderer-v0.3.2-linux-x86_64.zip` | 76 MB | `29de04682eb0e3ed4101fead36e0e1e85da800183f15c8b29335b9423396fdd3` | Pending (needs Linux) |

## Still pending
- Windows and Linux package native runs on their target OSes.
- Human playtest, physical gamepad feel test, and speaker audio audition.
