extends Node
## Global game state, input map, scene flow, hit-stop and run statistics.

signal checkpoint_changed(id)
signal hint(text, duration)
signal zone_entered(title_cn, title_en)
signal boss_changed(boss)

const TITLE_SCENE := "res://scenes/title.tscn"
const LEVEL_SCENE := "res://scenes/level.tscn"
const END_SCENE := "res://scenes/ending.tscn"

const GROUND_Y := 600.0

var checkpoint_id := 0
var cleared := {}          # encounter id -> true (persist across deaths)
var deaths := 0
var kills := 0
var parries := 0
var run_time := 0.0
var running := false
var level: Node = null     # current level node
var player: Node = null
var args := {}             # parsed user args after "--"
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
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_setup_input()
	load_settings.call_deferred()
	if args.has("shots"):
		_shots.call_deferred()
	if args.has("test") and ResourceLoader.exists("res://tests/test_runner.gd"):
		var tr = load("res://tests/test_runner.gd").new()
		add_child(tr)
	if args.has("quit_after"):
		get_tree().create_timer(float(args.quit_after), true, false, true).timeout.connect(func(): get_tree().quit())


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


var shake_scale := 1.0
var hitstop_on := true
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


func reset_bindings() -> void:
	for action in REBINDABLE:
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				InputMap.action_erase_event(action, ev)
		for kc in BINDINGS[action]:
			var k := InputEventKey.new()
			k.physical_keycode = kc
			InputMap.action_add_event(action, k)


## Replace {action} placeholders with the currently bound key names.
func fmt_keys(text: String) -> String:
	var out := text
	for action in REBINDABLE:
		var tag := "{%s}" % action
		if out.contains(tag):
			var names := []
			for kc in action_keys(action):
				names.append(OS.get_keycode_string(kc))
			out = out.replace(tag, " / ".join(names) if not names.is_empty() else "?")
	return out


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return
	set_bus_volume("Master", cf.get_value("audio", "volume", 1.0))
	set_bus_volume("Music", cf.get_value("audio", "music", 1.0))
	set_bus_volume("SFX", cf.get_value("audio", "sfx", 1.0))
	shake_scale = cf.get_value("video", "shake", 1.0)
	hitstop_on = cf.get_value("video", "hitstop", true)
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


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "volume", bus_volume("Master"))
	cf.set_value("audio", "music", bus_volume("Music"))
	cf.set_value("audio", "sfx", bus_volume("SFX"))
	cf.set_value("video", "shake", shake_scale)
	cf.set_value("video", "hitstop", hitstop_on)
	cf.set_value("video", "fullscreen", get_window().mode == Window.MODE_FULLSCREEN)
	for action in REBINDABLE:
		cf.set_value("keys", action, action_keys(action))
	cf.save(SETTINGS_PATH)


func _input(e: InputEvent) -> void:
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


func new_run() -> void:
	checkpoint_id = 0
	cleared.clear()
	deaths = 0
	kills = 0
	parries = 0
	run_time = 0.0
	running = true
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVEL_SCENE)


func to_title() -> void:
	running = false
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)


func finish_demo() -> void:
	running = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(END_SCENE)


func set_checkpoint(id: int) -> void:
	if id != checkpoint_id:
		checkpoint_id = id
	checkpoint_changed.emit(id)


func show_hint(text: String, duration := 4.0) -> void:
	hint.emit(fmt_keys(text), duration)


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
