extends Node2D
## End-of-demo hand-painted weathered stone pailou (牌坊).
## Sealed in pale burial mist until the Corpse General falls, then awakens with
## warm golden sanctuary light rays and ascending spirit motes.

const GATE_TEX := preload("res://assets/env/painted/end_gate_pailou.webp")

var t := 0.0
var _open_blend := 0.0
var _arch: Sprite2D
var _motes: CPUParticles2D


func _ready() -> void:
	z_index = 2
	_open_blend = 1.0 if Game.cleared.has("e8_elite") else 0.0
	_arch = Sprite2D.new()
	_arch.texture = GATE_TEX
	var target_h := 378.0
	var sc := target_h / float(GATE_TEX.get_height())
	_arch.scale = Vector2.ONE * sc
	_arch.offset = Vector2(0.0, -float(GATE_TEX.get_height()) * 0.5)
	_arch.position = Vector2(0.0, 14.0)
	add_child(_arch)
	_motes = CPUParticles2D.new()
	_motes.texture = Fx.dot_texture()
	_motes.amount = 28
	_motes.lifetime = 2.8
	_motes.preprocess = 1.4
	_motes.position = Vector2(0.0, -110.0)
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_motes.emission_rect_extents = Vector2(78.0, 105.0)
	_motes.direction = Vector2.UP
	_motes.spread = 22.0
	_motes.initial_velocity_min = 16.0
	_motes.initial_velocity_max = 46.0
	_motes.gravity = Vector2(4.0, -12.0)
	_motes.scale_amount_min = 0.14
	_motes.scale_amount_max = 0.34
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.90, 0.58, 0.0))
	g.add_point(0.25, Color(1.0, 0.88, 0.52, 0.85))
	g.add_point(0.8, Color(1.0, 0.78, 0.42, 0.55))
	g.set_color(g.get_point_count() - 1, Color(1.0, 0.88, 0.52, 0.0))
	_motes.color_ramp = g
	add_child(_motes)
	_sync_visuals()


func _process(delta: float) -> void:
	t += delta
	var target := 1.0 if Game.cleared.has("e8_elite") else 0.0
	_open_blend = move_toward(_open_blend, target, delta * 0.85)
	_sync_visuals()
	queue_redraw()


func _sync_visuals() -> void:
	if _arch != null:
		var sealed_col := Color(0.70, 0.73, 0.84, 1.0)
		var open_col := Color(1.0, 0.96, 0.88, 1.0)
		_arch.modulate = sealed_col.lerp(open_col, _open_blend)
	if _motes != null:
		_motes.emitting = _open_blend > 0.15
		_motes.modulate.a = clampf(_open_blend, 0.0, 1.0)


func _draw() -> void:
	var pulse := 0.82 + 0.18 * sin(t * 2.2)
	var open_a := lerpf(0.08, 0.85 * pulse, _open_blend)
	# Dawn sanctuary light beams radiating behind the painted stone archway opening.
	var ray_col := Color(0.74, 0.78, 0.90).lerp(Color(1.0, 0.88, 0.56), _open_blend)
	var fan_w := lerpf(72.0, 128.0, _open_blend)
	var rays := PackedVector2Array([
		Vector2(-52.0, -250.0), Vector2(52.0, -250.0),
		Vector2(fan_w, 4.0), Vector2(-fan_w, 4.0),
	])
	draw_polygon(rays, PackedColorArray([
		Color(ray_col.r, ray_col.g, ray_col.b, open_a * 0.04),
		Color(ray_col.r, ray_col.g, ray_col.b, open_a * 0.04),
		Color(ray_col.r, ray_col.g, ray_col.b, open_a * 0.24),
		Color(ray_col.r, ray_col.g, ray_col.b, open_a * 0.24),
	]))
	var core_w := lerpf(24.0, 56.0, _open_blend)
	var core := PackedVector2Array([
		Vector2(-24.0, -242.0), Vector2(24.0, -242.0),
		Vector2(core_w, 2.0), Vector2(-core_w, 2.0),
	])
	draw_polygon(core, PackedColorArray([
		Color(1.0, 0.96, 0.84, open_a * 0.10),
		Color(1.0, 0.96, 0.84, open_a * 0.10),
		Color(1.0, 0.93, 0.74, open_a * 0.36),
		Color(1.0, 0.93, 0.74, open_a * 0.36),
	]))
	# Subtle ground contact shadow + mist so plinths sit into the road.
	draw_set_transform(Vector2(0.0, 4.0), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 175.0, Color(0.08, 0.08, 0.11, 0.34))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for k in 4:
		var w := 420.0 - k * 28.0
		var mist_col := Color(0.76, 0.79, 0.86).lerp(Color(0.95, 0.88, 0.72), _open_blend * 0.55)
		draw_rect(Rect2(-w * 0.5, -16.0 + k * 4.0, w, 18.0), Color(mist_col.r, mist_col.g, mist_col.b, 0.065))
	# Soft sanctuary glow halo on the ground once unsealed.
	if _open_blend > 0.05:
		draw_set_transform(Vector2(0.0, -2.0), 0.0, Vector2(1.0, 0.24))
		draw_circle(Vector2.ZERO, 118.0 * pulse, Color(1.0, 0.86, 0.48, _open_blend * 0.22))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
