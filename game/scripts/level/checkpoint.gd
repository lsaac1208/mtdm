extends Node2D
## 篝火调息点 Campfire checkpoint: rest to heal, refill the gourd and set the
## respawn point.

var cp_id := 0
var t := 0.0
var lit := false
var _rested_at := -100.0
var embers: CPUParticles2D
var light: Node2D


func _ready() -> void:
	z_index = 3
	var tex_path := "res://assets/env/prop_campfire.png"
	if ResourceLoader.exists(tex_path):
		var s := Sprite2D.new()
		s.texture = load(tex_path)
		s.centered = false
		s.scale = Vector2(0.55, 0.55)
		s.position = Vector2(-s.texture.get_width() * 0.275, 8 - s.texture.get_height() * 0.55)
		add_child(s)
	embers = CPUParticles2D.new()
	embers.amount = 26
	embers.lifetime = 1.6
	embers.position = Vector2(0, -22)
	embers.direction = Vector2.UP
	embers.spread = 18
	embers.initial_velocity_min = 30
	embers.initial_velocity_max = 80
	embers.gravity = Vector2(6, -20)
	embers.scale_amount_min = 2
	embers.scale_amount_max = 4
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.75, 0.3, 1))
	g.set_color(1, Color(0.8, 0.2, 0.05, 0))
	embers.color_ramp = g
	add_child(embers)
	lit = Game.checkpoint_id >= cp_id


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	var p = Game.player
	if p == null or not is_instance_valid(p) or p.dead:
		return
	if absf(p.global_position.x - global_position.x) < 70.0 and p.is_on_floor():
		if t - _rested_at > 6.0:
			_rested_at = t
			var first := not lit or Game.checkpoint_id != cp_id
			lit = true
			Game.set_checkpoint(cp_id)
			var needed: bool = p.hp < p.max_hp or p.gourd < p.GOURD_MAX
			p.rest()
			if first or needed:
				Sfx.play("rest", -2.0)
				Game.show_hint("篝火调息 —— 气血已复，葫芦已满，此处记为重生点", 3.5)
				Fx.particles(global_position + Vector2(0, -30), 20, Color(1, 0.85, 0.45), 160.0, 40.0, Vector2.UP, -60.0, 1.0, 5.0)


func _draw() -> void:
	# warm light pool + flame tongues (procedural so it flickers)
	var f := 0.85 + 0.15 * sin(t * 13.0) * sin(t * 7.3)
	for i in 4:
		var r := (150.0 - i * 30.0) * f
		draw_set_transform(Vector2(0, -20), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, r, Color(1.0, 0.6, 0.25, 0.05))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in 3:
		var h := (34.0 - i * 8.0) * f + sin(t * 9.0 + i) * 4.0
		var w := 14.0 - i * 3.0
		var pts := PackedVector2Array([Vector2(-w, -8), Vector2(sin(t * 6.0 + i) * 4.0, -8 - h), Vector2(w, -8)])
		var cols := [Color(0.85, 0.25, 0.08, 0.9), Color(1, 0.6, 0.15, 0.95), Color(1, 0.92, 0.6, 1)]
		draw_colored_polygon(pts, cols[i])
