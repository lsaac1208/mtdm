extends Node2D
## 08 符箓攻击: thrown talisman with gold-fire trail. Seeks the nearest enemy
## hurtbox centre ahead of the thrower, so it can reach low targets (spec:
## Taoist skills cover all heights). Poise 20 interrupts a Spitter wind-up.

var dir := 1
var owner_actor: Node
var speed := 780.0
var life := 0.95
var vel := Vector2.ZERO
var hit_set := {}
var spr: Sprite2D
var trail: CPUParticles2D


func _ready() -> void:
	z_index = 11
	vel = Vector2(speed * dir, 0)
	spr = Sprite2D.new()
	spr.texture = PoseSprite.tex("icon_talisman")
	spr.scale = Vector2(0.34, 0.34)
	spr.rotation = deg_to_rad(90 * dir)
	add_child(spr)
	trail = CPUParticles2D.new()
	trail.texture = Fx.dot_texture()
	trail.amount = 40
	trail.lifetime = 0.35
	trail.local_coords = false
	trail.direction = Vector2(-dir, 0)
	trail.spread = 25
	trail.initial_velocity_min = 30
	trail.initial_velocity_max = 90
	trail.gravity = Vector2(0, -80)
	trail.scale_amount_min = 0.200
	trail.scale_amount_max = 0.467
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.85, 0.4, 1))
	g.set_color(1, Color(0.8, 0.2, 0.05, 0))
	trail.color_ramp = g
	add_child(trail)


func _target() -> Node:
	var best: Node = null
	var bd := 1e9
	for e in Combat.enemies_alive():
		var hb: Rect2 = e.get_hurtbox()
		var c := hb.get_center()
		var dx := (c.x - global_position.x) * dir
		if dx < -10 or dx > 620 or absf(c.y - global_position.y) > 260:
			continue
		var d := global_position.distance_to(c)
		if d < bd:
			bd = d
			best = e
	return best


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_burst(false)
		return
	var t := _target()
	if t:
		var c: Vector2 = t.get_hurtbox().get_center()
		var want := (c - global_position).normalized() * speed
		vel = vel.lerp(want, minf(1.0, delta * 7.0))
	global_position += vel * delta
	spr.rotation = vel.angle() + PI / 2
	spr.scale = Vector2(0.34, 0.34) * (1.0 + 0.08 * sin(life * 40.0))
	var r := Rect2(global_position - Vector2(20, 14), Vector2(40, 28))
	var hits := Combat.strike({"owner": owner_actor, "team": Combat.TEAM_PLAYER, "rect": r, "damage": 12.0,
		"poise": 20.0, "knock": 160.0, "dir": int(signf(vel.x)) if vel.x != 0 else dir, "kind": "projectile",
		"from_x": global_position.x - signf(vel.x) * 30, "unblockable": false, "tag": "talisman"}, hit_set)
	if hits.size() > 0:
		for h in hits:
			if h.has_method("ignite"):
				h.ignite(3.0)
		if is_instance_valid(owner_actor) and owner_actor.has_method("register_hit"):
			owner_actor.register_hit(hits.size())
		Game.hitstop(0.04)
		_burst(true)
	elif global_position.y > Game.GROUND_Y + 40:
		_burst(false)


func _burst(hit: bool) -> void:
	Fx.spark(global_position, Fx.C_GOLD, 16 if hit else 8)
	Fx.ring(global_position, 4.0, 46.0 if hit else 26.0, Color(1, 0.75, 0.3), 0.25, 5.0, 1.0)
	if hit:
		Sfx.play("talisman_hit", -2.0)
	set_physics_process(false)
	trail.emitting = false
	spr.visible = false
	get_tree().create_timer(0.4).timeout.connect(queue_free)
