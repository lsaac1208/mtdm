# 道行者 Taoist Wanderer — Vertical Slice v0.2.0

一人、一剑、一道，行于废土。 A 2D side-scrolling action demo: a lone Taoist wanders a post-apocalyptic wasteland and fights the Undead Tainted with sword, talismans, a yin-yang gourd and prayer beads.

## Play
- **Linux:** unzip `TaoistWanderer-v0.2.0-linux-x86_64.zip`, run `./TaoistWanderer.x86_64`.
- **Windows:** unzip `TaoistWanderer-v0.2.0-windows-x86_64.zip`, run `TaoistWanderer.exe`. (The Windows build has been exported but not yet run on Windows.)
- **macOS (universal, unsigned):** unzip `TaoistWanderer-v0.2.0-macos-universal.zip`, then right-click the app → Open (or run `xattr -dr com.apple.quarantine "道行者 Taoist Wanderer.app"`). The app is ad-hoc signed and not notarized; it has not been run on a Mac yet.
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

## New in v0.2.0
- Characters are now skinned cut-out rigs (Skeleton2D/Bone2D meshes from the concept art): real walk/run/jump cycles, wind-ups and recoveries, cloth that swings; every enemy has its own gait.
- Options menu: Master/Music/SFX volume, screen-shake strength, hit-stop, fullscreen, keyboard rebinding.
- Boss battle music (two phases), victory stinger, defeat cinematic; zone-specific skylines; material-specific hit effects.
- Balance pass: the Undead Warrior Elite's sweep can now be reliably jumped or dashed through.

## What's in it
- Five zones: 荒村废墟 Ruined Village → 道路边缘 Road's Edge → 低洼污染区 Tainted Lowland → 废弃道观 Abandoned Temple → 乱葬岗 Burial Mound.
- Five enemy types: Undead Grunt, Crawler (too low for horizontal slashes), Talisman-Bound Husk (punishes greedy combos with a seal burst), Taint Spitter (arcing globs leave poison pools), and the Undead Warrior Elite boss.
- Six campfires (heal, refill gourd, respawn point). Typical first clear: roughly 8–15 minutes.

## Tips
- Read the wind-ups: a glint marks the moment before an attack; red ground bands show where it lands.
- Against the elite: jump the overhead chop's ground shock, dash through the sweep, punish the long recoveries. Parries break its armour faster.

## Known limitations
- Characters are rigged from one painted pose each: no turnarounds, hands don't articulate, and the hero's base pose is three-quarter front; attack contact frames are the original painted poses.
- Audio is synthesized; it passes automated level/clipping/loop checks but has not had a human listening pass.
- Gamepad bindings are untested on hardware.
