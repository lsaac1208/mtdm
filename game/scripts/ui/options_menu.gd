class_name OptionsMenu
extends Control
## Options: Master / Music / SFX volume, screen-shake strength, hit-stop,
## fullscreen, and keyboard rebinding for every gameplay action. Changes apply
## immediately and persist to user://settings.cfg. Esc / Back closes.

signal closed

const BRUSH_FONT := preload("res://assets/fonts/MaShanZheng-subset.ttf")
const ACTION_NAMES := {
	"move_left": "左移 Left", "move_right": "右移 Right", "move_down": "下 (下劈) Down",
	"jump": "跳跃 Jump", "attack": "攻击 Attack", "dash": "冲刺 Dash", "block": "格挡 Block",
	"talisman": "符箓 Talisman", "gourd": "葫芦 Gourd", "beads": "念珠 Beads",
}

var _capture := ""            # action waiting for a key
var _key_buttons := {}
var _first: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = InkTheme.shared()
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.025, 0.02, 0.84)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", InkTheme.scroll_panel(26, 20, 0.95))
	frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	frame.offset_left = -454
	frame.offset_right = 454
	frame.offset_top = -342
	frame.offset_bottom = 342
	add_child(frame)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(830, 0)
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	var title := Label.new()
	title.text = "设 置  ·  Options"
	title.add_theme_font_override("font", BRUSH_FONT)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.92, 0.84, 0.66))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_section(box, "难度 Difficulty")
	var diff := OptionButton.new()
	for item in ["故事 Story — 受伤 −45%，尸将破甲更快", "常规 Normal", "修行 Hard — 受伤 +30%，尸将更坚"]:
		diff.add_item(item)
	diff.selected = Game.difficulty
	diff.custom_minimum_size = Vector2(520, 36)
	diff.item_selected.connect(func(i): Game.difficulty = i; Game.save_settings(); InkTheme.play_ui("ui_click", "ui_move", -7.0))
	InkTheme.wire_hover(diff)
	box.add_child(diff)
	_section(box, "声音 Audio")
	_first = _slider(box, "总音量 Master", Game.bus_volume("Master"), func(v): Game.set_bus_volume("Master", v))
	_slider(box, "音乐 Music", Game.bus_volume("Music"), func(v): Game.set_bus_volume("Music", v))
	_slider(box, "音效 Effects", Game.bus_volume("SFX"), func(v): Game.set_bus_volume("SFX", v))
	_section(box, "画面 Display")
	_slider(box, "屏幕震动 Screen shake", Game.shake_scale, func(v): Game.shake_scale = v)
	_check(box, "打击停顿 Hit-stop", Game.hitstop_on, func(on): Game.hitstop_on = on)
	_slider(box, "闪屏强度 Screen flashes", Game.flash_scale, func(v): Game.flash_scale = v)
	_check(box, "教学提示 Tutorial hints", Game.tutorial_hints, func(on): Game.tutorial_hints = on)
	_check(box, "手柄震动 Controller vibration", Game.rumble_on, func(on): Game.rumble_on = on)
	_check(box, "精简画质 Low graphics (faster)", Game.quality == 0, func(on):
		Game.quality = 0 if on else 1
		if Game.level and is_instance_valid(Game.level) and Game.level.has_method("apply_quality"):
			Game.level.apply_quality())
	_check(box, "全屏 Fullscreen (F11)", get_window().mode == Window.MODE_FULLSCREEN,
		func(on): get_window().mode = Window.MODE_FULLSCREEN if on else Window.MODE_WINDOWED)
	_section(box, "按键 Keyboard (点击后按新键 · click, then press a key)")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	box.add_child(grid)
	for action in Game.REBINDABLE:
		var l := Label.new()
		l.text = ACTION_NAMES.get(action, action)
		l.custom_minimum_size = Vector2(300, 0)
		l.add_theme_font_size_override("font_size", 18)
		grid.add_child(l)
		var b := Button.new()
		b.custom_minimum_size = Vector2(260, 34)
		b.pressed.connect(_begin_capture.bind(action))
		grid.add_child(b)
		_key_buttons[action] = b
	_refresh_keys()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	var reset := Button.new()
	reset.text = "恢复默认按键 Reset keys"
	reset.pressed.connect(func(): Game.reset_bindings(); _refresh_keys(); Game.save_settings(); InkTheme.play_ui("ui_click", "ui_move", -6.0))
	InkTheme.wire_hover(reset)
	row.add_child(reset)
	var back := Button.new()
	back.text = "返回 Back"
	back.custom_minimum_size = Vector2(180, 40)
	back.pressed.connect(close)
	InkTheme.wire_hover(back)
	row.add_child(back)
	_first.grab_focus.call_deferred()


func _section(box: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(0.85, 0.62, 0.35))
	box.add_child(l)


func _slider(box: VBoxContainer, text: String, value: float, cb: Callable) -> HSlider:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(300, 0)
	l.add_theme_font_size_override("font_size", 18)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(380, 28)
	var pct := Label.new()
	pct.text = "%d%%" % int(round(value * 100))
	s.value_changed.connect(func(v): cb.call(v); pct.text = "%d%%" % int(round(v * 100)); Game.save_settings())
	row.add_child(s)
	row.add_child(pct)
	box.add_child(row)
	return s


func _check(box: VBoxContainer, text: String, on: bool, cb: Callable) -> void:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	c.add_theme_font_size_override("font_size", 18)
	c.toggled.connect(func(v): cb.call(v); Game.save_settings())
	box.add_child(c)


func _refresh_keys() -> void:
	for action in _key_buttons:
		_key_buttons[action].text = "…按任意键 press a key…" if action == _capture else Game.keyboard_label(action)


func _begin_capture(action: String) -> void:
	InkTheme.play_ui("ui_click", "ui_move", -7.0)
	_capture = action
	_refresh_keys()


func _input(e: InputEvent) -> void:
	if _capture != "" and e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode != KEY_ESCAPE:
			Game.rebind(_capture, e.physical_keycode)
			Game.save_settings()
		_capture = ""
		_refresh_keys()
		get_viewport().set_input_as_handled()
		return
	if e.is_action_pressed("pause") or e.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	InkTheme.play_ui("ui_back", "ui_move", -7.0)
	Game.save_settings()
	closed.emit()
	queue_free()
