extends Node2D
## Taint Puddle (腐秽污染区): 65 px radius, 4.5 s by default. Standing in it
## slows the player and ticks corrosion damage, splitting the arena so the
## player must jump or dash across. Prayer beads purify puddles.
## `permanent` puddles are level hazards in the polluted lowland.

const SURFACE := preload("res://assets/env/painted/mire.webp")

var radius := 65.0
var life := 4.5
var permanent := false
var t := 0.0
var tick := 0.0
var dps := 6.0
var _bubbles := []


func _ready() -> void:
	add_to_group("taint_puddle")
	z_index = 3
	for i in 7:
		_bubbles.append(Vector2(radius * lerpf(-0.78, 0.78, i / 6.0), fmod(i * 0.618, 1.0)))


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
	if r < 3.0:
		return
	# The mineral lip ends exactly at the active horizontal extents.
	var depth := minf(30.0, r * 0.34)
	draw_texture_rect(SURFACE, Rect2(-r, -depth * 0.62, r * 2.0, depth), false, Color(1, 1, 1, fade))
	for bubble in _bubbles:
		var rise := fmod(bubble.y + t * 0.48, 1.0)
		var centre := Vector2(bubble.x * grow + sin(rise * PI) * 1.4, -3.0 - rise * 17.0)
		draw_circle(centre, 3.2 * (1.0 - rise * 0.6),
			Color(0.84, 0.94, 0.42, fade * (1.0 - rise)), false, 1.1, true)
