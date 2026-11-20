# Evidence — Taoist Wanderer (道行者) v0.4.0 Pre-Commercial Demo

Verified on Apple Silicon (`macOS-27.2.1-arm64`, `Apple M6`, Godot `4.7.2.stable.official.ed1daf0bf`, Metal `1280×720`).

![v0.4.0 Showcase](showcase.jpg)

## Verification Summary

| Gate | Result | Details |
| --- | --- | --- |
| Engine suite (`--test=all`, source) | **63/63 PASS** | Zero `SCRIPT ERROR`, `ERROR:`, or exit leaks (`spec_conformance` 21/21, `hero_anim_no_pops` `12.4 px`, destructibles, diegetic enemy UI, 5-enemy `FrameAnim`, prologue, whispers, rank persistence) |
| Full route & soak (`--test=soak`, source) | **3/3 PASS** | Two consecutive 0-death Normal clears (`rank=甲`, 24 kills each); `soak_no_leak PASS` (`nodes 86->86`, `orphans 0->0`) |
| Hero footwork (`tools/qa/hero_footwork.gd`) | **PASS** | `move_right` & `move_left`: `frame_anim=true`, `floor_gap_px=0.0` |
| Audio review (`tools/audio/audio_review.py`) | **75/75 PASS (0 flagged)** | `44.1 kHz`, 30 stereo + 45 mono (`26.14 MB`), max peak `-1.00 dBFS`, max loop seam `0.0115`, min stereo corr `0.16` |
| Five-zone Metal readability (`1280×720`) | **15/15 PASS** | All 5 zones (combined, hero, and every enemy independently > 47 contrast and > 570 px at 33%); see [READABILITY.md](readability/READABILITY.md) |
| Real-GPU frame time (`Apple M6` Metal `1280×720`) | **Verified** | `village` melee: `p50=2.38 ms / p95=3.39 ms / p99=4.56 ms`; `lowland`: `p50=1.91 ms / p95=2.57 ms / p99=3.90 ms`; `elite` boss: `p50=2.10 ms / p95=2.65 ms / p99=3.80 ms` |
| Native macOS `.app` package (`native_release.py`) | **4/4 PASS** | Unpacked `TaoistWanderer-v0.4.0-macos-universal.zip`: `engine` (63/63 PASS), `normal-route` (0 deaths, 24 kills, 6 parries, `02:00`, `rank=甲`), rendered `title` & `village` all PASS with zero errors; see [native/macos/native.json](native/macos/native.json) |
| Windows / Linux `v0.4.0` packages | **Built, target-OS pending** | Exported and checksummed; target OS launch verification pending |

## Release Packages (`build/SHA256SUMS.txt`)

- `TaoistWanderer-v0.4.0-macos-universal.zip` (`119 MB`) — `b9692376dbf6b21f34fefda713c9cc50ba22c41bcf529f279992bc91619b55e6`
- `TaoistWanderer-v0.4.0-windows-x86_64.zip` (`96 MB`) — `31f31f9b4ec3fe304741ab4e59438b595c022a74786f8c8c32435abf1121b451`
- `TaoistWanderer-v0.4.0-linux-x86_64.zip` (`86 MB`) — `85c3a108c7fdbdc34a5f5e444ea58e969c950e7b208ddeee845766ea4208a75b`
