extends Node2D
## Taint glob (spec §5.3): launch spray -> parabolic flight with drips ->
## impact splash that leaves a Taint Puddle (radius 65 px, 4.5 s).

const GRAV := 900.0
const Puddle := preload("res://scripts/fx/taint_puddle.gd")
var vel := Vector2.ZERO
var owner_actor: Node
var hit_set := {}
var t := 0.0
var trail: CPUParticles2D


func _ready() -> void:
	z_index = 11
	trail = CPUParticles2D.new()
	trail.amount = 30
	trail.lifetime = 0.5
	trail.local_coords = false
	trail.direction = Vector2.DOWN
	trail.spread = 30
	trail.initial_velocity_min = 10
	trail.initial_velocity_max = 50
	trail.gravity = Vector2(0, 500)
	trail.scale_amount_min = 3
	trail.scale_amount_max = 6
	var g := Gradient.new()
	g.set_color(0, Color(0.55, 0.72, 0.18, 0.9))
	g.set_color(1, Color(0.25, 0.35, 0.1, 0))
	trail.color_ramp = g
	add_child(trail)


func _physics_process(delta: float) -> void:
	t += delta
	vel.y += GRAV * delta
	global_position += vel * delta
	queue_redraw()
	var r := Rect2(global_position - Vector2(16, 16), Vector2(32, 32))
	var hits := Combat.strike({"owner": owner_actor, "team": Combat.TEAM_ENEMY, "rect": r, "damage": 14.0,
		"poise": 0.0, "knock": 200.0, "dir": int(signf(vel.x)), "kind": "projectile",
		"from_x": global_position.x - signf(vel.x) * 40, "unblockable": false, "tag": "taint"}, hit_set)
	if hits.size() > 0:
		_impact(true)
		return
	if global_position.y >= _ground_y():
		_impact(false)


func _ground_y() -> float:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -4), global_position + Vector2(0, 2000), 1)
	var res := space.intersect_ray(q)
	if res:
		_last_ground = res.position.y
	return _last_ground


var _last_ground := Game.GROUND_Y


func _impact(on_player: bool) -> void:
	set_physics_process(false)
	trail.emitting = false
	Sfx.play("splat", 0.0)
	Fx.particles(global_position, 22, Color(0.6, 0.78, 0.2, 0.95), 280.0, 70.0, Vector2.UP, 900.0, 0.55, 6.0)
	# the puddle always forms on the ground below the impact
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -30), global_position + Vector2(0, 1500), 1)
	var res := space.intersect_ray(q)
	var gy: float = res.position.y if res else _last_ground
	var pd := Puddle.new()
	pd.global_position = Vector2(global_position.x, gy)
	Fx.layer().add_child(pd)
	if not on_player:
		Fx.shake(1.5, 0.08)
	visible_core = false
	get_tree().create_timer(0.6).timeout.connect(queue_free)


var visible_core := true


func _draw() -> void:
	if not visible_core:
		return
	var a := vel.angle()
	var stretch := 1.0 + minf(vel.length() / 1200.0, 0.5)
	draw_set_transform(Vector2.ZERO, a, Vector2(stretch, 1.0 / stretch))
	draw_circle(Vector2.ZERO, 15.0, Color(0.12, 0.14, 0.06, 0.8))
	draw_circle(Vector2.ZERO, 12.0, Color(0.42, 0.55, 0.14))
	draw_circle(Vector2(3, -3), 6.0, Color(0.75, 0.9, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
