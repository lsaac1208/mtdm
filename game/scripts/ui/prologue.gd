extends Control
## Skippable 3-plate ink-scroll opening prologue played before a story run.
## Automatically bypassed during automated tests or --startx/--autostart runs.

const BRUSH_FONT := preload("res://assets/fonts/MaShanZheng-subset.ttf")
const PLATE_DURATION := 5.2

const SLIDES := [
	{
		"img": "res://assets/ui/prologue_01.webp",
		"heading": "「劫灰落尽，旧道已倾。」",
		"body": "疫雾漫过七镇，残符不再镇祟。山河成冢，人烟断绝。",
		"en": "Ash fell across the seven towns. Broken talismans hold back the dead no more.",
		"pan": Vector2(-14.0, -6.0),
		"y_bias": 0.36,
	},
	{
		"img": "res://assets/ui/prologue_02.webp",
		"heading": "「断碑之下，犹有师门遗篆。」",
		"body": "一道裂符，半截桃木，皆是前人未竟之诺。",
		"en": "Beneath shattered steles lie the last seals of those who walked before.",
		"pan": Vector2(10.0, -14.0),
		"y_bias": 0.04,
	},
	{
		"img": "res://assets/ui/prologue_03.webp",
		"heading": "「一人、一剑、一道，行于废土。」",
		"body": "前路乱葬岗尸气冲霄——既为道行者，便当斩祟封渊。",
		"en": "One wanderer, one blade, one Tao. Beyond the wasteland waits the Undead General.",
		"pan": Vector2(-10.0, -14.0),
		"y_bias": 0.02,
	},
]

var slide_idx := 0
var _slide_t := 0.0
var _t := 0.0
var _finishing := false
var _motes: Array = []
var _plates: Array[Texture2D] = []

var _art_clip: Control
var _art_rect: TextureRect
var _art_base_pos := Vector2(-22.0, -16.0)
var _heading: Label
var _body: Label
var _en: Label
var _skip_lbl: Label
var _motes_draw: Control
var _frame_draw: Control
var _fade: ColorRect
var _text_box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.048, 0.042, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	for s in SLIDES:
		var path := String(s.img)
		var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
		_plates.append(tex)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260401
	for i in 30:
		_motes.append({
			"x": rng.randf_range(0.0, 1280.0),
			"y": rng.randf_range(0.0, 720.0),
			"vx": rng.randf_range(-16.0, -5.0),
			"vy": rng.randf_range(-8.0, 6.0),
			"r": rng.randf_range(1.2, 3.0),
			"ph": rng.randf_range(0.0, TAU),
		})

	_motes_draw = Control.new()
	_motes_draw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_motes_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_motes_draw.draw.connect(_draw_motes)
	add_child(_motes_draw)

	# Framed painted story plate (top-center)
	_art_clip = Control.new()
	_art_clip.clip_contents = true
	_art_clip.position = Vector2(310.0, 56.0)
	_art_clip.size = Vector2(660.0, 412.0)
	add_child(_art_clip)

	_art_rect = TextureRect.new()
	_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_art_rect.size = Vector2(704.0, 444.0)
	_art_rect.position = Vector2(-22.0, -16.0)
	_art_clip.add_child(_art_rect)

	# Ornate brass-and-ink scroll frame + progress pips drawn over plate
	_frame_draw = Control.new()
	_frame_draw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame_draw.draw.connect(_draw_chrome)
	add_child(_frame_draw)

	# Narrative caption block
	_text_box = VBoxContainer.new()
	_text_box.position = Vector2(140.0, 488.0)
	_text_box.size = Vector2(1000.0, 175.0)
	_text_box.add_theme_constant_override("separation", 10)
	add_child(_text_box)

	_heading = Label.new()
	_heading.add_theme_font_override("font", BRUSH_FONT)
	_heading.add_theme_font_size_override("font_size", 42)
	_heading.add_theme_color_override("font_color", Color(0.95, 0.88, 0.74))
	_heading.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.02, 0.92))
	_heading.add_theme_constant_override("outline_size", 6)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_box.add_child(_heading)

	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 21)
	_body.add_theme_color_override("font_color", Color(0.86, 0.80, 0.69))
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_box.add_child(_body)

	_en = Label.new()
	_en.add_theme_font_size_override("font_size", 15)
	_en.add_theme_color_override("font_color", Color(0.64, 0.58, 0.49))
	_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_box.add_child(_en)

	_skip_lbl = Label.new()
	_skip_lbl.position = Vector2(720.0, 676.0)
	_skip_lbl.size = Vector2(530.0, 28.0)
	_skip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_lbl.add_theme_font_size_override("font_size", 15)
	_skip_lbl.add_theme_color_override("font_color", Color(0.72, 0.65, 0.54, 0.88))
	add_child(_skip_lbl)
	Game.prompts_changed.connect(_refresh_prompt)
	_refresh_prompt()

	_fade = ColorRect.new()
	_fade.color = Color(0.03, 0.025, 0.02, 1.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	_show_slide(0)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.65)
	Sfx.play_music("music_title")
	Sfx.play_ambience("amb_wind")


func _refresh_prompt() -> void:
	if _skip_lbl == null:
		return
	_skip_lbl.text = Game.t("按 %s / %s 继续  ·  按 %s 跳过  |  Skip", "%s / %s Continue  ·  %s Skip") % [
		Game.binding_label("confirm", true),
		Game.binding_label("jump", true),
		Game.binding_label("pause", true),
	]


func _show_slide(idx: int) -> void:
	slide_idx = clampi(idx, 0, SLIDES.size() - 1)
	_slide_t = 0.0
	var s: Dictionary = SLIDES[slide_idx]
	var tex: Texture2D = _plates[slide_idx]
	_art_rect.texture = tex
	var clip_sz := _art_clip.size
	var w := clip_sz.x + 44.0
	var h := clip_sz.y + 32.0
	if tex != null and tex.get_width() > 0:
		var aspect := float(tex.get_height()) / float(tex.get_width())
		h = maxf(clip_sz.y + 32.0, w * aspect)
		if h < clip_sz.y + 32.0:
			h = clip_sz.y + 32.0
			w = maxf(clip_sz.x + 44.0, h / maxf(0.1, aspect))
	_art_rect.size = Vector2(w, h)
	var excess_y := maxf(0.0, h - clip_sz.y)
	var bias := float(s.get("y_bias", 0.5))
	_art_base_pos = Vector2(-(w - clip_sz.x) * 0.5, -excess_y * bias)
	_art_rect.position = _art_base_pos
	_heading.text = String(s.heading)   # calligraphy stays Chinese
	# English mode: the translation is the body, the original the small line
	_body.text = String(s.en) if Game.lang == "en" else String(s.body)
	_en.text = String(s.body) if Game.lang == "en" else String(s.en)
	_art_rect.modulate.a = 0.0
	_text_box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_art_rect, "modulate:a", 1.0, 0.65)
	tw.parallel().tween_property(_text_box, "modulate:a", 1.0, 0.60).set_delay(0.15)
	if slide_idx > 0:
		Sfx.play("whisper_chime", -7.0, 0.04)
	_frame_draw.queue_redraw()


func advance() -> void:
	if _finishing:
		return
	if slide_idx + 1 < SLIDES.size():
		Sfx.play("ui_click", -5.0, 0.04)
		_show_slide(slide_idx + 1)
	else:
		skip()


func skip() -> void:
	if _finishing:
		return
	_finishing = true
	Sfx.play("ui_confirm", -2.0)
	if not Game.args.has("test"):
		Game.prologue_seen = true
		Game.save_settings()
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.35)
	tw.tween_callback(Game.new_run)


func _input(e: InputEvent) -> void:
	if _finishing or _t < 0.25:
		return
	if e.is_action_pressed("pause") or e.is_action_pressed("ui_cancel"):
		skip()
		get_viewport().set_input_as_handled()
		return
	if e.is_action_pressed("confirm") or e.is_action_pressed("jump") or e.is_action_pressed("attack"):
		advance()
		get_viewport().set_input_as_handled()
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		advance()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	_slide_t += delta
	var s: Dictionary = SLIDES[slide_idx]
	var pan: Vector2 = s.pan
	var frac := clampf(_slide_t / PLATE_DURATION, 0.0, 1.0)
	var pos := _art_base_pos + pan * frac
	pos.x = clampf(pos.x, _art_clip.size.x - _art_rect.size.x, 0.0)
	pos.y = clampf(pos.y, _art_clip.size.y - _art_rect.size.y, 0.0)
	_art_rect.position = pos
	for m in _motes:
		m.x = float(m.x) + float(m.vx) * delta
		m.y = float(m.y) + (float(m.vy) + sin(_t * 1.4 + float(m.ph)) * 5.0) * delta
		if float(m.x) < -10.0:
			m.x = 1290.0
		if float(m.y) < -10.0:
			m.y = 730.0
		elif float(m.y) > 730.0:
			m.y = -10.0
	_motes_draw.queue_redraw()
	if not _finishing and not Game.args.has("test") and _slide_t >= PLATE_DURATION:
		advance()


func _draw_motes() -> void:
	for m in _motes:
		var r := float(m.r)
		var a := (0.16 + 0.14 * sin(_t * 1.8 + float(m.ph)))
		_motes_draw.draw_circle(Vector2(float(m.x), float(m.y)), r, Color(0.92, 0.80, 0.62, a))


func _draw_chrome() -> void:
	var r := Rect2(Vector2(310.0, 56.0), Vector2(660.0, 412.0))
	var brass := Color(0.76, 0.59, 0.34, 0.88)
	var brass_dim := Color(0.52, 0.40, 0.24, 0.52)
	var cinnabar := Color(0.74, 0.22, 0.14, 0.92)
	# Subtle shadow framing + double brass ink rule
	_frame_draw.draw_rect(r.grow(10.0), Color(0.02, 0.015, 0.012, 0.52), false, 8.0)
	_frame_draw.draw_rect(r.grow(5.0), brass_dim, false, 1.0, true)
	_frame_draw.draw_rect(r, brass, false, 2.0, true)
	# Corner brackets
	var cl := 18.0
	for corner in [
		[r.position, Vector2(1, 0), Vector2(0, 1)],
		[Vector2(r.end.x, r.position.y), Vector2(-1, 0), Vector2(0, 1)],
		[Vector2(r.position.x, r.end.y), Vector2(1, 0), Vector2(0, -1)],
		[r.end, Vector2(-1, 0), Vector2(0, -1)],
	]:
		var p: Vector2 = corner[0]
		var dx: Vector2 = corner[1]
		var dy: Vector2 = corner[2]
		_frame_draw.draw_line(p - dx * 2.0 - dy * 2.0, p + dx * cl, Color(0.95, 0.80, 0.48, 0.95), 2.5, true)
		_frame_draw.draw_line(p - dx * 2.0 - dy * 2.0, p + dy * cl, Color(0.95, 0.80, 0.48, 0.95), 2.5, true)
	# Top-left small chapter tag
	_frame_draw.draw_line(Vector2(310.0, 34.0), Vector2(970.0, 34.0), Color(0.76, 0.59, 0.34, 0.28), 1.0, true)
	# Progress seal pips below text
	var cy := 662.0
	var start_x := 640.0 - float(SLIDES.size() - 1) * 20.0
	for i in SLIDES.size():
		var px := start_x + float(i) * 40.0
		var active := i == slide_idx
		var sz := 7.0 if active else 4.5
		var col := cinnabar if active else brass_dim
		var pts := PackedVector2Array([
			Vector2(px, cy - sz), Vector2(px + sz, cy),
			Vector2(px, cy + sz), Vector2(px - sz, cy),
		])
		_frame_draw.draw_colored_polygon(pts, col)
		if active:
			_frame_draw.draw_polyline(PackedVector2Array([
				Vector2(px, cy - sz - 3.0), Vector2(px + sz + 3.0, cy),
				Vector2(px, cy + sz + 3.0), Vector2(px - sz - 3.0, cy),
				Vector2(px, cy - sz - 3.0),
			]), Color(0.95, 0.80, 0.48, 0.85), 1.2, true)
