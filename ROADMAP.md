# ROADMAP — 道行者 / Taoist Wanderer

## 0.6.0（进行中）— 可续玩与长期体验
目标：让真人玩家能中断、再来、反复游玩序章，并为第二章做技术准备。
1. 篝火存档 + 标题「继续」（已完成）。
2. 进阶/重玩：通关后解锁「再战尸将」挑战 + 分难度本地最佳（已完成）。
3. 设置补全：闪屏强度与教学提示开关（已完成）；手柄震动待做（无实体手柄，仅能注入事件验证）。
4. 第二章技术预研：关卡数据多章节化（LevelData 拆分），不新增美术前不做内容承诺。


## 0.5.0（进行中，分支 `claude/autonomous-v05`）
已完成：手感（输入缓冲、空中冲刺）、敌群可读性、Boss 体积、上下文教学提示、残碑环境叙事、伏爬者软锁修复。
待办（按优先级）：
1. ~~渲染全流程复查新版本~~（已完成，并据此修复结算界面溢出）。
2. 音频：自适应混音（已完成，待真人试听）。战斗反馈：敌人受击反应（单帧受击图 → 程序化后仰/滑步/墨溅分级）、Boss 前摇音效层次。
3. 内容：在不新增美术前提下扩展遭遇 —— 乱葬岗尸潮加入瘴吐者（已完成）；道观封印残尸双人组（已完成）；敌人定格帧程序化生命感（已完成）。尸将死亡演出（已完成：镇印卡上移，不遮挡倒地）。下一步：伏爬者扑击前摇可读性复核（已完成：0.32 s + 嘶声，难度缩放前摇）。
4. 打包 Linux/Windows/macOS 0.5.0 并在 Linux 导出包内跑全套检查。
5. 文档与发布说明；公开发布需项目方明确授权。


## 0.4.0 序章商业试玩版（当前已发布预发布版）
已完成（见 [evidence/v0.4.0](evidence/v0.4.0/README.md)）：
- **世界纵深与可破坏交互**：通关光门升级为手绘风化道家石牌坊配门后金光柱；五区布置 10 处可斩碎道具（封符陶罐/八卦木箱/铜香炉）与飞灵回气；新增 4 套分区水墨底景视差与篝火首次点亮光柱。
- **全敌人多帧手绘战斗动画与战斗反馈**：五类敌人战斗动作全部升级为逐帧手绘 + 2.5D 法线图（共 41 个敌人片段 + 主角 21 个片段）；新增非 Boss 敌人受伤血量/架势小条、封印残尸胸符裂纹预警、尸将二阶段狂煞气场与弹反/残影/尘土/回血全套演出。
- **序章叙事、六情默语与商业级菜单**：三幕可跳过水墨开场序章、六表情头像与五区非阻塞默语、统一墨金标题/操作卡牌/暂停/设置及「行旅录」甲乙丙印章结算与存档。
- **44.1 kHz 立体声音频升级**：75 个音频文件全部升格 44.1 kHz（30 轨立体声 + 45 轨单声道），`audio_review.py` `0 flagged`。
- **验收**：63/63 自动化检查零报错、0 死常规通关 + 双轮 soak 零泄漏（`nodes 86->86 orphans 0->0`）、五区可读性 15/15 PASS、Apple M6 Metal 真机帧时 `p50=1.91–2.38 ms`、以及 macOS 原生 `.app` 解压运行全绿。

下一步（面向公开试玩 / 商业化）：
1. 真人盲测、实体手柄手感与扬声器听感终审。
2. Windows / Linux `v0.4.0` 目标系统实机启动验证，以及 Apple 公证与 Windows 发行签名。
3. 第二章路线、新敌种阵营与扩展叙事内容开发。

## 0.3.2 逐帧战斗与真机验收版（已合入 0.4.0）
已完成（见 [evidence/v0.3.2](evidence/v0.3.2/README.md)）：
- 主角全套逐帧战斗、守势呼吸、收剑转身与技能动画（21 个 `FrameAnim` 片段 + 2.5D 法线图），消除脱战单帧跳变；`hero_anim_no_pops` 降至 `16.7 px`。
- 墨金 HUD 与三态动态头像（`portrait` / `portrait_combat` / `portrait_hurt`），含气血滞后条、低血脉动、道力阈值刻度、羊皮纸底技能徽章与尸将 Boss 血条/破甲槽。
- 贴墙/贴边界防重叠分离（`personal_space`：`open=33 / pinned=34 / dash_past=true`）。
- Apple Silicon Mac 真机 Metal 性能实测（`wave` `p50=2.45 ms`、`elite` `p50=2.14 ms`）、五区可读性 15/15 PASS、以及解压后 macOS `.app` 原生运行全绿。

下一步：
1. 真人试玩、实体手柄手感与扬声器听感调音（含 M8 分区环境音与 Boss 音乐层）。
2. Windows / Linux `v0.3.2` 目标系统实机启动验证。
3. 进入下一阶段内容制作（尸将 V1.1 精修或 Batch 2 敌人/表情对话节点）。

## 0.3.1 接手版（已完成）
完成：守势待机、Boss 战提示位置、伤害数字堆叠、光门/结界/粒子/墨渍/平台融入、毒池色偏、统一菜单皮肤、开阔地近身退让、平台等比拼合（见 [evidence/v0.3.1](evidence/v0.3.1/README.md)）。

## 0.3 交付与下一次观察

本轮实现主角、五区环境、危险边界与 HUD 的视觉打磨，保留既有战斗判定。请结合[同机位录像与验收](evidence/v0.3/README.md)和[首玩记录](evidence/v0.3/PLAYTEST.md)，先处理具体读招困难与操作误解，再安排新章节。下列 0.1 与 0.2 里程碑用于回溯。

Priorities follow the project directive: launchable → core combat → distinct enemies → full level + elite + ending → polish/packaging.

## Done (v0.1.0, 2026-11-18)
- **M0 Assessment** — read README, docs/01–05, raw chat, MANIFEST; audited 10 concept sheets (all are parchment-backed reference sheets; no runtime assets; elite only on sheet 06; no environment art).
- **M1 Foundation** — Godot 4.7.2 project in `game/`, input map (keyboard + pad), autoloads, scene flow, fonts.
- **M2 Asset pipeline** — pose extraction from sheets (50 sprites, spec heights), procedural environment + audio generators.
- **M3 Core combat** — player 13-pose FSM, rect hit/hurt with literal high/low bands, poise/stagger, parry, skills, hit-stop/shake.
- **M4 Enemies** — grunt, crawler, husk, spitter, elite with signature mechanics and telegraphs.
- **M5 Level & flow** — 5-zone route, Group A–D encounters + burial wave, arena barriers, campfires, death/respawn, boss bar, ending, title, pause.
- **M5.5 Verification** — 33 engine checks, input-only bot clears the route (source + exported Linux build), rendered capture modes, Linux/Windows exports.

## Done in session 2 (v0.1.1–v0.1.2)
- Shader leg rig (walk/run/jump), torso twist, motion smears, hit jitter/splats/zoom punch, death motions, elite chop readability.
- Ground/debris/parallax seam fixes, ambient particles, zone ambience beds + crossfades, master limiter.
- Human-like bot difficulty proxy, Road's Edge campfire, dash i-frame tuning, spawn soft-lock fix, gamepad mapping test, flow tests, package.py.

## Done in session 3 (v0.1.3)
- Arm bones + attack arm curves (hero and enemies), enemy ledge hop, spec-conformance/continuity/ledge tests, acceptance.sh with committed evidence.

## v0.2.0 (done — acceptance 14/14 at e312e39)
- [x] M7 skinned cut-out rigs + clips for hero and all five enemies
- [x] M6 options menu, telemetry, balance pass, fairness tests
- [x] M8 audio normalization, boss music + stingers, audio review evidence
- [x] M9 zone skylines, material hit effects, boss defeat cinematic, readability gate, 5-zone comparison
- [x] M10 Linux/Windows/macOS packages, v0.2.0 acceptance

## After v0.2.0
- [x] Difficulty modes (Story / Normal / Hard) — hedge until a human playtest exists.
- Human playtest + listening test (cannot be done here).
- Windows/macOS runtime checks on real machines; Developer ID signing + notarization (needs Apple account).
- Second source pose per character (back/turn) and hand poses — needs new art.
- Painted environment layers to replace procedural skylines.

## Next
### M6 · Playtest & tuning (highest value)
- Human playtest of the full route; record time-to-clear, deaths per encounter, confusing moments.
- Tune: parry window (0.17 s), elite damage (34/26) and recovery lengths, spitter cadence, crawler pounce range, campfire spacing.
- Add an options menu (volume sliders, screen shake toggle, key rebinding).

### M7 · Animation quality
- (Legs, arms, torso now rigged in-shader.) Remaining: painted in-betweens / hand poses if an artist is available. Hero locomotion: cut the ready pose into Skeleton2D parts (torso, arms, legs, robe panels, ribbons) or paint 6–8 run frames; same for grunt shamble and crawler crawl (sheet 08 already defines the 10-part split).
- Add in-between frames for combo transitions; hair-ribbon/sword-tassel secondary motion as separate bones.
- Produce the elite V1.1 sheet (docs/04 prompt) and cut its poses (raise, chop, sweep, kneel, collapse).

### M8 · Audio pass
- Audition every SFX/music loop on real speakers; rebalance; add per-zone ambience beds (crows in the village, bubbling taint, temple wind chimes, burial-mound drones); boss music layer.

### M9 · Visual polish
- Painted environment layers (Batch 3) to replace procedural ruins; foreground occluders per zone; better ground edge and campfire art.
- Hit sparks per material (flesh / armour / paper seal); boss death cinematic beat.
- Readability at 50 % scale (Tier 3) check per the art bible.

### M10 · Packaging
- Windows build test on real hardware; macOS export (needs signing decision); app icons; GitHub Release (needs owner's go-ahead — repo is public).

### Later production (out of slice scope)
- Batch 2 enemies (重型亡秽体, 小BOSS, 秽骨之王), other factions, more chapters, save system, story/dialogue using the expression sheet.
