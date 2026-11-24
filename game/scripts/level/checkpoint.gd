extends Node2D
## 篝火调息点 Campfire checkpoint: rest to heal, refill the gourd and set the
## respawn point.

var cp_id := 0
var t := 0.0
var lit := false
var _lit_blend := 0.0
var _ignite_t := 0.0
var _rested_at := -100.0
var embers: CPUParticles2D
var light: Node2D


func _ready() -> void:
	z_index = 3
	var hearth := Sprite2D.new()
	hearth.texture = preload("res://assets/env/painted/hearth.webp")
	hearth.scale = Vector2.ONE * 98.0 / hearth.texture.get_width()
	hearth.offset.y = -hearth.texture.get_height() * 0.5
	hearth.position.y = 5.0
	hearth.show_behind_parent = true
	add_child(hearth)
	embers = CPUParticles2D.new()
	embers.texture = Fx.dot_texture()
	embers.amount = 26
	embers.lifetime = 1.6
	embers.position = Vector2(0, -22)
	embers.direction = Vector2.UP
	embers.spread = 18
	embers.initial_velocity_min = 30
	embers.initial_velocity_max = 80
	embers.gravity = Vector2(6, -20)
	embers.scale_amount_min = 0.133
	embers.scale_amount_max = 0.267
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.75, 0.3, 1))
	g.set_color(1, Color(0.8, 0.2, 0.05, 0))
	embers.color_ramp = g
	add_child(embers)
	lit = Game.checkpoint_id >= cp_id
	_lit_blend = 1.0 if lit else 0.0
	embers.amount = 28 if lit else 8


func _process(delta: float) -> void:
	t += delta
	_lit_blend = move_toward(_lit_blend, 1.0 if lit else 0.0, delta * 2.2)
	if _ignite_t > 0.0:
		_ignite_t = maxf(0.0, _ignite_t - delta * 1.25)
	queue_redraw()
	var p = Game.player
	if p == null or not is_instance_valid(p) or p.dead:
		return
	if absf(p.global_position.x - global_position.x) < 70.0 and p.is_on_floor():
		if t - _rested_at > 6.0:
			_rested_at = t
			var first := not lit or Game.checkpoint_id != cp_id
			lit = true
			embers.amount = 28
			Game.set_checkpoint(cp_id)
			var needed: bool = p.hp < p.max_hp or p.gourd < p.GOURD_MAX
			p.rest()
			if first or needed:
				_ignite_t = 1.0 if first else 0.55
				if first:
					Sfx.play("hearth_ignite", -2.0)
				Sfx.play("rest", -4.5 if first else -2.0)
				Game.show_hint(Game.t("篝火调息 —— 气血已复，葫芦已满，此处记为重生点", "Rest at the campfire — health and gourd restored, progress saved here"), 3.5)
				Fx.particles(global_position + Vector2(0, -30), 26 if first else 18, Color(1, 0.85, 0.45), 190.0, 45.0, Vector2.UP, -85.0, 1.15, 5.4)
				var ring := Fx.ring(global_position + Vector2(0, -24), 16.0, 145.0 if first else 95.0, Color(1.0, 0.82, 0.36), 0.52, 5.0, 0.72)
				ring.glyphs = 8 if first else 0


func _draw() -> void:
	# Warm light pool + flame tongues: low smoldering coals before first rest,
	# dramatic flaring hearth + ceremonial ignition pillar once lit.
	var f := 0.85 + 0.15 * sin(t * 13.0) * sin(t * 7.3)
	var strength := lerpf(0.32, 1.0, _lit_blend) + _ignite_t * 0.55
	for i in 4:
		var r := (150.0 - i * 30.0) * f * lerpf(0.55, 1.08, _lit_blend)
		draw_set_transform(Vector2(0, -20), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, r, Color(1.0, 0.6, 0.25, 0.055 * strength))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _ignite_t > 0.01:
		var col_a := _ignite_t * _ignite_t * 0.42
		var pw := 34.0 * (1.25 - _ignite_t * 0.4)
		var ph := 230.0 * (0.45 + (1.0 - _ignite_t) * 0.75)
		draw_polygon(PackedVector2Array([
			Vector2(-pw * 0.5, -10.0), Vector2(pw * 0.5, -10.0),
			Vector2(pw * 0.22, -ph), Vector2(-pw * 0.22, -ph),
		]), PackedColorArray([
			Color(1.0, 0.84, 0.38, col_a), Color(1.0, 0.84, 0.38, col_a),
			Color(1.0, 0.96, 0.72, 0.0), Color(1.0, 0.96, 0.72, 0.0),
		]))
	for i in 3:
		var x := (i - 1) * 7.0
		var base_h := lerpf(9.0, 30.0, _lit_blend) + _ignite_t * 24.0
		var h := (base_h - absf(x) * 1.1) * f
		var bend := sin(t * 8.0 + i * 1.8) * 3.0
		var base := Vector2(x, -11.0)
		var points := PackedVector2Array([base + Vector2(-6, 0), base + Vector2(-5, -h * 0.38),
			base + Vector2(bend - 2, -h * 0.69), base + Vector2(bend + 2, -h),
			base + Vector2(bend + 4, -h * 0.4), base + Vector2(5, -h * 0.23), base + Vector2(5, 0)])
		draw_colored_polygon(points, Color(1.0, 0.47 + i * 0.09, 0.14, lerpf(0.55, 0.94, _lit_blend)))
	if not lit:
		var hint_a := 0.16 + 0.10 * sin(t * 2.6)
		draw_set_transform(Vector2(0.0, -4.0), 0.0, Vector2(1.0, 0.28))
		draw_arc(Vector2.ZERO, 44.0 + 4.0 * sin(t * 2.6), 0.0, TAU, 24, Color(1.0, 0.78, 0.40, hint_a), 1.6)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
