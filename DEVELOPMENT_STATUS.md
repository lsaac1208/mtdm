# DEVELOPMENT_STATUS — 道行者 / Taoist Wanderer

## 稳定化阶段（当前 · 功能冻结）

_2026-11-24 · 项目方指令：停止功能扩展，进入稳定化与发布候选准备。_

- 冻结后修复：手柄无法操作菜单（Godot 默认 ui_accept/ui_cancel 无手柄键，D44）；结算「再行此道」用 Enter/A 误回标题；英文长提示溢出提示牌（Boss 布局下压住副标题）。
- 新增回归：`pad_menu_navigation`、`pad_pause_menu`、`pad_ending_play_again`、`epitaph_readable_after_boss`，长提示适配断言。共 90 项。
- 视觉复查：中文/标准画质与英文/精简画质各一次完整渲染通关，五区、Boss、结算均已目检；16:10 与 21:9 已检查。
- 音频：资源门禁 75/0；实录混音峰值 −1.35 dBFS、0 削波、无静音断档。
- 试玩包文档：`playtest/`（安装、操作、首玩指引、反馈表、已知问题）。

## 0.6.0 候选版（未发布）

_2026-11-23 · 分支 `claude/autonomous-v05`（0.5.0 候选之后）_

- 已完成：篝火存档 + 标题「继续」；闪屏强度与教学提示开关；通关后「再战尸将」挑战（分难度本地最佳，与主线存档隔离）。
- 已验证：`--test=all` 80/80；soak 无泄漏；拟人机器人通关；标题（含继续/再战）、设置页、再战结算均已渲染检查（`evidence/v0.5.0/shots/`）。
- 未验证：真人试玩、扬声器听感、实体手柄、Windows/macOS 实机。
- 另含：英文模式（游戏内全部可读文字，D43）、读碑心声、精简画质按 1280×720 渲染、手柄震动、多章节数据外观层、精简画质与 perfcap、战斗中残碑/Boss 标题清爽化。版本号 0.6.0，三平台包已构建，验收见 [evidence/v0.6.0/README.md](evidence/v0.6.0/README.md)（当前构建：源码与导出包均 86/86）。
- 阻塞（外部依赖）：真人试玩调校、第二章新美术、Windows/macOS 实机。公开发布需项目方授权。

## 0.5.0 候选版（未发布）

_2026-11-23 · 分支 `claude/autonomous-v05`（基于 `codex/demo-v0.4.0` @ `bd25e07`）· Godot 4.7.2_

- 已完成：输入缓冲 + 空中冲刺限一次；敌群排队防叠影；尸将体积阻挡；教学提示学会即收；五块可读残碑（尸将墓志于 Boss 战后升起）；修复 v0.4.0 起就存在的伏爬者扑击软锁（soak 29 死的根因）。
- 已验证（本机 Linux，软件 GL）：`--test=all` 74/74；soak ×4（8 次连续通关，`nodes 86->86 orphans 0->0`）；拟人机器人多次通关（0–1 死）；渲染截图前后对照见 `evidence/v0.5.0/shots/`；Linux 导出包（`package.py 0.5.0-dev linux`）解压后包内 74/74 + 机器人通关；新版完整渲染录像（拟人机器人）已复查。
- 界面渲染审查（标题/暂停/设置/结算）：修复行旅录新增行溢出压住按钮；操作卡加入「读碑」。
- 难度曲线遥测（拟人机器人 ×6，伤害/局）：荒村 1.7 → C 组 41.8 → 尸潮 43 → 尸将 110.7（0.33 死/局），Boss 为峰值；乱葬岗尸潮新增瘴吐者，终局波次远近混合；道观 B 组改为封印残尸双人组（伤害 16.9→36.7/局，0 死）；敌人定格帧加入蓄力颤动/喘息。
- 已构建 `0.5.0-dev` Windows/macOS 包（build/，未入库）。
- 未验证：真人试玩、扬声器听感、实体手柄、Windows/macOS 实机运行（无对应系统）。
- 0.5.0 候选：版本号已升至 0.5.0，三平台包已构建，完整验收见 [evidence/v0.5.0/README.md](evidence/v0.5.0/README.md)；公开发布需项目方授权。
- 下一步见 ROADMAP「0.5.0」。


## 0.4.0 序章商业试玩版（当前）

_2026-11-20 · 分支 `codex/demo-v0.4.0`（基于 `claude/post-codex-continuation` @ `8eb690d`）· Godot 4.7.2 · 版本 0.4.0_

当前画面与叙事系统：全角色（主角 21 片段 + 五类敌人共 41 片段）统一采用 `FrameAnim` 逐帧手绘图集 + 烘焙 2.5D 法线/厚度/AO 贴图（`PoseSprite` 与 `CutoutRig` 仅作回退）；五区配备手绘风化道家石牌坊通关门、10 处可斩碎道力道具（陶罐/木箱/暖光香炉）、四套底景水墨视差与篝火点燃演出；新增三幕可跳过水墨开场序章、六表情头像五区非阻塞默语、统一墨金全链路菜单与「行旅录」甲/乙/丙印章评级存档；全套 75 个音乐/环境/音效升格为 44.1 kHz（30 立体声 + 45 单声道）。

- 已验证：源码 63/63 引擎检查零报错、双轮常规通关 soak 零泄漏（`nodes 86->86` / `orphans 0->0`）、步态贴地 `floor_gap_px=0.0`、75/75 音频复检 `0 flagged`、Apple M6 Metal `1280×720` 五区可读性 15/15 PASS、真机帧时 `p50=1.91–2.38 ms`、以及解压后原生 macOS `.app` 四项全绿（`engine` / `normal-route` / `title` / `village`）。
- 本版验收与实机总览：[evidence/v0.4.0/README.md](evidence/v0.4.0/README.md) · 英文交接文档：[HANDOFF.md](HANDOFF.md) · 变更日志：[CHANGELOG.md](CHANGELOG.md)。
- 未验证：Windows 与 Linux `v0.4.0` 包待目标系统实机桌面验证；真人盲测、实体手柄手感与扬声器听感终审待执行。
- 下一步见 [ROADMAP.md](ROADMAP.md) 的 `0.4.0` 商业化与第二章规划。

## 0.3.1 接手版（历史）

_2026-11-19 · 分支 `claude/post-codex-continuation`（基于 `codex/visual-polish-v03` @ `451d4d3`）· Godot 4.7.2 · 版本 0.3.1_

当前画面系统：`FrameAnim`（逐帧手绘图集 + 2.5D 法线/厚度/AO，负责移动、跳跃、待机与敌人循环）＋ `PoseSprite`（原画姿势，负责出招关键帧）＋ `CutoutRig`（仅作缺图回退）。三者由 `RigVisual` 统一调度。

- 已验证：基线 52/52 + 通关；本分支（`72714c7`）54/54，机器人完美与拟人模式多次通关；Linux 导出包内 54/54 + 通关 + 渲染截图；最终完整渲染录像复查。
- 本轮修复与前后对照：[evidence/v0.3.1](evidence/v0.3.1/README.md)。
- 未验证：Windows、macOS 包未在对应系统运行；无真人试玩与实体手柄测试；音频未经人耳试听。
- 已知问题与下一步见 [ROADMAP](ROADMAP.md) 的 0.3.1 段落。

## 0.3 视觉打磨版（历史）

当时开发分支为 `codex/visual-polish-v03`。三档难度、九个主角新姿势、五区绘景、动态按键提示和场景退出修复已接入。查看[验收记录](evidence/v0.3/README.md)和[候选包](https://github.com/lsaac1208/mtdm/releases/tag/v0.3.0-rc.1)。以下为上一个发布基线的历史记录。

_Last updated: 2026-11-19 (v0.2.0) · branch `dev/vertical-slice-20261118` · engine Godot 4.7.2 · version 0.2.0_

## Where things are
| Path | What |
|---|---|
| `game/` | Godot project (open `game/project.godot`) |
| `game/scripts/actors/` | `actor.gd` (shared body), `player.gd` (13-pose combat FSM), `pose_sprite.gd` (key-pose renderer) |
| `game/scripts/enemies/` | `enemy.gd` base + `grunt`, `crawler`, `husk`, `spitter`, `elite` |
| `game/scripts/core/` | autoloads: `game.gd` (input map, flow, hit-stop, dev flags), `combat.gd` (hit resolver), `sfx.gd` |
| `game/scripts/level/` | `level_data.gd` (route, encounters, signs), `level.gd` (builder, camera, parallax, respawn), `encounter.gd`, `barrier.gd`, `checkpoint.gd`, `end_gate.gd` |
| `game/scripts/fx/`, `game/shaders/` | slash/ring/telegraph VFX, talisman + taint projectiles, puddles, sprite + atmosphere shaders |
| `game/scripts/ui/` | title, HUD, pause menu, ending |
| `game/tests/test_runner.gd` | engine-level checks, playthrough bot, showcase captures |
| `tools/art/` | `extract.py` + `sprites.json` (pose cut-outs), `make_env.py` (environment art), `segment.py` |
| `tools/audio/make_audio.py`, `tools/build/make_fonts.py` | audio + font generation |
| `build/` (git-ignored) | exported binaries and zips |

## Published
- **v0.2.0 pre-release**: https://github.com/lsaac1208/mtdm/releases/tag/v0.2.0 — tag `v0.2.0` → `e312e39` (the validated commit); 3 assets (Linux / Windows / macOS universal), SHA-256 in the release notes and identical to the acceptance-run builds. The downloaded Linux asset was re-run end to end (bot clear). Windows/macOS runtime still unverified. `main` untouched.

## v0.2.0 — what changed and how it was verified
- **M7 animation (done):** real skinned cut-out rigs for the hero and all five enemies (`Skeleton2D`/`Bone2D`, weighted `Polygon2D` meshes built by `tools/rig/make_rig.py`, `AnimationPlayer` clips with crossfades, spring cloth). Hero: idle/walk/run/jump/fall/land/hit/block/dash/dead + attack wind-ups/recovery; enemies: distinct gaits (lurching shamble, ritual step, hunched waddle, heavy stomp, quadruped scuttle), wind-ups, elite rig-driven sweep, kneel, roar, death. Verified by frame-by-frame captures (`rigcap`, `combocap`, `walkcap`, `chopcap`, `crawlcap`, `jumpcap`) and tests (`hero_anim_no_pops`, `spec_conformance` heights). Painted concept poses remain as attack contact frames.
- **M6 gameplay (done):** options menu (3 buses, shake, hit-stop, fullscreen, key rebinding; live key names in hints); run telemetry + `tools/telemetry_report.py`; balance pass (docs/BALANCE.md: human-like bot deaths 21 → 6 over 10 runs; elite 1.8 → 0.2 deaths/run); `elite_fairness` (sweep-jump window 0.36 s, dash windows 0.18 s); enemies hop ledges.
- **M8 audio (done, not human-heard):** category loudness normalization + −1 dBFS soft limit, seamless loops, two-phase boss music, boss/victory stingers, Music/SFX buses; `tools/audio/audio_review.py` (13 flagged → 0); in-game boss mix recorded: −4.2 dBFS peak, 0 clipped (docs/audio_review/).
- **M9 visuals (done):** zone-specific parallax skylines (village/road/lowland/temple/burial) with border crossfades; material hit effects (flesh/paper/taint/armor debris); boss defeat cinematic (slow-mo, flash, letterbox, 镇 seal); reduced-scale readability gate (`tools/readability.py`).
- **M10 delivery (done where possible):** Linux, Windows and macOS (universal, ad-hoc signed) packages via `tools/build/package.py`; acceptance gate now 14 checks.

## Acceptance evidence
Run `GODOT=<godot> tools/acceptance.sh <version>` — it runs every executable gate and writes `evidence/acceptance-<date>/REPORT.md` (gates table, spec rows, test list, FPS, rendered frames, contact sheet). Latest: `evidence/acceptance-20261119/` at commit `e312e39` (v0.2.0) — **14/14 gates PASS**: 50 engine checks in source and inside the exported Linux binary; 3 perfect + 3 human-like bot clears (human-like: 0 deaths in all 3); audio review 62 files / 0 flagged; soak (nodes 38→38, 0 orphans); Linux + Windows + macOS packages; exported-build bot clear; readability ≥ 31 ΔL at 33 % scale in all 5 zones; 50 rendered frames.

## Implemented and verified
**Flow:** title → level (5 zones, 6 campfires, 9 encounters) → elite boss → light gate → ending screen with time/deaths/kills/parries → back to title. Pause menu (resume / restart from campfire / title / volume slider). Death → "身陨" card → fade → respawn at last campfire; failed encounters reset, cleared ones stay cleared.

**Player (spec docs/02, docs/05):** run 260 px/s, variable jump, coyote + buffered input, dash 540 px/s with i-frames (+1 air dash), 3-hit combo 横斩→下劈→突刺, `S+J` down slash, dash slash (low), jump attack (low, small pogo on hit), hold-block with 0.17 s parry window (parry staggers enemies, +Qi, hit-stop), talisman (homing, 20 Qi, ignites), gourd (3 charges: +35 HP + knock-back gust), prayer beads (50 Qi, charge with super armour → 210 px ring AOE, purifies puddles), hit reaction, death. HP/Qi/gourd HUD.

**Enemies:** all five, each with a distinct FSM:
- Grunt — wander → alert → shamble → 0.4 s lean-forward wind-up (glint telegraph) → lunging claw → recovery; any hit staggers.
- Crawler — lurks (dimmed), 92×46 hurtbox, rears up, crawls 215 px/s, 0.26 s crouch telegraph + danger band, low pounce, scuttles back; flips on hit.
- Talisman-Bound Husk — stands sealed until approached/struck, awakens, slow armoured advance, sleeve strike; 4 melee hits → glowing seal → unblockable 符力溃散 burst. Ranged hits don't build pressure.
- Taint Spitter — keeps 220–520 px range, glowing throat-sac wind-up 0.9 s (interruptible by poise ≥ 12), parabolic glob → 4.5 s taint puddle (slow + corrosion), long recovery, weak swipe up close.
- Undead Warrior Elite — super armour + poise meter, 0.8 s chop (+ low ground shock to jump), 0.65 s sweep (40–128 px band), long recoveries, parry/poise break → 1.8 s kneel with bonus damage, phase 2 at 50 % (faster, chains, 2-grunt summon). Boss bar with armour meter.

**Presentation:** 50 concept-art pose sprites with ink contour + pale paper halo (figure/ground separation), shader skeletal rig per pose: two-bone legs (hip/knee) plus arm bones from `assets/sprites/rig.json` (shoulder pivot, hand, weapon tip; inpainted where the limb leaves) — legs, arms, torso move in walk/run/idle, the sword arm sweeps through every attack, enemy weapon arms raise and swing, knee-tuck airborne pose, hit jitter + ground ink splats + camera zoom-punch, cross-fades, lean/squash, stride/sway/breath shader, hit flash, ink-burn deaths; sword-qi brush arcs, telegraph glints, danger bands, rings, particles, hit-stop, screen shake; parallax ink-wash wasteland with per-zone tint + fog + vignette/grain + ambient particles (dust/ash/spores/embers), cracked-earth ground with debris; brush-font zone cards, boss intro card, tutorial hint strip from roadside steles; generated SFX + 4 pentatonic music loops + 5 zone ambience beds (wind, crows, bubbling taint, wind chimes, burial groans) with crossfades; title and ending screens.

### Verified results (this session)
- `--test=all`: **50/50 checks pass** (incl. settings persistence, soak/no-leak (separate gate), 21-row spec conformance vs docs/05, animation-continuity (no pose pops), enemies-cross-ledges, spawns-on-surfaces guard, flow: pause-restart keeps progress, ending→title→new run resets state, no stale actors) (movement, jump, dash, crawler band whiff/hit with slash vs down/dash slash, grunt stagger + combo kill, timed parry, husk seal burst + punishment + talisman no-pressure, spitter glob → puddle, talisman interrupts spitter wind-up, elite wind-up 0.80 s and armour vs light hits, death → respawn at campfire, encounter lock/barrier/clear, scripted clear of every encounter → ending scene). No script errors.
- `--test=bot` (input-only scripted player, full route from the title flow): completes the current route in 3 of 3 runs (0–1 deaths, 24–27 kills, ≈2:15–3:00 game time for the bot). Also passes **on the exported Linux binary**.
- Full-length rendered playthrough recorded (movie writer, 161 s) and reviewed as a contact sheet; found & fixed: enemy hit-flash whiting out the whole silhouette, spitter spawning inside a rock ledge (could soft-lock Group C).
- Audio integration verified by recording the mixed output with Godot's movie writer during a bot run (music + SFX present; peaks now limited by a master compressor/limiter). Not yet listened to by a human.
- Difficulty proxy: `--bot_skill=human` (≈180 ms reaction cadence, 25 % missed defensive reads) cleared 6/6 runs with 0–7 deaths (mean ≈2.8); most deaths are at the elite, the rest at Groups A/C. A real first-time player will likely die more (the bot reads enemy state perfectly).
- Performance: 55–65 FPS at 1280×720 on CPU software GL (llvmpipe) during the burial-mound wave.
- v0.1.2 exported Linux binary: 38/38 checks and full bot clear run *inside the exported build*.
- Re-verified after the latest polish commit: 33/33 checks, bot clears on source and on the re-exported Linux binary.
- Rendered captures under Xvfb (software GL): title, all five zones, every enemy's telegraph/attack, VFX, ending screen were inspected.
- Packages: `python3 tools/build/package.py 0.1.2` → `build/TaoistWanderer-v0.1.2-{linux,windows}-x86_64.zip` (41 / 50 MB).
- Exports: `build/linux/TaoistWanderer.x86_64` (verified: runs, renders, bot completes) and `build/windows/TaoistWanderer.exe` (**built but not run** — no Windows here; installing Wine was not permitted in this environment).

## Not verified / known limitations
- **No human playtest yet.** Feel (timing windows, difficulty, readability at speed) is tuned from specs and bot runs only. Bot clear time (~2 min) means a first-time human run is probably ~8–15 min.
- **Audio never heard by a human** — mix verified numerically/spectrally from a recorded run only.
- **Motion is single-pose rigging** (legs, arms, torso deformed from one painted pose per state; attacks blend 2 key poses + arm sweep). Hands and cloth don't deform independently and there are no painted in-betweens; it reads as cut-out animation, not frame-by-frame.
- Software GL only here; real-GPU frame rate untested (the game is light: sprites + a few shaders).
- Elite uses the V1.0 sheet images (V1.1 corrected sheet not produced yet).
- Environment art is procedural, not painted; ruins can look blocky up close.
- Some enemy cut-outs keep small parchment specks between rags; the crawler/husk sheets' pose rows are lower-resolution than the hero's.
- Gamepad: every binding verified by injecting joypad events in-engine (`gamepad_actions_fire`); not tried on a physical pad.
- Windows export unrun (no Windows; Wine install not permitted). macOS universal .app exported, ad-hoc signed, not notarized, not run on a Mac.

## Session-3 changes
Talisman pose was mirrored (threw away from facing) — fixed; arm bones for talisman/gourd/block; settings persistence; soak gate.
Arm bones (rig.json) for hero + grunt/husk/spitter/elite; attack arm curves; idle/run/air arm motion; elite cleaver raise/chop/sweep; ledge-hop for enemies (fixed crawler stall); spec-conformance, anim-continuity, ledge tests; outline sampling optimisation; acceptance.sh + evidence; v0.1.3.

## Session-2 changes (for reviewers)
Leg rig + torso twist + knee-tuck jumps; enemy cut-out cleanup; hit jitter/splats/zoom-punch/smears; topple/kneel deaths; elite chop two-beat wind-up; ground strata + debris; parallax seam fix; ambient particles; zone ambience beds with crossfades; master limiter; Road's Edge campfire; dash i-frames 0.24 s; spawn-on-surface fix (Group C soft-lock); opening epigraph; F11 fullscreen; package.py; RELEASE_NOTES.md.

## Next concrete tasks
See `ROADMAP.md` (M6 onward). Top three: human playtest + tuning pass; real locomotion animation (hero run cycle, grunt shamble) via Skeleton2D cut-outs or painted frames; audio audition/mix pass.
