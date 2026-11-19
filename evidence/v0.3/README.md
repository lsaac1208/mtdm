# 0.3.0 · 实机验收

接手基线为 `66db6bc`。运行版本、三平台包、校验值、完整测试结果及完整分辨率的前后对照录像随 [GitHub Release](https://github.com/lsaac1208/mtdm/releases/tag/v0.3.0-rc.1) 发布。

| 同机位 1280×720 原图 | 开发基线 | 0.3 候选版 | 观察点 |
| --- | --- | --- | --- |
| 荒村，从入口向首场战斗行进 | [改前](before/village.png) | [改后](after/village.png) | 枯树与头部的切线、腰带和剑手、起跑的支撑脚 |
| 低洼污染区越过毒池 | [改前](before/lowland.png) | [改后](after/lowland.png) | 亮色毒池边缘、跳跃高度、落脚点 |
| 尸将重劈前摇 | [改前](before/elite.png) | [改后](after/elite.png) | 举刀高于头顶、玩家与敌人的轮廓间隔 |

Godot 4.7.2 以每秒 60 帧记录游戏画面与声音。两版采用相同起点、按键序列和正常 HUD。尸将回放在 AI 实际进入出招选择时按「重劈、横扫」顺序演示；正式游戏保留其随机选择。荒村和低地截图按操作帧提取，尸将截图按前摇开始后的 0.4 秒提取。每个 MP4 先播放旧版，再播放候选版。视频标签在封装时加入。

## 技术验收与真人试玩

- [五区角色可读性](readability/READABILITY.md) 分别测量主角、敌人与两者合并后的明度差；[缩小至约三分之一的游戏画面](readability/readability_33pct.png) 可供目视对照。
- [原生图形性能](performance/README.md) 记录乱葬岗混战与尸将前摇，列出设备、渲染器、采样方法及帧时间。
- [主角承重脚与剑击](../../tools/rig/masters/README.md) 附原画和生成方法。脚部专项在承重区间测量世界坐标滑移与距地高度；收腿和摆动期保留自然抬脚。
- [首次玩家记录表](PLAYTEST.md) 用于填写第一次认错敌人、误踩毒池、看漏前摇和听不清提示音的位置。实体手柄、真人完整试玩、普通扬声器听感需分别记录。模拟输入通关单独列在平台报告中。

### 本轮实际结果

源码 [52 项检查](gameplay/tests.log) 全部通过，含高低段攻击、符箓打断、尸将回避、难度与动态提示。双向承重步态共 99 个采样，最大水平滑移为 0.00013 px。[步态原始结果](gameplay/footwork.log) · [三连击动作帧](gameplay/sword-poses.jpg)

故事、常规、修行各跑一次带反应延迟的输入机器人，三次都抵达结局，死亡次数依次为 0、0、7。单次结果用于确认路线和难度能运行。[故事](gameplay/difficulty-0.log) · [常规](gameplay/difficulty-1.log) · [修行](gameplay/difficulty-2.log)

原图缩小至约三分之一后，荒村主角单独对背景的平均明度差从 34.9 升至 65.9，低地从 30.9 升至 59.6。五区的主角、敌人和两者合计共 15 组测量全部达到阈值。音频数值检查覆盖 62 个文件。[原始音频检查](gameplay/audio.log)

### 原速实机录像

[荒村入口与第一战](https://github.com/lsaac1208/mtdm/releases/download/v0.3.0-rc.1/01-village-before-after.mp4) · [低洼污染区](https://github.com/lsaac1208/mtdm/releases/download/v0.3.0-rc.1/02-lowland-before-after.mp4) · [尸将举刀](https://github.com/lsaac1208/mtdm/releases/download/v0.3.0-rc.1/03-elite-before-after.mp4)
