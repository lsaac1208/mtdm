extends Node2D
## Taint Puddle (腐秽污染区): 65 px radius, 4.5 s by default. Standing in it
## slows the player and ticks corrosion damage, splitting the arena so the
## player must jump or dash across. Prayer beads purify puddles.
## `permanent` puddles are level hazards in the polluted lowland.

var radius := 65.0
var life := 4.5
var permanent := false
var t := 0.0
var tick := 0.0
var dps := 8.0
var _bubbles := []


func _ready() -> void:
	add_to_group("taint_puddle")
	z_index = 3
	for i in 7:
		_bubbles.append(Vector2(randf_range(-radius * 0.8, radius * 0.8), randf()))


func purify_near(pos: Vector2, r: float) -> void:
	if permanent:
		return
	if absf(pos.x - global_position.x) < r + radius:
		life = minf(life, t + 0.3)
		Fx.particles(global_position + Vector2(0, -6), 12, Color(1, 0.85, 0.5, 0.8), 120.0, 50.0, Vector2.UP, -50.0, 0.6, 5.0)


func _physics_process(delta: float) -> void:
	t += delta
	if not permanent and t >= life:
		queue_free()
		return
	queue_redraw()
	var p = Game.player
	if p and is_instance_valid(p) and not p.dead:
		var feet: Vector2 = p.global_position
		var grow := clampf(t / 0.25, 0.0, 1.0)
		if absf(feet.x - global_position.x) < radius * grow and absf(feet.y - global_position.y) < 14.0 and p.is_on_floor():
			p.in_taint = 0.2
			tick -= delta
			if tick <= 0.0:
				tick = 0.5
				var hs := {}
				Combat.strike({"owner": self, "team": Combat.TEAM_ENEMY, "rect": p.get_hurtbox(), "damage": dps * 0.5,
					"poise": 0.0, "knock": 0.0, "dir": 0, "kind": "hazard", "centre": feet,
					"unblockable": true, "tag": "puddle"}, hs)
		else:
			tick = minf(tick, 0.0)


func _draw() -> void:
	var grow := clampf(t / 0.25, 0.0, 1.0)
	var fade := 1.0 if permanent else clampf((life - t) / 0.6, 0.0, 1.0)
	var r := radius * grow
	var pts := PackedVector2Array()
	for i in 33:
		var ang := PI + PI * i / 32.0
		var wob := 1.0 + 0.06 * sin(i * 1.7 + t * 2.0)
		pts.append(Vector2(cos(ang) * r * wob, sin(ang) * 9.0 * wob + 2.0))
	for i in 33:
		var ang := PI * i / 32.0
		pts.append(Vector2(cos(ang) * r, sin(ang) * 5.0 + 2.0))
	draw_colored_polygon(pts, Color(0.2, 0.26, 0.08, 0.85 * fade))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(p * Vector2(0.82, 0.7))
	draw_colored_polygon(inner, Color(0.42, 0.55, 0.14, 0.75 * fade))
	for b in _bubbles:
		var k: float = fmod(b.y + t * 0.6, 1.0)
		draw_circle(Vector2(b.x * grow, -2 - k * 10.0), 3.0 * (1.0 - k), Color(0.75, 0.9, 0.35, 0.8 * fade * (1.0 - k)))
	# rising miasma
	if randf() < 0.1:
		Fx.particles(global_position + Vector2(randf_range(-r, r) * 0.8, -4), 1, Color(0.5, 0.65, 0.2, 0.35),
			40.0, 20.0, Vector2.UP, -40.0, 1.2, 9.0, 3)
