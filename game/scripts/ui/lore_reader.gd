class_name LoreReader
extends CanvasLayer
## Ink-scroll reading card for a LoreStele. Pauses the tree while open; any of
## confirm / attack / jump / move_up / pause closes it after a short guard so
## the press that opened it can't also close it.

const BRUSH_FONT := preload("res://assets/fonts/MaShanZheng-subset.ttf")
const SERIF := preload("res://assets/fonts/NotoSerifSC-Bold-subset.otf")

var data: Dictionary = {}
var first := true
var _t := 0.0
var _root: Control
var _closing := false
var _was_paused := false


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	get_tree().paused = true
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.modulate.a = 0.0
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.015, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	var sb := InkTheme.scroll_panel(44, 30, 0.94)
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -190
	panel.offset_bottom = 190
	_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var title := Label.new()
	title.text = String(data.get("title", ""))
	title.add_theme_font_override("font", BRUSH_FONT)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.96, 0.82, 0.52))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var en := Label.new()
	en.text = String(data.get("en", "")).to_upper()
	en.add_theme_font_size_override("font_size", 13)
	en.add_theme_color_override("font_color", Color(0.70, 0.60, 0.46))
	en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(en)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(0.76, 0.59, 0.34, 0.5)
	v.add_child(rule)

	var body := Label.new()
	body.text = String(data.get("text", ""))
	body.add_theme_font_override("font", SERIF)
	body.add_theme_font_size_override("font_size", 21)
	body.add_theme_color_override("font_color", Color(0.94, 0.89, 0.79))
	body.add_theme_constant_override("line_spacing", 6)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(560, 0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var en_body := Label.new()
	en_body.text = String(data.get("en_text", ""))
	en_body.add_theme_font_size_override("font_size", 13)
	en_body.add_theme_color_override("font_color", Color(0.62, 0.56, 0.47))
	en_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	en_body.custom_minimum_size = Vector2(560, 0)
	v.add_child(en_body)

	var foot := Label.new()
	var n := Game.lore_read.size()
	foot.text = ("新得碑文　" if first else "") + "残碑 %d / %d　·　%s" % [n, LevelData.LORE.size(), Game.fmt_keys("{attack} 合上")]
	foot.add_theme_font_size_override("font_size", 14)
	foot.add_theme_color_override("font_color", Color(0.86, 0.68, 0.36))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(foot)
	InkTheme.play_ui("whisper_chime" if first else "ui_click", "ui_move", -8.0)


func _process(delta: float) -> void:
	_t += delta
	if _closing:
		_root.modulate.a = move_toward(_root.modulate.a, 0.0, delta * 6.0)
		if _root.modulate.a <= 0.0:
			get_tree().paused = _was_paused
			queue_free()
		return
	_root.modulate.a = move_toward(_root.modulate.a, 1.0, delta * 5.0)


func _input(e: InputEvent) -> void:
	if _closing or _t < 0.3:
		return
	for a in ["confirm", "attack", "jump", "move_up", "pause", "ui_cancel"]:
		if e.is_action_pressed(a):
			close()
			# consumed here so the pause menu doesn't also open on Esc
			get_viewport().set_input_as_handled()
			return


func close() -> void:
	if _closing:
		return
	_closing = true
	# first read: the wanderer reacts in a non-blocking whisper once play resumes
	var r = data.get("react", [])
	if first and r is Array and r.size() == 2:
		var id := "lore_" + String(data.get("id", ""))
		var mood := String(r[0])
		var text := String(r[1])
		get_tree().create_timer(0.6, true, false, true).timeout.connect(
			func(): Game.show_whisper(id, mood, "道行者 · 默语", text, 4.4))
	InkTheme.play_ui("ui_back", "ui_move", -9.0)
