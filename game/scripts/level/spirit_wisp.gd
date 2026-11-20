class_name SpiritWisp
extends Node2D
## Floating Dao spirit essence dropped by shattered wasteland props.
## Pops in a gentle arc, settles briefly, then curves smoothly into the hero.

var qi_amount := 10.0
var hp_amount := 0.0
var tint := Color(0.76, 0.94, 0.72)
var core := Color(1.0, 0.97, 0.84)
var vel := Vector2.ZERO
var _t := 0.0
var _trail: Array[Vector2] = []
var _collected := false


func _ready() -> void:
	z_index = 11
	if vel == Vector2.ZERO:
		vel = Vector2(randf_range(-95.0, 95.0), randf_range(-240.0, -170.0))
	_trail.append(global_position)


func _physics_process(delta: float) -> void:
	if _collected:
		return
	_t += delta
	if _t > 6.0:
		queue_free()
		return
	var p = Game.player
	var has_player: bool = p != null and is_instance_valid(p) and not p.dead
	if _t < 0.28 or not has_player:
		vel.y += 860.0 * delta
		global_position += vel * delta
		if global_position.y > Game.GROUND_Y - 16.0:
			global_position.y = Game.GROUND_Y - 16.0
			vel.y = -absf(vel.y) * 0.36
			vel.x *= 0.72
	else:
		var target: Vector2 = p.global_position + Vector2(0.0, -68.0)
		var to_p: Vector2 = target - global_position
		var dist := to_p.length()
		if dist < 34.0 or _t > 3.2:
			_collect(p)
			return
		var pull := minf(660.0, 240.0 + (_t - 0.28) * 520.0)
		var desired := to_p.normalized() * pull
		vel = vel.lerp(desired, clampf(delta * 9.5, 0.0, 1.0))
		global_position += vel * delta
	_trail.append(global_position)
	if _trail.size() > 9:
		_trail.remove_at(0)
	queue_redraw()


func _collect(p: Node) -> void:
	_collected = true
	if qi_amount > 0.0 and p.has_method("_gain_qi"):
		p._gain_qi(qi_amount)
	if hp_amount > 0.0 and p.hp < p.max_hp:
		p.hp = minf(p.max_hp, p.hp + hp_amount)
		p.hp_changed.emit(p.hp, p.max_hp)
	Sfx.play("wisp_pickup", -4.0, 0.12)
	Fx.ring(p.global_position + Vector2(0.0, -68.0), 10.0, 44.0, tint, 0.26, 3.0, 0.7)
	Fx.particles(p.global_position + Vector2(0.0, -68.0), 7, core, 110.0, 35.0, Vector2.UP, -40.0, 0.45, 3.5)
	queue_free()


func _draw() -> void:
	if _trail.size() >= 2:
		for i in range(1, _trail.size()):
			var f := float(i) / float(_trail.size())
			var a := _trail[i - 1] - global_position
			var b := _trail[i] - global_position
			draw_line(a, b, Color(tint.r, tint.g, tint.b, f * 0.48), 1.5 + f * 4.5, true)
	var pulse := 1.0 + 0.14 * sin(_t * 14.0)
	draw_circle(Vector2.ZERO, 13.0 * pulse, Color(tint.r, tint.g, tint.b, 0.22))
	draw_circle(Vector2.ZERO, 6.8 * pulse, Color(tint.r, tint.g, tint.b, 0.72))
	draw_circle(Vector2.ZERO, 3.4 * pulse, core)
