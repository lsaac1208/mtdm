# Evidence — Taoist Wanderer 0.6.0 (release candidate)

Linux, Godot 4.7.2; rendered checks under Xvfb with software GL (llvmpipe). **Automated checks and bots are not human approval of feel, art or audio.**

| Gate | Result |
| --- | --- |
| Engine suite (`--test=all`, source) | **85/85 PASS**, 0 script errors/warnings (refreshed build at `8f1d473`) |
| Soak ×2 | **PASS** — 4 consecutive clears, `nodes 87->87`, `orphans 0->0` |
| Human-like bot | Normal 3/3, Story 1/1, Hard 1/1, Low graphics 1/1 — all 0 deaths |
| Exported Linux zip (unpacked) | **85/85** + human-like clear inside the package |
| Windows / macOS zips | Built; **not run on target OS** |
| Frame time at 1920×1080 (Low renders at 1280×720 base) | p50 High → Low: village 22.5 → 12.1 ms, elite 31.7 → 19.3; elite p95 41.6 → 24.1 |
| Frame time (`--test=perfcap`, llvmpipe, 1280×720) | p50 High → Low: village 13–16 → 11–12 ms, lowland 16–17 → 13, burial wave 20–21 → 17–19, elite 21–26 → 19–20 (D42) |

New since 0.5.0 (each with an engine check): `run_save_and_continue`, `accessibility_flash_and_hints`, `rematch_flow`, `rumble_events_and_toggle`, `chapter_facade`, `graphics_quality_toggle`, `combat_quiet`.

Rendered shots (in `evidence/v0.5.0/shots/`): `title_continue.png`, `title_rematch.png`, `rematch_ending.png`, `options_accessibility.png`, `quality_high_vs_low.jpg`.

## SHA-256

```
39689ed0884ff10418f1080482806ef26a589ef68d13d9548f29cbe512878a8d  TaoistWanderer-v0.6.0-linux-x86_64.zip
a995e43f64e99191e934dffea4544439645703a1120bd8b8bd0eea4fd5a1343e  TaoistWanderer-v0.6.0-windows-x86_64.zip
4ebc9212bb27a2c43550f4d81fe40cf68dcf4f803c6009d72560cec4de23d95b  TaoistWanderer-v0.6.0-macos-universal.zip
```
(Rebuilt from `8f1d473`, superseding the first 0.6.0 build: adds the stele gamepad-prompt fix, stele reactions, base-resolution Low mode and the fresh-install settings fix.)

## Not verified
Human playtest; speaker/headphone listening (adaptive mix, hiss cue); physical gamepad (incl. vibration feel); Windows/macOS runtime and save-file location on those OSes; real-GPU frame times.
