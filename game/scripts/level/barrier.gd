extends StaticBody2D
## Arena seal: a column of hanging talismans and gold light that blocks the
## player until the encounter is cleared, then burns away.

var t := 0.0
var dying := -1.0
var papers := []


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = Vector2(24, 900)
	cs.shape = s
	cs.position = Vector2(0, -450)
	add_child(cs)
	z_index = 9
	for i in 7:
		papers.append(Vector2(randf_range(-10, 10), -40.0 - i * 62.0 - randf() * 20.0))
	Fx.particles(position + Vector2(0, -150), 20, Color(1, 0.8, 0.4), 260.0, 40.0, Vector2.UP, 0.0, 0.6, 5.0)


func dissolve() -> void:
	dying = 0.0
	collision_layer = 0
	Fx.particles(global_position + Vector2(0, -200), 40, Color(1, 0.7, 0.3), 220.0, 180.0, Vector2.UP, -80.0, 1.0, 6.0)


func _process(delta: float) -> void:
	t += delta
	if dying >= 0.0:
		dying += delta
		if dying > 0.8:
			queue_free()
	queue_redraw()


func _draw() -> void:
	# A ward of light rising from a seal on the ground. It fades upward so it
	# reads as part of the scene, not as a UI ladder framing the screen.
	var a := 1.0 if dying < 0.0 else maxf(0.0, 1.0 - dying / 0.8)
	var pulse := 0.75 + 0.25 * sin(t * 5.0)
	var steps := 14
	for k in steps:
		var y0 := -float(k + 1) * 30.0
		var fade := pow(1.0 - float(k) / steps, 1.6)
		draw_rect(Rect2(-20, y0, 40, 30), Color(1.0, 0.76, 0.34, 0.09 * fade * a * pulse))
		draw_rect(Rect2(-4, y0, 8, 30), Color(1.0, 0.88, 0.58, 0.32 * fade * a * pulse))
	# ground seal
	for k in 3:
		var rx := 34.0 + k * 10.0
		var pts := PackedVector2Array()
		for j in 25:
			var ang := TAU * j / 24.0 + t * (0.6 if k % 2 == 0 else -0.4)
			pts.append(Vector2(cos(ang) * rx, sin(ang) * rx * 0.22 - 2.0))
		draw_polyline(pts, Color(1.0, 0.72, 0.3, (0.55 - k * 0.15) * a * pulse), 1.6)
	# rising motes
	for k in 6:
		var ph := fposmod(t * 0.35 + k * 0.17, 1.0)
		var mx := sin(k * 1.7 + t * 1.3) * 10.0
		draw_circle(Vector2(mx, -ph * 360.0), 2.0 * (1.0 - ph) + 0.6, Color(1.0, 0.85, 0.5, (1.0 - ph) * 0.8 * a))
	# talismans tied on a cord, hanging at staggered heights
	draw_line(Vector2(0, -390), Vector2(0, -24), Color(0.62, 0.14, 0.08, 0.55 * a), 1.6)
	for i in mini(papers.size(), 4):
		var pp: Vector2 = papers[i]
		var y := -70.0 - i * 84.0 + pp.x
		var sw := sin(t * 2.2 + i * 1.3) * 5.0
		var top := Vector2(sw * 0.4, y)
		var poly := PackedVector2Array([top + Vector2(-8, 0), top + Vector2(8, 0),
			top + Vector2(9 + sw * 0.3, 40), top + Vector2(sw * 0.5, 50), top + Vector2(-9 + sw * 0.3, 40)])
		draw_colored_polygon(PackedVector2Array(Array(poly).map(func(v): return v + Vector2(3, 3))), Color(0, 0, 0, 0.18 * a))
		draw_colored_polygon(poly, Color(0.90, 0.78, 0.46, 0.92 * a))
		draw_polyline(PackedVector2Array(Array(poly) + [poly[0]]), Color(0.36, 0.22, 0.10, 0.8 * a), 1.2)
		var c := top + Vector2(sw * 0.15, 0)
		draw_line(c + Vector2(0, 7), c + Vector2(sw * 0.2, 38), Color(0.66, 0.12, 0.08, a), 2.2)
		draw_line(c + Vector2(-5, 15), c + Vector2(5, 15), Color(0.66, 0.12, 0.08, a), 1.8)
		draw_circle(c + Vector2(0, 26), 3.2, Color(0.66, 0.12, 0.08, 0.85 * a))
