class_name InkTheme
extends RefCounted
## Shared UI skin: ink-wash plates with a cinnabar focus seal and gold edge.
## Replaces Godot's default grey boxes on the title, pause and options menus
## so every screen belongs to the same painted world.

const INK := Color(0.10, 0.08, 0.06, 0.58)
const INK_DEEP := Color(0.07, 0.05, 0.04, 0.82)
const CINNABAR := Color(0.50, 0.12, 0.07, 0.92)
const CINNABAR_DEEP := Color(0.36, 0.08, 0.05, 0.95)
const GOLD := Color(0.86, 0.68, 0.36)
const PAPER := Color(0.95, 0.90, 0.80)
const PAPER_DIM := Color(0.62, 0.58, 0.52)


static func scroll_panel(pad_x := 26, pad_y := 20, alpha := 0.90) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.068, 0.056, 0.046, alpha)
	s.border_color = Color(0.76, 0.59, 0.34, 0.84)
	s.set_border_width_all(1)
	s.border_width_top = 2
	s.set_corner_radius_all(5)
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	s.shadow_size = 16
	s.shadow_offset = Vector2(0, 6)
	s.anti_aliasing = true
	return s


static func inset_card(pad_x := 18, pad_y := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.045, 0.038, 0.032, 0.82)
	s.border_color = Color(0.56, 0.44, 0.27, 0.58)
	s.set_border_width_all(1)
	s.border_width_left = 3
	s.set_corner_radius_all(3)
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	s.anti_aliasing = true
	return s


static func play_ui(name_: String, fallback := "ui_move", vol_db := -7.0) -> void:
	if Sfx._stream(name_) != null:
		Sfx.play(name_, vol_db, 0.03)
	elif fallback != "":
		Sfx.play(fallback, vol_db, 0.03)


static func wire_hover(btn: Control) -> void:
	var armed_ms := Time.get_ticks_msec() + 140
	var cb := func():
		if Time.get_ticks_msec() >= armed_ms and btn.is_visible_in_tree():
			play_ui("ui_hover", "ui_move", -9.0)
	btn.focus_entered.connect(cb)
	btn.mouse_entered.connect(cb)


static func _plate(bg: Color, edge: Color, edge_w: int, shadow := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.border_width_left = edge_w
	s.border_width_bottom = 1 if edge_w > 0 else 0
	s.corner_radius_top_left = 2
	s.corner_radius_bottom_right = 2
	s.content_margin_left = 18
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	s.skew = Vector2(-0.12, 0.0)
	if shadow > 0:
		s.shadow_color = Color(0, 0, 0, 0.28)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(2, 3)
	return s


const BRUSH_FONT := preload("res://assets/fonts/MaShanZheng-subset.ttf")
const SERIF_FONT := preload("res://assets/fonts/NotoSerifSC-Bold-subset.otf")

static var _shared: Theme


static func shared() -> Theme:
	if _shared == null:
		# Ensure glyphs omitted from the brush subset (e.g. '·', '↑') fall back
		# deterministically to the bundled Noto Serif subset on every OS.
		var bf: FontFile = BRUSH_FONT
		if bf.fallbacks.is_empty():
			bf.fallbacks = [SERIF_FONT]
		_shared = build()
	return _shared


static func build() -> Theme:
	var t := Theme.new()
	var normal := _plate(INK, Color(GOLD, 0.0), 0)
	var hover := _plate(CINNABAR, GOLD, 4, 6)
	var pressed := _plate(CINNABAR_DEEP, GOLD, 4, 2)
	var disabled := _plate(Color(INK, 0.3), Color(0, 0, 0, 0), 0)
	for type in ["Button", "OptionButton", "CheckButton", "MenuButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("focus", type, hover)
		t.set_stylebox("disabled", type, disabled)
		t.set_color("font_color", type, PAPER)
		t.set_color("font_hover_color", type, Color(1.0, 0.95, 0.82))
		t.set_color("font_focus_color", type, Color(1.0, 0.95, 0.82))
		t.set_color("font_pressed_color", type, GOLD)
		t.set_color("font_hover_pressed_color", type, GOLD)
		t.set_color("font_disabled_color", type, PAPER_DIM)
		t.set_color("font_outline_color", type, Color(0.05, 0.03, 0.02, 0.7))
		t.set_constant("outline_size", type, 2)
	var popup := _plate(INK_DEEP, GOLD, 1, 8)
	popup.border_width_top = 1
	popup.border_width_right = 1
	popup.skew = Vector2.ZERO
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_stylebox("hover", "PopupMenu", _plate(CINNABAR, GOLD, 3))
	t.set_color("font_color", "PopupMenu", PAPER)
	t.set_color("font_hover_color", "PopupMenu", Color(1.0, 0.95, 0.82))
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.10, 0.08, 0.06, 0.65)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = CINNABAR
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	return t
