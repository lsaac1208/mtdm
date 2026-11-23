extends Node
## Global game state, input map, scene flow, hit-stop and run statistics.

signal checkpoint_changed(id)
signal hint(text, duration)
signal zone_entered(title_cn, title_en)
signal boss_changed(boss)
signal whisper(mood, speaker, text, duration)
signal prompts_changed

const TITLE_SCENE := "res://scenes/title.tscn"
const PROLOGUE_SCENE := "res://scenes/prologue.tscn"
const LEVEL_SCENE := "res://scenes/level.tscn"
const END_SCENE := "res://scenes/ending.tscn"

const GROUND_Y := 600.0

var checkpoint_id := 0
var cleared := {}          # encounter id -> true (persist across deaths)
var deaths := 0
var kills := 0
var parries := 0
var props_broken := 0
var run_time := 0.0
var running := false
var level: Node = null     # current level node
var player: Node = null
var whispers_seen := {}
## Contextual tutorial: the actions the current hint teaches, how many presses
## count as "learned", and which hints are already learned this run.
var hint_learn: Array = []
var hint_need := 1
var hint_key := ""
var hints_learned := {}
var lore_read := {}          # LoreStele id -> true (this run)
var best_rank := ""
var best_time := 0.0
var best_diff := -1
var cleared_once := false
## "story" = the full prologue; "rematch" = post-clear boss challenge started
## at the last campfire (never touches the story save or the main rank).
var mode := "story"
const REMATCH_CP := 5
var best_rematch := [0.0, 0.0, 0.0]   # best rematch time per difficulty
var last_rematch_best := false
var prologue_seen := false
var last_clear_is_best := false
var args := {}
var _prompt_pad := -1
var _pad_family := ""
var using_gamepad: bool:
	get: return _prompt_pad >= 0
var _quitting := false
## Run telemetry for balance analysis: damage taken per attack source, death
## causes, per-encounter time / damage / deaths.
var telemetry := {"damage": {}, "deaths": [], "encounters": {}}             # parsed user args after "--"
var _hitstop_until := 0.0

const BINDINGS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_down": [KEY_S, KEY_DOWN],
	"move_up": [KEY_W, KEY_UP],
	"jump": [KEY_K, KEY_SPACE],
	"attack": [KEY_J],
	"dash": [KEY_L, KEY_SHIFT],
	"block": [KEY_I],
	"talisman": [KEY_U],
	"gourd": [KEY_O],
	"beads": [KEY_P],
	"pause": [KEY_ESCAPE],
	"confirm": [KEY_ENTER, KEY_KP_ENTER],
}
const PAD_BUTTONS := {
	"jump": [JOY_BUTTON_A],
	"attack": [JOY_BUTTON_X],
	"dash": [JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER],
	"block": [JOY_BUTTON_LEFT_SHOULDER],
	"talisman": [JOY_BUTTON_Y],
	"pause": [JOY_BUTTON_START],
	"confirm": [JOY_BUTTON_A, JOY_BUTTON_START],
	"move_left": [JOY_BUTTON_DPAD_LEFT],
	"move_right": [JOY_BUTTON_DPAD_RIGHT],
	"move_down": [JOY_BUTTON_DPAD_DOWN],
	"move_up": [JOY_BUTTON_DPAD_UP],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	get_window().close_requested.connect(quit)
	get_window().theme = InkTheme.shared()
	Input.joy_connection_changed.connect(_on_joy_connection)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_setup_input()
	load_settings.call_deferred()
	if args.has("difficulty"):
		(func(): difficulty = clampi(int(args.difficulty), 0, 2)).call_deferred()
	if args.has("shots"):
		_shots.call_deferred()
	if args.has("test") and ResourceLoader.exists("res://tests/test_runner.gd"):
		var tr = load("res://tests/test_runner.gd").new()
		add_child(tr)
	if args.has("quit_after"):
		get_tree().create_timer(float(args.quit_after), true, false, true).timeout.connect(quit)


func _setup_input() -> void:
	for action in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.3)
		for k in BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
		for b in PAD_BUTTONS.get(action, []):
			var jb := InputEventJoypadButton.new()
			jb.button_index = b
			InputMap.action_add_event(action, jb)
	# analog stick + triggers
	_add_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis("gourd", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_axis("beads", JOY_AXIS_TRIGGER_RIGHT, 1.0)


func _add_axis(action: String, axis: int, v: float) -> void:
	var m := InputEventJoypadMotion.new()
	m.axis = axis
	m.axis_value = v
	InputMap.action_add_event(action, m)


var _fps_t := 0.0


func _process(delta: float) -> void:
	if args.has("fpslog"):
		_fps_t += delta
		if _fps_t >= 2.0:
			_fps_t = 0.0
			print("FPS %d  frame_ms %.1f  objects %d" % [Engine.get_frames_per_second(), 1000.0 / maxf(1.0, Engine.get_frames_per_second()), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	if running and not get_tree().paused:
		run_time += delta
	if _hitstop_until > 0.0 and Time.get_ticks_msec() / 1000.0 >= _hitstop_until:
		_hitstop_until = 0.0
		Engine.time_scale = 1.0


const SETTINGS_PATH := "user://settings.cfg"
## Mid-run save (campfire rest). Tests only write it when given --qa-run=PATH.
const RUN_PATH := "user://run.cfg"


func _run_path() -> String:
	return String(args.get("qa-run", RUN_PATH))


func _run_save_enabled() -> bool:
	return args.has("qa-run") or not (args.has("test") or args.has("shots"))


func save_run() -> void:
	if not _run_save_enabled() or not running or mode != "story":
		return
	var cf := ConfigFile.new()
	cf.set_value("run", "checkpoint", checkpoint_id)
	cf.set_value("run", "cleared", cleared.keys())
	cf.set_value("run", "lore", lore_read.keys())
	cf.set_value("run", "whispers", whispers_seen.keys())
	cf.set_value("run", "hints", hints_learned.keys())
	cf.set_value("run", "deaths", deaths)
	cf.set_value("run", "kills", kills)
	cf.set_value("run", "parries", parries)
	cf.set_value("run", "props", props_broken)
	cf.set_value("run", "time", run_time)
	cf.set_value("run", "difficulty", difficulty)
	cf.save(_run_path())


func has_saved_run() -> bool:
	return FileAccess.file_exists(_run_path())


## Summary for the title's Continue entry: {zone_cn, time}; empty if none.
func saved_run_info() -> Dictionary:
	var cf := ConfigFile.new()
	if not has_saved_run() or cf.load(_run_path()) != OK:
		return {}
	var cp := clampi(int(cf.get_value("run", "checkpoint", 0)), 0, LevelData.CHECKPOINTS.size() - 1)
	var cx: float = LevelData.CHECKPOINTS[cp].x
	var zone := String(LevelData.ZONES[0].cn)
	for z in LevelData.ZONES:
		if cx >= float(z.x):
			zone = String(z.cn)
	return {"zone": zone, "time": float(cf.get_value("run", "time", 0.0))}


func clear_saved_run() -> void:
	if has_saved_run() and _run_save_enabled():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_run_path()))


static func _keys_to_set(arr) -> Dictionary:
	var d := {}
	for k in arr:
		d[k] = true
	return d


## Resume a saved run at its last campfire (no prologue).
## Post-clear challenge: straight to the General from the last campfire.
func start_rematch() -> void:
	mode = "rematch"
	checkpoint_id = REMATCH_CP
	cleared.clear()
	for e in LevelData.ENCOUNTERS:
		if String(e.id) != "e8_elite":
			cleared[e.id] = true
	whispers_seen.clear()
	hints_learned.clear()
	lore_read.clear()
	hint_learn = []
	deaths = 0
	kills = 0
	parries = 0
	props_broken = 0
	run_time = 0.0
	last_clear_is_best = false
	last_rematch_best = false
	telemetry = {"damage": {}, "deaths": [], "encounters": {}}
	running = true
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVEL_SCENE)


## Records a finished rematch; returns true if it beat this difficulty's best.
func record_rematch(persist := true) -> bool:
	var d := clampi(difficulty, 0, 2)
	var prev: float = best_rematch[d]
	last_rematch_best = prev <= 0.0 or run_time < prev
	if last_rematch_best:
		best_rematch[d] = run_time
		if persist:
			save_settings()
	return last_rematch_best


func continue_run() -> bool:
	mode = "story"
	var cf := ConfigFile.new()
	if cf.load(_run_path()) != OK:
		return false
	checkpoint_id = clampi(int(cf.get_value("run", "checkpoint", 0)), 0, LevelData.CHECKPOINTS.size() - 1)
	cleared = _keys_to_set(cf.get_value("run", "cleared", []))
	lore_read = _keys_to_set(cf.get_value("run", "lore", []))
	whispers_seen = _keys_to_set(cf.get_value("run", "whispers", []))
	hints_learned = _keys_to_set(cf.get_value("run", "hints", []))
	hint_learn = []
	deaths = int(cf.get_value("run", "deaths", 0))
	kills = int(cf.get_value("run", "kills", 0))
	parries = int(cf.get_value("run", "parries", 0))
	props_broken = int(cf.get_value("run", "props", 0))
	run_time = float(cf.get_value("run", "time", 0.0))
	difficulty = clampi(int(cf.get_value("run", "difficulty", difficulty)), 0, 2)
	last_clear_is_best = false
	telemetry = {"damage": {}, "deaths": [], "encounters": {}}
	running = true
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVEL_SCENE)
	return true


var shake_scale := 1.0
## 0 = Story (故事), 1 = Normal (常规), 2 = Hard (修行)
var difficulty := 1
const DIFF_DAMAGE := [0.55, 1.0, 1.3]     # damage taken by the player
const DIFF_POISE := [0.7, 1.0, 1.2]       # elite armour (poise) multiplier
## Rank-and-file wind-up length per difficulty (Story gives newcomers longer
## tells; the elite's spec-locked 0.65-0.85 s wind-ups are not scaled).
const DIFF_TELEGRAPH := [1.35, 1.0, 0.88]


func tele(sec: float) -> float:
	return sec * DIFF_TELEGRAPH[clampi(difficulty, 0, 2)]
var hitstop_on := true
## Photosensitivity: scales every full-screen flash / colour pulse (0 = off).
var flash_scale := 1.0
## Roadside tutorial hint strips (story hints such as respawn lines stay on).
var tutorial_hints := true
## Gamepad vibration (only ever sent to the pad the player is using).
var rumble_on := true
var last_rumble := []   # [weak, strong, duration] of the last request (QA)


func rumble(weak: float, strong: float, dur: float) -> void:
	if not rumble_on:
		return
	last_rumble = [weak, strong, dur]
	if _prompt_pad >= 0:
		Input.start_joy_vibration(_prompt_pad, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), dur)
const REBINDABLE := ["move_left", "move_right", "move_down", "jump", "attack", "dash", "block", "talisman", "gourd", "beads"]
const BUS_NAMES := ["Master", "Music", "SFX"]


func bus_volume(bus: String) -> float:
	var i := AudioServer.get_bus_index(bus)
	return db_to_linear(AudioServer.get_bus_volume_db(i)) if i >= 0 else 1.0


func set_bus_volume(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		i = Sfx.ensure_bus(bus) if bus != "Master" else 0
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(i, v <= 0.001 or (i == 0 and args.has("mute")))


## Keyboard keycodes currently bound to an action (pad bindings are untouched).
func action_keys(action: String) -> Array:
	var out := []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			out.append(ev.physical_keycode)
	return out


func rebind(action: String, keycode: int) -> void:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	var k := InputEventKey.new()
	k.physical_keycode = keycode
	InputMap.action_add_event(action, k)
	if using_gamepad:
		_set_prompt_device(-1)
	else:
		prompts_changed.emit()


func reset_bindings() -> void:
	for action in REBINDABLE:
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				InputMap.action_erase_event(action, ev)
		for kc in BINDINGS[action]:
			var k := InputEventKey.new()
			k.physical_keycode = kc
			InputMap.action_add_event(action, k)
	prompts_changed.emit()


const PAD_LABELS := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_START: "Start",
	JOY_BUTTON_DPAD_LEFT: "D-pad ←", JOY_BUTTON_DPAD_RIGHT: "D-pad →",
	JOY_BUTTON_DPAD_UP: "D-pad ↑", JOY_BUTTON_DPAD_DOWN: "D-pad ↓",
}
const SONY_LABELS := {
	JOY_BUTTON_A: "×", JOY_BUTTON_B: "○", JOY_BUTTON_X: "□", JOY_BUTTON_Y: "△",
	JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1", JOY_BUTTON_START: "Options",
}
const NINTENDO_LABELS := {
	JOY_BUTTON_A: "B", JOY_BUTTON_B: "A", JOY_BUTTON_X: "Y", JOY_BUTTON_Y: "X",
	JOY_BUTTON_LEFT_SHOULDER: "L", JOY_BUTTON_RIGHT_SHOULDER: "R", JOY_BUTTON_START: "+",
}
const TRIGGER_LABELS := {"": ["LT", "RT"], "sony": ["L2", "R2"], "nintendo": ["ZL", "ZR"]}


func keyboard_label(action: String, primary_only := false) -> String:
	var labels := PackedStringArray()
	for kc: Key in action_keys(action):
		var key := kc
		if DisplayServer.get_name() != "headless":
			key = DisplayServer.keyboard_get_keycode_from_physical(kc)
		labels.append(OS.get_keycode_string(kc if key == KEY_NONE else key))
		if primary_only:
			break
	return " / ".join(labels) if not labels.is_empty() else "—"


func binding_label(action: String, primary_only := false) -> String:
	if not using_gamepad:
		return keyboard_label(action, primary_only)
	var labels := PackedStringArray()
	for ev in InputMap.action_get_events(action):
		var label := ""
		if ev is InputEventJoypadButton:
			label = PAD_LABELS.get(ev.button_index, "")
			if _pad_family == "sony":
				label = SONY_LABELS.get(ev.button_index, label)
			elif _pad_family == "nintendo":
				label = NINTENDO_LABELS.get(ev.button_index, label)
		elif ev is InputEventJoypadMotion:
			if ev.axis == JOY_AXIS_TRIGGER_LEFT:
				label = TRIGGER_LABELS[_pad_family][0]
			elif ev.axis == JOY_AXIS_TRIGGER_RIGHT:
				label = TRIGGER_LABELS[_pad_family][1]
		if not label.is_empty():
			labels.append(label)
			if primary_only:
				break
	return " / ".join(labels) if not labels.is_empty() else "—"


func fmt_keys(text: String) -> String:
	var out := text
	for action in BINDINGS:
		var tag := "{%s}" % action
		if out.contains(tag):
			out = out.replace(tag, binding_label(action))
	return out


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(args.get("qa-settings", SETTINGS_PATH)) != OK:
		return
	set_bus_volume("Master", cf.get_value("audio", "volume", 1.0))
	set_bus_volume("Music", cf.get_value("audio", "music", 1.0))
	set_bus_volume("SFX", cf.get_value("audio", "sfx", 1.0))
	shake_scale = cf.get_value("video", "shake", 1.0)
	difficulty = clampi(cf.get_value("game", "difficulty", 1), 0, 2)
	hitstop_on = cf.get_value("video", "hitstop", true)
	flash_scale = clampf(float(cf.get_value("video", "flash", 1.0)), 0.0, 1.0)
	tutorial_hints = bool(cf.get_value("game", "hints", true))
	rumble_on = bool(cf.get_value("game", "rumble", true))
	if cf.get_value("video", "fullscreen", false) and DisplayServer.get_name() != "headless":
		get_window().mode = Window.MODE_FULLSCREEN
	if cf.has_section("keys"):
		for action in REBINDABLE:
			if cf.has_section_key("keys", action):
				var codes: Array = cf.get_value("keys", action)
				for ev in InputMap.action_get_events(action):
					if ev is InputEventKey:
						InputMap.action_erase_event(action, ev)
				for kc in codes:
					var k := InputEventKey.new()
					k.physical_keycode = kc
					InputMap.action_add_event(action, k)
	if cf.has_section("progress"):
		best_rank = String(cf.get_value("progress", "best_rank", ""))
		best_time = float(cf.get_value("progress", "best_time", 0.0))
		best_diff = int(cf.get_value("progress", "best_diff", -1))
		cleared_once = bool(cf.get_value("progress", "cleared_once", false))
		var br = cf.get_value("progress", "best_rematch", [0.0, 0.0, 0.0])
		if br is Array and br.size() == 3:
			best_rematch = [float(br[0]), float(br[1]), float(br[2])]
		prologue_seen = bool(cf.get_value("progress", "prologue_seen", false))
	prompts_changed.emit()


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "volume", bus_volume("Master"))
	cf.set_value("audio", "music", bus_volume("Music"))
	cf.set_value("audio", "sfx", bus_volume("SFX"))
	cf.set_value("video", "shake", shake_scale)
	cf.set_value("game", "difficulty", difficulty)
	cf.set_value("video", "hitstop", hitstop_on)
	cf.set_value("video", "flash", flash_scale)
	cf.set_value("game", "hints", tutorial_hints)
	cf.set_value("game", "rumble", rumble_on)
	cf.set_value("video", "fullscreen", get_window().mode == Window.MODE_FULLSCREEN)
	for action in REBINDABLE:
		cf.set_value("keys", action, action_keys(action))
	cf.set_value("progress", "best_rank", best_rank)
	cf.set_value("progress", "best_time", best_time)
	cf.set_value("progress", "best_diff", best_diff)
	cf.set_value("progress", "cleared_once", cleared_once)
	cf.set_value("progress", "best_rematch", best_rematch)
	cf.set_value("progress", "prologue_seen", prologue_seen)
	cf.save(args.get("qa-settings", SETTINGS_PATH))


func _on_joy_connection(device: int, connected: bool) -> void:
	if not connected and device == _prompt_pad:
		_set_prompt_device(-1)


func _set_prompt_device(device: int) -> void:
	if _prompt_pad == device:
		return
	_prompt_pad = device
	_pad_family = ""
	if device >= 0 and device in Input.get_connected_joypads():
		var vendor: int = Input.get_joy_info(device).get("vendor_id", 0)
		match vendor:
			0x054c: _pad_family = "sony"
			0x057e: _pad_family = "nintendo"
	prompts_changed.emit()


func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		_set_prompt_device(-1)
	elif e is InputEventJoypadButton and e.pressed:
		_set_prompt_device(e.device)
	elif e is InputEventJoypadMotion and absf(e.axis_value) > 0.35:
		_set_prompt_device(e.device)
	if e is InputEventKey and e.pressed and not e.echo and (e.physical_keycode == KEY_F11 or (e.physical_keycode == KEY_ENTER and e.alt_pressed)):
		var w := get_window()
		w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		save_settings()
		get_viewport().set_input_as_handled()


## Freeze-frame for impact weight. Uses real time so it always recovers.
func hitstop(duration: float, scale := 0.05) -> void:
	if args.has("nohitstop") or not hitstop_on:
		return
	var now := Time.get_ticks_msec() / 1000.0
	_hitstop_until = maxf(_hitstop_until, now + duration)
	Engine.time_scale = scale


## Real-time delta unaffected by brief hitstop slow-downs so slash trails,
## hit sparks, enemy hit-shudder, and camera punch stay fluid at 60/120 fps.
static func unscaled_delta(delta: float) -> float:
	var ts := Engine.time_scale
	if ts <= 0.001:
		return 1.0 / 60.0
	return minf(delta / ts, 0.05)


func new_run() -> void:
	mode = "story"
	checkpoint_id = 0
	cleared.clear()
	whispers_seen.clear()
	hints_learned.clear()
	lore_read.clear()
	hint_learn = []
	deaths = 0
	kills = 0
	parries = 0
	props_broken = 0
	run_time = 0.0
	last_clear_is_best = false
	telemetry = {"damage": {}, "deaths": [], "encounters": {}}
	running = true
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVEL_SCENE)


func start_story_run() -> void:
	clear_saved_run()   # a new journey replaces any unfinished one
	if args.has("test") or args.has("shots") or args.has("autostart") or args.has("skip_prologue") or args.has("startx"):
		new_run()
		return
	checkpoint_id = 0
	cleared.clear()
	whispers_seen.clear()
	deaths = 0
	kills = 0
	parries = 0
	props_broken = 0
	run_time = 0.0
	last_clear_is_best = false
	telemetry = {"damage": {}, "deaths": [], "encounters": {}}
	running = false
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(PROLOGUE_SCENE)


static func rank_order(grade: String) -> int:
	match grade:
		"甲": return 3
		"乙": return 2
		"丙": return 1
		_: return 0


static func compute_rank(p_deaths: int, p_parries: int, p_time: float, p_diff: int) -> Dictionary:
	if (p_deaths == 0 and (p_parries >= 2 or p_time <= 360.0)) or (p_diff >= 2 and p_deaths <= 1 and p_parries >= 3):
		return {
			"grade": "甲",
			"en": "A · MASTER OF TAO",
			"title": "道心通明",
			"color": Color(0.76, 0.14, 0.09),
		}
	if (p_deaths <= 3 and p_time <= 540.0) or p_diff >= 2:
		return {
			"grade": "乙",
			"en": "B · DEMON SLAYER",
			"title": "斩妖除祟",
			"color": Color(0.68, 0.24, 0.11),
		}
	return {
		"grade": "丙",
		"en": "C · WASTELAND WANDERER",
		"title": "初涉废土",
		"color": Color(0.46, 0.30, 0.16),
	}


func record_clear(persist := true) -> Dictionary:
	var info: Dictionary = compute_rank(deaths, parries, run_time, difficulty)
	var grade := String(info.grade)
	var cur_ord := rank_order(grade)
	var prev_ord := rank_order(best_rank)
	var improved := (not cleared_once) or cur_ord > prev_ord or (cur_ord == prev_ord and (best_time <= 0.0 or run_time < best_time))
	last_clear_is_best = improved
	if improved:
		best_rank = grade
		best_time = run_time
		best_diff = difficulty
	cleared_once = true
	if persist:
		save_settings()
	return info


func to_title() -> void:
	running = false
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)


func finish_demo() -> void:
	if mode == "story":
		clear_saved_run()
	running = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(END_SCENE)


func set_checkpoint(id: int) -> void:
	if id != checkpoint_id:
		checkpoint_id = id
	checkpoint_changed.emit(id)
	save_run()


func show_hint(text: String, duration := 4.0, learn: Array = [], need := 1, key := "") -> void:
	hint_learn = learn
	hint_need = need
	hint_key = key if key != "" else text
	hint.emit(text, duration)


## Called by the HUD once the player has performed the hinted action.
func mark_hint_learned() -> void:
	if hint_key != "":
		hints_learned[hint_key] = true
	hint_learn = []


func show_whisper(id: String, mood: String, speaker: String, text: String, duration := 4.5) -> void:
	if id != "" and whispers_seen.get(id, false):
		return
	if id != "":
		whispers_seen[id] = true
	whisper.emit(mood, speaker, text, duration)


func quit(exit_code := 0) -> void:
	if _quitting:
		return
	_quitting = true
	running = false
	Sfx.shutdown()
	# AudioServer retires stopped playbacks on the mixer thread, then releases
	# their resources on an idle frame. Fixed-FPS test runs outpace that thread.
	var drain_us := int(maxf(0.08, AudioServer.get_output_latency() + 2 * AudioServer.get_time_to_next_mix()) * 1e6)
	var deadline := Time.get_ticks_usec() + drain_us
	while Time.get_ticks_usec() < deadline:
		await get_tree().process_frame
	get_tree().quit(exit_code)


func format_time(t: float) -> String:
	var s := int(t)
	return "%02d:%02d" % [s / 60, s % 60]


## --shots=dir --shot_times=1,2.5 [--startx=N]: save viewport captures.
func _shots() -> void:
	var dir: String = args.shots
	DirAccess.make_dir_recursive_absolute(dir)
	var times := (args.get("shot_times", "2") as String).split(",")
	var i := 0
	var elapsed := 0.0
	for ts in times:
		var tt := float(ts)
		await get_tree().create_timer(tt - elapsed, true, false, true).timeout
		elapsed = tt
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/shot_%02d.png" % [dir, i])
		print("SHOT %s/shot_%02d.png" % [dir, i])
		i += 1


func tel_damage(source: String, amount: float) -> void:
	telemetry.damage[source] = telemetry.damage.get(source, 0.0) + amount


func tel_enc(id: String, key: String, v: float) -> void:
	if not telemetry.encounters.has(id):
		telemetry.encounters[id] = {"time": 0.0, "damage": 0.0, "deaths": 0, "start": 0.0}
	telemetry.encounters[id][key] = telemetry.encounters[id].get(key, 0.0) + v
