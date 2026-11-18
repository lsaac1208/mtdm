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
	var a := 1.0 if dying < 0.0 else maxf(0.0, 1.0 - dying / 0.8)
	var pulse := 0.75 + 0.25 * sin(t * 5.0)
	draw_rect(Rect2(-14, -520, 28, 520), Color(1.0, 0.78, 0.35, 0.10 * a * pulse))
	draw_rect(Rect2(-5, -520, 10, 520), Color(1.0, 0.85, 0.5, 0.28 * a * pulse))
	draw_line(Vector2(0, -520), Vector2(0, 0), Color(0.6, 0.12, 0.08, 0.8 * a), 2.0)
	for i in papers.size():
		var pp: Vector2 = papers[i]
		var sw := sin(t * 2.5 + i) * 4.0
		var r := Rect2(pp.x - 9 + sw, pp.y, 18, 44)
		draw_rect(r, Color(0.88, 0.76, 0.45, a))
		draw_rect(r, Color(0.3, 0.2, 0.1, a), false, 1.5)
		draw_line(r.position + Vector2(9, 6), r.position + Vector2(9, 38), Color(0.65, 0.12, 0.08, a), 2.5)
		draw_line(r.position + Vector2(4, 14), r.position + Vector2(14, 14), Color(0.65, 0.12, 0.08, a), 2.0)
