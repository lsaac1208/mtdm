extends RefCounted
## Chapter 1 · 序章 (Prologue) — route data. Moved verbatim from level_data.gd;
## LevelData exposes the active chapter through same-named static vars.
## The opening demo route (docs/01 §4.3, docs/05 roadmap): 荒村废墟 → 道路边缘
## → 低洼污染区 → 废弃道观 → 乱葬岗 (elite). Encounters use the spec's
## Group A–D recipes. Ground is at y = 600; x grows to the right.

const LENGTH := 11300.0

const ZONES := [
	{"id": "village", "x": 0.0, "cn": "荒村废墟", "en": "Ruined Village", "tint": Color(1.0, 0.93, 0.82), "fog": Color(0.85, 0.72, 0.55, 0.16), "music": "music_wander", "amb": "amb_village", "motes": [Color(0.95, 0.82, 0.55, 0.5), -12.0, 6.0],
		"light": {"key_dir": Vector3(0.62, -0.64, 0.45), "key": Color(1.10, 1.02, 0.89), "shadow": Color(0.68, 0.64, 0.60), "rim": Color(1.16, 1.02, 0.80), "rim_str": 0.28, "bounce": Color(0.86, 0.72, 0.54), "bounce_str": 0.16, "haze": Color(0.76, 0.66, 0.54, 0.13), "soil": Color(0.52, 0.42, 0.32), "shadow_lean": -0.40}},
	{"id": "road", "x": 2350.0, "cn": "道路边缘", "en": "Road's Edge", "tint": Color(0.86, 0.86, 0.84), "fog": Color(0.7, 0.68, 0.62, 0.2), "music": "music_wander", "amb": "amb_wind", "motes": [Color(0.55, 0.53, 0.5, 0.55), 25.0, 9.0],
		"light": {"key_dir": Vector3(0.36, -0.78, 0.51), "key": Color(0.99, 0.98, 0.95), "shadow": Color(0.64, 0.66, 0.68), "rim": Color(0.96, 0.97, 0.98), "rim_str": 0.25, "bounce": Color(0.68, 0.66, 0.62), "bounce_str": 0.13, "haze": Color(0.68, 0.67, 0.63, 0.15), "soil": Color(0.45, 0.43, 0.39), "shadow_lean": -0.22}},
	{"id": "lowland", "x": 4350.0, "cn": "低洼污染区", "en": "Tainted Lowland", "tint": Color(0.78, 0.86, 0.68), "fog": Color(0.45, 0.6, 0.25, 0.26), "music": "music_taint", "amb": "amb_lowland", "motes": [Color(0.7, 0.9, 0.3, 0.6), -30.0, 7.0],
		"light": {"key_dir": Vector3(0.42, -0.74, 0.52), "key": Color(0.96, 1.03, 0.88), "shadow": Color(0.58, 0.66, 0.58), "rim": Color(0.86, 1.04, 0.78), "rim_str": 0.30, "bounce": Color(0.52, 0.86, 0.36), "bounce_str": 0.20, "haze": Color(0.56, 0.64, 0.50, 0.16), "soil": Color(0.36, 0.42, 0.30), "shadow_lean": -0.26}},
	{"id": "temple", "x": 6550.0, "cn": "废弃道观", "en": "Abandoned Temple", "tint": Color(0.95, 0.8, 0.7), "fog": Color(0.55, 0.3, 0.2, 0.2), "music": "music_temple", "amb": "amb_temple", "motes": [Color(1.0, 0.6, 0.25, 0.75), -35.0, 5.0],
		"light": {"key_dir": Vector3(0.54, -0.66, 0.52), "key": Color(1.12, 0.94, 0.78), "shadow": Color(0.58, 0.52, 0.54), "rim": Color(1.20, 0.80, 0.48), "rim_str": 0.32, "bounce": Color(0.84, 0.48, 0.30), "bounce_str": 0.18, "haze": Color(0.60, 0.45, 0.38, 0.15), "soil": Color(0.40, 0.30, 0.26), "shadow_lean": -0.34}},
	{"id": "burial", "x": 8550.0, "cn": "乱葬岗", "en": "Burial Mound", "tint": Color(0.7, 0.72, 0.85), "fog": Color(0.3, 0.32, 0.45, 0.28), "music": "music_temple", "amb": "amb_burial", "motes": [Color(0.6, 0.6, 0.62, 0.6), 30.0, 10.0],
		"light": {"key_dir": Vector3(-0.44, -0.74, 0.51), "key": Color(0.94, 0.98, 1.09), "shadow": Color(0.58, 0.62, 0.74), "rim": Color(0.88, 0.96, 1.18), "rim_str": 0.34, "bounce": Color(0.52, 0.56, 0.68), "bounce_str": 0.15, "haze": Color(0.54, 0.58, 0.70, 0.18), "soil": Color(0.34, 0.35, 0.42), "shadow_lean": 0.30}},
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
	{"x": 470.0, "art": "waymark", "learn": ["jump"], "text": "{move_left} / {move_right} 移动　·　{jump} 跳跃（按住跳更高）"},
	{"x": 760.0, "art": "post", "learn": ["attack"], "need": 3, "text": "{attack} 攻击 —— 连按三段：横斩 → 下劈 → 突刺"},
	{"x": 1130.0, "art": "tablet", "learn": ["block"], "text": "按住 {block} 格挡；在敌人出手瞬间举剑 = 弹反（回道力，敌人露出破绽）"},
	{"x": 2580.0, "art": "post", "learn": ["dash"], "text": "{dash} 冲刺（短暂无敌）　·　冲刺中按 {attack} = 冲刺斩（低段）"},
	{"x": 2900.0, "art": "tablet", "text": "伏爬者贴地而行，横斩会从它头顶掠过 —— 用 {move_down}+{attack} 下劈、冲刺斩或跳劈"},
	{"x": 4560.0, "art": "chime", "learn": ["talisman"], "text": "{talisman} 符箓（耗 20 道力）：追踪远敌，可打断瘴吐者蓄力　·　莫踏毒潭"},
	{"x": 6800.0, "art": "waymark", "learn": ["gourd"], "text": "{gourd} 阴阳葫芦：饮下回血并震开周身（篝火处补满）"},
	{"x": 7280.0, "art": "post", "text": "封印残尸：连续贪刀会引发「符力溃散」—— 见胸前符光，立刻退开！"},
	{"x": 8240.0, "art": "tablet", "learn": ["beads"], "text": "{beads} 念珠施法（耗 50 道力）：聚气后环阵爆发，解围利器"},
	{"x": 8860.0, "art": "tablet", "text": "乱葬岗尸潮将起 —— 被围时以念珠解围，留意贴地而来的伏爬者"},
	{"x": 9840.0, "art": "chime", "text": "尸将：读它的举刀前摇 —— 竖劈要跳开震地，横扫可冲刺穿过；收招时反击"},
]

# Readable lore steles (残碑): one per zone, off the encounter locks. Walk up
# and press {move_up} to read; finds are tallied in the Journey Ledger. The
# last one rises in the elite's arena only once it is sealed ("after") and
# recasts the fight that just ended.
const LORE := [
	{"id": "well", "x": 2300.0, "title": "村口残碑", "en": "Village Stele",
		"text": "某年三月，秽雨七日不绝。\n里正率众以石封井，自此井中夜夜有人叩壁。\n\n碑脚另有一行新刻，字迹潦草：\n「勿开井。」",
		"en_text": "Tainted rain fell seven days. The headman sealed the well with stone; every night since, something knocks from inside. Scratched below: \"Do not open the well.\""},
	{"id": "road", "x": 2480.0, "title": "驿道里程碑", "en": "Waymarker",
		"text": "此去青云观六十里。\n\n旁有刀刻小字：\n「观中已无灯火。逃者勿往，往者勿回。」",
		"en_text": "Qingyun Temple, sixty li. Knife-cut beside it: \"No lamps burn at the temple. Those who flee, do not go; those who go, do not return.\""},
	{"id": "ward", "x": 5420.0, "title": "镇水碑", "en": "Water-Ward Stele",
		"text": "镇水以符，镇符以血。\n\n碑上黄符早已化作青黑浆水，顺着字口流下，碑底爬满秽苔。\n镇物尚在，镇人已无。",
		"en_text": "Ward the water with talismans; ward the talismans with blood. The seals have rotted to black sludge. The ward remains; its keepers do not."},
	{"id": "temple", "x": 7540.0, "title": "青云观功德碑", "en": "Temple Merit Stele",
		"text": "功德主姓名尽数被凿去，唯余末行未损：\n「师兄弃观而去，携镇尸铃一枚，不知所终。」\n\n道行者以指抚过凿痕，良久无言。",
		"en_text": "Every donor's name has been chiselled away save the last line: \"Elder brother abandoned the temple, taking the corpse-binding bell. Whereabouts unknown.\""},
	{"id": "general", "x": 10760.0, "after": "e8_elite", "title": "尸将墓志", "en": "The General's Epitaph",
		"text": "镇关校尉，殉于大疫。\n生前誓守此关，死后不渝。\n\n——原来那具铁甲，守的从来不是乱葬岗，而是这道关。\n道行者合掌：「关已无人可守。安息吧。」",
		"en_text": "A garrison captain, fallen in the great plague, sworn to hold this pass in life and after. The armour never guarded the graves - it guarded the gate. \"There is no one left to guard. Rest now.\""},
]


# Breakable painted props across all five zones (spaced clear of signs, pools,
# platforms, checkpoints, and readcap capture positions).
const DESTRUCTIBLES := [
	{"x": 630.0, "type": "urn"},
	{"x": 1340.0, "type": "crate"},
	{"x": 3340.0, "type": "crate"},
	{"x": 3760.0, "type": "urn"},
	{"x": 4860.0, "type": "urn"},
	{"x": 5840.0, "type": "crate"},
	{"x": 6920.0, "type": "brazier"},
	{"x": 7980.0, "type": "brazier"},
	{"x": 9160.0, "type": "urn"},
	{"x": 9950.0, "type": "brazier"},
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
		# husk duo: two sealed husks (entrance + far end) and one grunt, so the
		# player must manage two seal-pressure meters instead of trading hits
		"enemies": [["husk", 8300.0, -1.0, 0.0], ["husk", 7960.0, -1.0, 0.0], ["grunt", 8100.0, 0.5, 0.9]]},
	{"id": "e7c_burial_wave", "group": "A+", "trigger": 9080.0, "lock": [8960.0, 9640.0],
		"enemies": [["grunt", 9450.0, 0.3, 0.9], ["crawler", 9560.0, 0.9, 0.6], ["grunt", 9050.0, 3.2, 0.9],
			["crawler", 9550.0, 3.8, 0.6], ["grunt", 9500.0, 4.4, 0.9],
			# finale variety: a spitter rises at the far end so the wave mixes
			# ranged pressure (talisman / push through) with the crawler rush
			["spitter", 9600.0, 2.2, 0.8]]},
	{"id": "e8_elite", "group": "D", "trigger": 10000.0, "lock": [9800.0, 10900.0], "boss": true,
		"enemies": [["elite", 10600.0, -1.0, 0.0], ["grunt", 10420.0, 1.4, 0.9]]},
]

const END_X := 11080.0

# Non-blocking inner-monologue whisper cards triggered once per zone / climax.
const WHISPERS := {
	"village": {"mood": "wistful", "speaker": "道行者 · 默语", "text": "荒村灶冷，连镇宅符都化了灰……先探探前路。", "dur": 4.4},
	"road": {"mood": "alert", "speaker": "道行者 · 默语", "text": "官道尸迹未干，荒冢之祟已开始成群结队。", "dur": 4.4},
	"lowland": {"mood": "wistful", "speaker": "道行者 · 默语", "text": "瘴气沉谷，毒泥蚀骨——落脚须慎，莫贪进击。", "dur": 4.6},
	"temple": {"mood": "alert", "speaker": "道行者 · 默语", "text": "破庙香火虽断，残符犹在。此处煞气极重。", "dur": 4.4},
	"burial": {"mood": "fierce", "speaker": "道行者 · 默语", "text": "铁甲煞气冲霄……前方便是镇守乱葬岗的尸将。", "dur": 4.6},
	"boss_sealed": {"mood": "calm", "speaker": "道行者 · 默语", "text": "尸将已伏，前路石坊洞开。此行尚未终结。", "dur": 4.8},
}


const ID := "ch1"
