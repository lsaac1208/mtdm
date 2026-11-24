> **Final playtest RC record:** [RC_VERIFICATION.md](RC_VERIFICATION.md) (source `9c363c8`, supersedes the build sections below).

# Evidence — Taoist Wanderer 0.6.0 (release candidate)

Linux, Godot 4.7.2; rendered checks under Xvfb with software GL (llvmpipe). **Automated checks and bots are not human approval of feel, art or audio.**

| Gate | Result |
| --- | --- |
| Engine suite (`--test=all`, source) | **86/86 PASS**, 0 script errors/warnings (refreshed build at `28f3876`) |
| Soak ×2 | **PASS** — 4 consecutive clears, `nodes 87->87`, `orphans 0->0` |
| Human-like bot | Normal 3/3, Story 1/1, Hard 1/1, Low graphics 1/1 — all 0 deaths |
| Exported Linux zip (unpacked) | **86/86** inside the package |
| English mode | human-like clear with `--ui_lang=en`; prologue, hints, stele card, pause, HUD, ending rendered (`english_*.jpg/png`) |
| Windows / macOS zips | Built; **not run on target OS** |
| Frame time at 1920×1080 (Low renders at 1280×720 base) | p50 High → Low: village 22.5 → 12.1 ms, elite 31.7 → 19.3; elite p95 41.6 → 24.1 |
| Frame time (`--test=perfcap`, llvmpipe, 1280×720) | p50 High → Low: village 13–16 → 11–12 ms, lowland 16–17 → 13, burial wave 20–21 → 17–19, elite 21–26 → 19–20 (D42) |

New since 0.5.0 (each with an engine check): `run_save_and_continue`, `accessibility_flash_and_hints`, `rematch_flow`, `rumble_events_and_toggle`, `chapter_facade`, `graphics_quality_toggle`, `combat_quiet`.

Rendered shots (in `evidence/v0.5.0/shots/`): `title_continue.png`, `title_rematch.png`, `rematch_ending.png`, `options_accessibility.png`, `quality_high_vs_low.jpg`.

## SHA-256

```
d255412b5b917370f3204652ecd790d37b177810566954aa5d3778313899c217  TaoistWanderer-v0.6.0-linux-x86_64.zip
d14edeffa02d4946329c598fd8d3a2f5eae12a6b1a781d0ad295ec02c3c173bb  TaoistWanderer-v0.6.0-windows-x86_64.zip
90bfeef97bc094fe9efed1a6968b5b5fa80145e8a6eb532cd441ba9f31cee0ac  TaoistWanderer-v0.6.0-macos-universal.zip
```
(Rebuilt from `28f3876` — third build of the candidate, now with English mode — superseding earlier builds: adds the stele gamepad-prompt fix, stele reactions, base-resolution Low mode and the fresh-install settings fix.)

## Not verified
Human playtest; speaker/headphone listening (adaptive mix, hiss cue); physical gamepad (incl. vibration feel); Windows/macOS runtime and save-file location on those OSes; real-GPU frame times.
