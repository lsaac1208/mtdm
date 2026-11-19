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


static var _shared: Theme


static func shared() -> Theme:
	if _shared == null:
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
