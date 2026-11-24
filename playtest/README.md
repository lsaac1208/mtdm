# 道行者 Taoist Wanderer — 试玩包说明 / Playtest Guide (v0.6.0 RC)

> 这是一份**未公开发布的试玩候选版**。感谢你帮忙试玩！全程约 10–20 分钟。
> This is an **unreleased playtest candidate**. Thank you for testing! A full run takes about 10–20 minutes.

## 1. 安装与启动 / Install & launch

| 平台 Platform | 文件 File | 启动 Launch |
| --- | --- | --- |
| Windows 10/11 (x86_64) | `TaoistWanderer-v0.6.0-windows-x86_64.zip` | 解压整个 ZIP，双击 `TaoistWanderer.exe`。若 SmartScreen 提示，选「更多信息 → 仍要运行」（未做代码签名）。<br>Extract the whole ZIP, run `TaoistWanderer.exe`. If SmartScreen warns, choose *More info → Run anyway* (not code-signed). |
| macOS 11+ (Intel & Apple Silicon) | `TaoistWanderer-v0.6.0-macos-universal.zip` | 解压后**右键 → 打开** `道行者 Taoist Wanderer.app`（未公证，首次需右键打开）。<br>Extract, then **right-click → Open** the app (ad-hoc signed, not notarized). |
| Linux x86_64 / Steam Deck | `TaoistWanderer-v0.6.0-linux-x86_64.zip` | 解压后运行 `./TaoistWanderer.x86_64`；若无执行权限先 `chmod +x TaoistWanderer.x86_64`。<br>Extract and run `./TaoistWanderer.x86_64` (`chmod +x` if needed). |

需要支持 OpenGL 3.3 的显卡。Requires an OpenGL 3.3 capable GPU. 无需安装引擎 / no engine install needed.

**英文 / English:** 标题页 → 设置 → 语言 Language → English. Title → Options → 语言 Language → English.

## 2. 操作 / Controls

| 动作 Action | 键盘 Keyboard | 手柄 Gamepad (Xbox layout) |
| --- | --- | --- |
| 移动 Move | A / D 或 ← → | 左摇杆 / 十字键 Left stick / D-pad |
| 跳跃 Jump（按住更高 hold = higher） | K / Space | A |
| 攻击 Attack（连按三段 3-hit combo） | J | X |
| 下劈 Overhead (hits crawlers) | S + J | ↓ + X |
| 冲刺 Dash（短暂无敌 brief invulnerability） | L / Shift | B / RB |
| 格挡 / 弹反 Guard / Parry | 按住 I（出手瞬间 = 弹反） hold I | LB |
| 符箓 Talisman | U | Y |
| 葫芦 Gourd（回血 heal） | O | LT |
| 念珠 Beads（范围爆发 ring burst） | P | RT |
| 读碑 Read stele | W / ↑（站在碑旁 beside it） | 十字键↑ D-pad up |
| 暂停 Pause | Esc | Start |
| 菜单 Menus | 方向键 + Enter / Esc | 十字键 + A 确认 / B 返回 |

按键可在 设置 → 按键 中重新绑定。Keys can be rebound in Options.

## 3. 第一次试玩建议 / First session

1. 从标题页「开始游戏」开始，序章可随时跳过。Start from the title; the prologue can be skipped.
2. 选择你平时习惯的难度（推荐「常规」）。Pick your usual difficulty (Normal recommended).
3. 路边石碑会教你操作；发光的**残碑**可以阅读，讲述这片土地的故事。Roadside signs teach the controls; glowing **steles** can be read.
4. 篝火处休息会**存档**；退出后可在标题页「继续」。Resting at a campfire **saves**; use *Continue* on the title.
5. 一路走到乱葬岗，击败尸将，穿过石坊光门即通关。Reach the Burial Mound, defeat the Undead General and walk through the gate.
6. 通关后标题页会出现「再战尸将」挑战。After clearing, *Rematch* unlocks on the title.

画面卡顿？设置 → 精简画质。Stuttering? Options → *Low graphics*. 对闪光敏感？设置 → 闪屏强度。Sensitive to flashes? Options → *Screen flashes*.

## 4. 反馈 / Feedback

请填写 [FEEDBACK_TEMPLATE.md](FEEDBACK_TEMPLATE.md)（中英皆可），并尽量注明发生的区域或篝火。Please fill in the feedback template (either language), noting the zone or campfire.

存档与设置位置（需要时可附上）/ Save & settings files (attach if asked):
- Linux / Steam Deck: `~/.local/share/godot/app_userdata/道行者 Taoist Wanderer/`
- Windows: `%APPDATA%\Godot\app_userdata\道行者 Taoist Wanderer\` *(Godot default; not yet verified on Windows)*
- macOS: `~/Library/Application Support/Godot/app_userdata/道行者 Taoist Wanderer/` *(Godot default; not yet verified on macOS)*

已知问题见 [KNOWN_ISSUES.md](KNOWN_ISSUES.md)。Known issues: see KNOWN_ISSUES.md.
