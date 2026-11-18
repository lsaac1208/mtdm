# 道行者 Taoist Wanderer — Vertical Slice v0.1.3

一人、一剑、一道，行于废土。 A 2D side-scrolling action demo: a lone Taoist wanders a post-apocalyptic wasteland and fights the Undead Tainted with sword, talismans, a yin-yang gourd and prayer beads.

## Play
- **Linux:** unzip `TaoistWanderer-v0.1.3-linux-x86_64.zip`, run `./TaoistWanderer.x86_64`.
- **Windows:** unzip `TaoistWanderer-v0.1.3-windows-x86_64.zip`, run `TaoistWanderer.exe`. (The Windows build has been exported but not yet run on Windows.)
- Needs an OpenGL 3.3 capable GPU (or Mesa software rendering).

## Controls
| Action | Keyboard | Gamepad |
|---|---|---|
| Move | A / D | Left stick / D-pad |
| Jump (hold for height) | K / Space | A |
| Attack — 横斩 → 下劈 → 突刺 | J | X |
| Down slash (hits low crawlers) | S + J | Down + X |
| Dash (brief invulnerability); attack during dash = dash slash | L / Shift | B / RB |
| Block (hold) · Parry (raise guard as the blow lands) | I | LB |
| Talisman 符箓 (20 Qi) | U | Y |
| Yin-Yang Gourd 葫芦 (heal + push, 3 charges, refilled at campfires) | O | LT |
| Prayer Beads 念珠 (50 Qi ring blast) | P | RT |
| Pause (controls, restart from campfire, volume) | Esc | Start |
| Fullscreen | F11 / Alt+Enter | — |

## What's in it
- Five zones: 荒村废墟 Ruined Village → 道路边缘 Road's Edge → 低洼污染区 Tainted Lowland → 废弃道观 Abandoned Temple → 乱葬岗 Burial Mound.
- Five enemy types: Undead Grunt, Crawler (too low for horizontal slashes), Talisman-Bound Husk (punishes greedy combos with a seal burst), Taint Spitter (arcing globs leave poison pools), and the Undead Warrior Elite boss.
- Six campfires (heal, refill gourd, respawn point). Typical first clear: roughly 8–15 minutes.

## Tips
- Read the wind-ups: a glint marks the moment before an attack; red ground bands show where it lands.
- Against the elite: jump the overhead chop's ground shock, dash through the sweep, punish the long recoveries. Parries break its armour faster.

## Known limitations
- Character motion is built from single concept-art poses with procedural rigging; no hand-drawn animation frames yet.
- Audio is synthesized and has not had a listening/mixing pass.
- Gamepad bindings are untested on hardware.
