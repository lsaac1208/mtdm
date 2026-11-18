class_name Fx
extends RefCounted
## Spawn helpers for combat VFX. All effects are procedural ink/brush shapes
## so they read in the same hand-inked language as the concept art:
## sword qi = cinnabar rim + white-hot core + dry-brush ink tail (spec §3.2).

const SlashFx := preload("res://scripts/fx/slash_fx.gd")
const RingFx := preload("res://scripts/fx/ring_fx.gd")

const C_CINNABAR := Color(0.70, 0.13, 0.09)
const C_GOLD := Color(1.0, 0.78, 0.32)
const C_TAINT := Color(0.62, 0.78, 0.22)
const C_INK := Color(0.07, 0.06, 0.05)
const C_BONE := Color(0.86, 0.82, 0.74)


static func layer() -> Node:
	if Game.level and is_instance_valid(Game.level) and Game.level.has_node("Fx"):
		return Game.level.get_node("Fx")
	return Engine.get_main_loop().current_scene


static func slash(pos: Vector2, facing: int, a0: float, a1: float, radius: float, width: float,
		life := 0.2, rim := C_CINNABAR, core := Color(1, 0.97, 0.9), squash := 1.0) -> Node2D:
	var s := SlashFx.new()
	s.position = pos
	s.facing = facing
	s.a0 = a0
	s.a1 = a1
	s.radius = radius
	s.width = width
	s.life = life
	s.rim = rim
	s.core = core
	s.squash_y = squash
	layer().add_child(s)
	return s


static func ring(pos: Vector2, r0: float, r1: float, color: Color, life := 0.4, width := 10.0, squash := 0.35) -> Node2D:
	var r := RingFx.new()
	r.position = pos
	r.r0 = r0
	r.r1 = r1
	r.color = color
	r.life = life
	r.width = width
	r.squash_y = squash
	layer().add_child(r)
	return r


static func particles(pos: Vector2, amount: int, color: Color, speed := 220.0, spread := 180.0,
		dir := Vector2.UP, gravity := 600.0, life := 0.5, size := 4.0, z := 8) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = maxi(amount, 1)
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = life
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	p.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = ramp
	p.z_index = z
	p.emitting = true
	layer().add_child(p)
	p.finished.connect(p.queue_free)


static func spark(pos: Vector2, color := C_GOLD, n := 10) -> void:
	particles(pos, n, color, 380.0, 70.0, Vector2.UP, 900.0, 0.3, 3.5)


static func hit_ink(pos: Vector2, dir: int, color := C_INK) -> void:
	particles(pos, 14, color, 340.0, 35.0, Vector2(dir, -0.3).normalized(), 900.0, 0.45, 5.0)


static func dust(pos: Vector2, n := 8, dir := Vector2.UP) -> void:
	particles(pos, n, Color(0.55, 0.48, 0.38, 0.55), 110.0, 70.0, dir, -30.0, 0.6, 7.0, 4)


static func ash(pos: Vector2, n := 24, color := Color(0.2, 0.18, 0.16, 0.8)) -> void:
	particles(pos, n, color, 90.0, 80.0, Vector2.UP, -60.0, 1.4, 4.0)


static func splat(pos: Vector2, size := 18.0, color := Color(0.12, 0.05, 0.04, 0.8)) -> void:
	var s = preload("res://scripts/fx/ink_splat.gd").new()
	s.position = pos + Vector2(0, 2)
	s.size = size
	s.color = color
	layer().add_child(s)


static func punch(amount := 0.04, dur := 0.22) -> void:
	if Game.level and is_instance_valid(Game.level) and Game.level.has_method("punch"):
		Game.level.punch(amount, dur)


static func shake(amount: float, dur := 0.2) -> void:
	if Game.level and is_instance_valid(Game.level) and Game.level.has_method("shake"):
		Game.level.shake(amount, dur)


static func float_text(pos: Vector2, text: String, color: Color, size := 26) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
	l.add_theme_constant_override("outline_size", 6)
	l.position = pos - Vector2(60, 20)
	l.size = Vector2(120, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.z_index = 30
	layer().add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 46, 0.8).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.35)
	tw.tween_callback(l.queue_free)
