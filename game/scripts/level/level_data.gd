class_name LevelData
extends RefCounted
## The opening demo route (docs/01 §4.3, docs/05 roadmap): 荒村废墟 → 道路边缘
## → 低洼污染区 → 废弃道观 → 乱葬岗 (elite). Encounters use the spec's
## Group A–D recipes. Ground is at y = 600; x grows to the right.

const LENGTH := 11300.0

const ZONES := [
	{"x": 0.0, "cn": "荒村废墟", "en": "Ruined Village", "tint": Color(1.0, 0.93, 0.82), "fog": Color(0.85, 0.72, 0.55, 0.16), "music": "music_wander"},
	{"x": 2350.0, "cn": "道路边缘", "en": "Road's Edge", "tint": Color(0.86, 0.86, 0.84), "fog": Color(0.7, 0.68, 0.62, 0.2), "music": "music_wander"},
	{"x": 4350.0, "cn": "低洼污染区", "en": "Tainted Lowland", "tint": Color(0.78, 0.86, 0.68), "fog": Color(0.45, 0.6, 0.25, 0.26), "music": "music_taint"},
	{"x": 6550.0, "cn": "废弃道观", "en": "Abandoned Temple", "tint": Color(0.95, 0.8, 0.7), "fog": Color(0.55, 0.3, 0.2, 0.2), "music": "music_temple"},
	{"x": 8550.0, "cn": "乱葬岗", "en": "Burial Mound", "tint": Color(0.7, 0.72, 0.85), "fog": Color(0.3, 0.32, 0.45, 0.28), "music": "music_temple"},
]

# Solid ground pieces: [x0, x1, top_y]. Gaps between pieces don't exist in
# this slice (no pits) — elevation changes are steps/platforms.
const GROUND := [
	[-400.0, 11700.0, 600.0],
]

# One-way-free solid platforms: [x0, x1, top_y, style]
const PLATFORMS := [
	[880.0, 1010.0, 528.0, "wall"],
	[2700.0, 2830.0, 520.0, "rubble"],
	[3000.0, 3200.0, 545.0, "cart"],
	[4980.0, 5180.0, 520.0, "rock"],
	[6150.0, 6330.0, 525.0, "rock"],
	[7020.0, 7120.0, 535.0, "altar"],
	[8800.0, 8930.0, 530.0, "grave"],
	[9300.0, 9420.0, 530.0, "grave"],
]

const POOLS := [   # permanent taint pools [x, radius]
	[4680.0, 72.0],
	[5560.0, 84.0],
	[6050.0, 60.0],
]

const CHECKPOINTS := [
	{"id": 0, "x": 260.0},
	{"id": 1, "x": 2400.0},
	{"id": 2, "x": 4440.0},
	{"id": 3, "x": 6680.0},
	{"id": 4, "x": 8700.0},
	{"id": 5, "x": 9720.0},
]

const SIGNS := [
	{"x": 470.0, "text": "A / D 移动　·　K / 空格 跳跃（按住跳更高）"},
	{"x": 760.0, "text": "J 攻击 —— 连按三段：横斩 → 下劈 → 突刺"},
	{"x": 1130.0, "text": "按住 I 格挡；在敌人出手瞬间举剑 = 弹反（回道力，敌人露出破绽）"},
	{"x": 2580.0, "text": "L / Shift 冲刺（短暂无敌）　·　冲刺中按 J = 冲刺斩（低段）"},
	{"x": 2900.0, "text": "伏爬者贴地而行，横斩会从它头顶掠过 —— 用 S+J 下劈、冲刺斩或跳劈"},
	{"x": 4560.0, "text": "U 符箓（耗 20 道力）：追踪远敌，可打断瘴吐者蓄力　·　莫踏毒潭"},
	{"x": 6800.0, "text": "O 阴阳葫芦：饮下回血并震开周身（篝火处补满）"},
	{"x": 7280.0, "text": "封印残尸：连续贪刀会引发「符力溃散」—— 见胸前符光，立刻退开！"},
	{"x": 8240.0, "text": "P 念珠施法（耗 50 道力）：聚气后环阵爆发，解围利器"},
	{"x": 8860.0, "text": "乱葬岗尸潮将起 —— 被围时以念珠解围，留意贴地而来的伏爬者"},
	{"x": 9840.0, "text": "尸将：读它的举刀前摇 —— 竖劈要跳开震地，横扫可冲刺穿过；收招时反击"},
]

# Encounters. `lock` = arena bounds (barriers close when the player crosses
# `trigger`). Enemies: [type, x, delay, spawn_rise] — delay < 0 = pre-placed.
const ENCOUNTERS := [
	{"id": "e1_village", "group": "", "trigger": 1450.0, "lock": [1250.0, 2250.0],
		"enemies": [["grunt", 1750.0, -1.0, 0.0], ["grunt", 2120.0, 1.2, 0.9]]},
	{"id": "e2_crawler", "group": "", "trigger": 0.0, "lock": [],
		"enemies": [["crawler", 3180.0, -1.0, 0.0]]},
	{"id": "e3_group_a", "group": "A", "trigger": 3620.0, "lock": [3420.0, 4300.0],
		"enemies": [["grunt", 3950.0, -1.0, 0.0], ["grunt", 4200.0, 0.6, 0.9], ["crawler", 4150.0, 1.6, 0.6]]},
	{"id": "e4_spitter", "group": "", "trigger": 0.0, "lock": [],
		"enemies": [["spitter", 5080.0, -1.0, 0.0], ["crawler", 5330.0, -1.0, 0.0]]},
	{"id": "e5_group_c", "group": "C", "trigger": 5760.0, "lock": [5620.0, 6480.0],
		"enemies": [["spitter", 6270.0, -1.0, 0.0], ["grunt", 6000.0, 0.4, 0.9], ["grunt", 6180.0, 1.0, 0.9]]},
	{"id": "e6_husk", "group": "", "trigger": 0.0, "lock": [],
		"enemies": [["husk", 7380.0, -1.0, 0.0]]},
	{"id": "e7_group_b", "group": "B", "trigger": 7820.0, "lock": [7620.0, 8480.0],
		"enemies": [["husk", 8300.0, -1.0, 0.0], ["grunt", 8100.0, 0.5, 0.9], ["grunt", 8380.0, 1.2, 0.9]]},
	{"id": "e7c_burial_wave", "group": "A+", "trigger": 9080.0, "lock": [8960.0, 9640.0],
		"enemies": [["grunt", 9450.0, 0.3, 0.9], ["crawler", 9560.0, 0.9, 0.6], ["grunt", 9050.0, 3.2, 0.9],
			["crawler", 9550.0, 3.8, 0.6], ["grunt", 9500.0, 4.4, 0.9]]},
	{"id": "e8_elite", "group": "D", "trigger": 10000.0, "lock": [9800.0, 10900.0], "boss": true,
		"enemies": [["elite", 10600.0, -1.0, 0.0], ["grunt", 10420.0, 1.4, 0.9]]},
]

const END_X := 11080.0
