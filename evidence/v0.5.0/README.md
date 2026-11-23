# Evidence — Taoist Wanderer 0.5.0 (release candidate)

Verified on Linux (Godot 4.7.2, software GL / llvmpipe under Xvfb for rendered checks). **Automated checks and bot runs are not human approval of feel, art or audio.**

## Verification summary

| Gate | Result |
| --- | --- |
| Engine suite (`--test=all`, source) | **77/77 PASS** (63 from v0.4.0 + 14 new), zero script errors |
| Soak (`--test=soak`) ×2 | **PASS** — 4 consecutive clears, `nodes 86->86`, `orphans 0->0` |
| Human-like bot (`--bot_skill=human`) | Normal 4/4 clears (0 deaths), Story 1/1, Hard 1/1 (1 death) |
| Exported Linux package (`TaoistWanderer-v0.5.0-linux-x86_64.zip`, unpacked) | **77/77** + human-like clear inside the package |
| Windows / macOS packages | Built (`windows-x86_64` 95 MB, `macos-universal` 118 MB); **not run on target OS** |
| Audio asset gate (`audio_review.py`) | 75 files, 0 flagged |
| Recorded in-game mix (full run) | peak −1.01 dBFS, 0 clipped samples, loudness spread 6.8 dB (was 5.3) |
| Rendered review | full human-like playthrough movies + targeted captures (`lorecap`, `defeatcap`, `elitecap`, UI screens) |

## Before / after (same harness)

| Defect / feature | Measure | v0.4.0 | 0.5.0 |
| --- | --- | --- | --- |
| Crawler pounce soft-lock | camping frames (`crawler_retreats_after_pounce`) | 284 | 0 |
| Unlimited air dash | second air dash allowed | yes | no |
| Dash pressed during attack | honoured | no | yes |
| Enemy pile-up at slab | stacked frames (`pack_spreads_at_ledge`) | 54 % | 0 % |
| Hero inside elite armour | closest distance (`boss_body_block`) | 1 px | 79 px |
| Crawler tell (Normal) | crouch → pounce | 0.26 s | 0.33 s (+ hiss) |
| Crawler pounce damage | human-like bot, per run | 51.7 | 38.8 |

## Shots

- `shots/burial_pack_stacked_v040.jpg` — v0.4.0 crawler blob at a grave slab
- `shots/boss_body_before_after.jpg` — hero vs elite armour, before/after
- `shots/lore_steles.jpg` — steles and reading card
- `shots/ledger_controls_fix.jpg` — Journey Ledger overflow fix, controls card
- `shots/burial_wave_spitter.jpg` — finale wave with spitter
- `shots/temple_husk_duo.jpg` — temple group B
- `shots/boss_defeat_card_before_after.jpg` — seal card no longer covers the fall

## Package checksums (SHA-256)

```
0ebd81eeac9fdc0bed85543bf3c44e977789a8d0a36a28167d8452a2619e7e38  TaoistWanderer-v0.5.0-linux-x86_64.zip
1ed6143223d47209e0842c8a32e3c972052c58d01cd824689c0584d97064f540  TaoistWanderer-v0.5.0-windows-x86_64.zip
1af6c6b315140d4d04b9122b5246df2fb2f9eda93d08c0fe8c1a52e0eecbc3ba  TaoistWanderer-v0.5.0-macos-universal.zip
```
(`build/` is git-ignored; rebuild with `GODOT=... python3 tools/build/package.py 0.5.0`.)

## Not verified

Human playtest, speaker/headphone listening (incl. the new hiss cue and adaptive mix), physical gamepad, Windows and macOS runtime, real-GPU frame times for 0.5.0.
