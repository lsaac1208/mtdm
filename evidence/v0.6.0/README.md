# Evidence — Taoist Wanderer 0.6.0 (release candidate)

Linux, Godot 4.7.2; rendered checks under Xvfb with software GL (llvmpipe). **Automated checks and bots are not human approval of feel, art or audio.**

| Gate | Result |
| --- | --- |
| Engine suite (`--test=all`, source) | **84/84 PASS**, 0 script errors/warnings |
| Soak ×2 | **PASS** — 4 consecutive clears, `nodes 87->87`, `orphans 0->0` |
| Human-like bot | Normal 3/3, Story 1/1, Hard 1/1, Low graphics 1/1 — all 0 deaths |
| Exported Linux zip (unpacked) | **84/84** + human-like clear inside the package |
| Windows / macOS zips | Built; **not run on target OS** |
| Frame time (`--test=perfcap`, llvmpipe) | p50 High → Low: village 13–16 → 11–12 ms, lowland 16–17 → 13, burial wave 20–21 → 17–19, elite 21–26 → 19–20 (D42) |

New since 0.5.0 (each with an engine check): `run_save_and_continue`, `accessibility_flash_and_hints`, `rematch_flow`, `rumble_events_and_toggle`, `chapter_facade`, `graphics_quality_toggle`, `combat_quiet`.

Rendered shots (in `evidence/v0.5.0/shots/`): `title_continue.png`, `title_rematch.png`, `rematch_ending.png`, `options_accessibility.png`, `quality_high_vs_low.jpg`.

## SHA-256

```
75e310e2ea1ff4f374344508d80f5fe5f8fb6ddded6aa73699916b31670469bb  TaoistWanderer-v0.6.0-linux-x86_64.zip
81a7b35ca35cc232e80a2f01967fd804268985366907b8e6e5ac08ee21d50cc3  TaoistWanderer-v0.6.0-windows-x86_64.zip
bfaf3cbc3185c22cdafdf99ce20f5d5d2379edf8fe4c19dd3397b9d093a0d62d  TaoistWanderer-v0.6.0-macos-universal.zip
```

## Not verified
Human playtest; speaker/headphone listening (adaptive mix, hiss cue); physical gamepad (incl. vibration feel); Windows/macOS runtime and save-file location on those OSes; real-GPU frame times.
