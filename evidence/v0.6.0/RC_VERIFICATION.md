# Taoist Wanderer 0.6.0 — Playtest Release Candidate Verification

| | |
| --- | --- |
| Version | **0.6.0** (unpublished playtest RC) |
| Source | branch `claude/autonomous-v05`, commit **`9c363c8e53c9a26744a319c6d6c84bad1d3ba39b`** (all three packages built from this clean tree) |
| Engine | Godot 4.7.2.stable.official.ed1daf0bf |
| Feature scope | **Frozen** (owner directive, 2026-11-24) |
| Bundle | `build/playtest-v0.6.0/` (git-ignored): 3 ZIPs, `SHA256SUMS`, `MANIFEST.json`, playtest README / feedback template / known issues, release notes, 8 screenshots, 2:20 gameplay video |

## Platform status

| Platform | Status |
| --- | --- |
| Linux x86_64 | **BUILT + RUNTIME VERIFIED** on Linux 6.12 x86_64 (Mesa llvmpipe, Xvfb): **90/90** engine checks and a human-like full clear run *inside the unpacked package*; `native_release.py`: archive-executable / engine / normal-route / soak PASS; rendered title + village launches exit 0 with no errors using `--audio-driver Dummy` (the sandbox has no audio device — without it the only errors are ALSA `ERR_CANT_OPEN`, see `native/linux/*.log`). |
| Windows x86_64 | Local: **BUILT — RUNTIME NOT VERIFIED** (no Windows host). After publication: automated native checks PASS on a GitHub-hosted Windows Server 2025 VM (see below); real player PCs still pending. |
| macOS universal | Local: **BUILT — RUNTIME NOT VERIFIED** (no Mac host; ad-hoc signed, not notarized). After publication: automated native checks PASS on a GitHub-hosted macOS 15 arm64 VM; real Macs (incl. Intel) still pending. |

## Published release (2026-11-24)

- GitHub **Pre-release** `v0.6.0` — https://github.com/lsaac1208/mtdm/releases/tag/v0.6.0 (annotated tag → `9c363c8`; not marked latest; `main` untouched).
- All 15 assets re-downloaded (API and public direct links, HTTP 200) and byte-identical to `SHA256SUMS` / `MANIFEST.json`; GitHub asset digests match.
- Native workflow run 45347180031 on the published ZIPs: Ubuntu 24.04 x86_64, Windows Server 2025 x86_64, macOS 15.8 arm64 — digest, engine, normal-route, title, village **all PASS** (`native-ci/*.json`). Cloud VMs, not player hardware; Intel Macs not covered.

## Automated verification (source, this stabilization pass)

- `--test=all`: **90/90 PASS**, no script errors or warnings.
- Soak ×3: 6 consecutive clears, `nodes 87->87`, `orphans 0->0`.
- Human-like full clears: Chinese, English, Story, Hard, Low graphics (all cleared).
- Rendered full playthroughs reviewed frame-sheet by frame-sheet: Chinese/High and English/Low — all five zones, boss, seal, epitaph, ending.
- Aspect ratios rendered: 16:9, 16:10 (1280×800, Steam Deck), 21:9 (2560×1080).
- Audio: asset gate 75 files / 0 flagged; recorded in-game mix peak −1.35 dBFS, 0 clipped samples, no silent gaps, loudness spread 7.2 dB.
- Gamepad: menu navigation, pause, options and ending verified with **injected** pad events only.

## Fixed during stabilization

1. Menus unusable on a gamepad (A/B not mapped to Godot's UI actions) — D44.
2. Ending “Play Again” with Enter / pad A went to the title.
3. Long English hints overflowed their plate (and the boss subtitle).
4. Regression added: the General's epitaph is readable after a real boss kill.

## SHA-256

```
9937169ef90f7027b1a55c503ffb01e74696185569be1b8ece8c87decfcb748a  TaoistWanderer-v0.6.0-linux-x86_64.zip
2f7cc524b476c0be3853a2901a3253992684fc29b4617e7ec4b11bf7d96fb7f7  TaoistWanderer-v0.6.0-windows-x86_64.zip
2dc22a265cf48aec56bd97dbc5ec90a4b0ddc7af54f4d910dd49d776c650040e  TaoistWanderer-v0.6.0-macos-universal.zip
0f8402f751750e5c1594a4bb30690e4fc03da97217aec60759f357b394f702cc  gameplay-full-run-zh.mp4
```

## Not verified (human / hardware only)

Human playtest; speaker or headphone listening; physical gamepad (incl. vibration feel and Nintendo-layout A/B); Windows and macOS runtime and their save locations; real-GPU frame times for 0.6.0; native-speaker English proofreading.
