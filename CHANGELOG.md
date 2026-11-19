# Changelog

All versions are pre-release vertical slices. Automated results were produced with software rendering. They are not human acceptance.

## 0.3.1 — 2026-11-19 (pre-release)

Branch `claude/post-codex-continuation`, based on `codex/visual-polish-v03` @ `451d4d3`.

### Verified baseline
- Before any changes, `451d4d3` passed a clean import, 52/52 engine checks and a full bot clear. A full rendered playthrough of it was reviewed.

### Fixed (presentation only; combat rules and hitboxes unchanged)
- **Guard stance:** between strikes, and while an enemy is near, the hero holds the profile sword guard. Previously the hero snapped to the three-quarter-front relaxed idle for one beat between strikes.
- **Boss-fight hint:** the hint strip moves under the boss title card instead of covering both fighters' feet.
- **Personal space:** enemies in neutral states are pushed back when the hero walks into them, so the two painted figures no longer stack. There is no push while the hero dashes or is airborne, or while an enemy attacks, so all dodge windows are unchanged.
- **Damage numbers:** numbers on the same target stack upward instead of overprinting.
- **End gate:** the flat black rectangles are replaced by a shaded stone pailou (archway) with eaves, a plaque and ground mist.
- **Encounter ward:** the full-height "ladder" is replaced by light rising from a ground seal and fading upward, with four hanging talismans.
- **Particles:** particles are soft round dabs instead of hard squares.
- **Hit stains:** stains are translucent and soaked into the ground instead of opaque black ellipses.
- **Platforms:** each platform takes its zone's light tone, has a contact shadow and keeps the painting's proportions instead of being squashed horizontally.
- **Taint pools:** a taint pool no longer dyes the whole costume olive. The point light is halved and desaturated, with a light tint and vapour wisps instead.
- **Menus:** one ink-and-cinnabar UI skin (`InkTheme`) now covers the title, pause and options screens.
- **HUD portrait:** the portrait is cut to a disc so it sits inside its ring.
- **Boss-sealed card:** the English line uses the body serif. The brush font has no proper Latin glyphs.

### Tests and tooling
- New engine checks `guard_stance` and `personal_space` (54 in total).
- New capture modes `titlecap`, `gatecap`, `sealcap` and `platcap`.
- New script `tools/qa/smoke.sh` runs a local verification in one command.
- Evidence is in `evidence/v0.3.1/`. Handoff notes are in `HANDOFF.md`.

### Pending
- Windows and macOS packages have not been run on their target systems.
- Human playtest, physical controller and audio listening are still to do.
- Real-GPU performance has not been measured.

## 0.3.0-rc.1 — 2026-11-19 (pre-release, Codex)
Visual polish: painted zones, new hero poses, three difficulties and dynamic key prompts. Built from `93cee6d`. The later Codex commit `451d4d3` added frame-by-frame animation, 2.5D lighting, combat feel work and new title and ending screens. Those changes ship for the first time in 0.3.1.

## 0.2.0 — 2026-11-19 (pre-release)
Skinned cut-out rigs, options menu, telemetry-based balance, boss music and the macOS universal export.
