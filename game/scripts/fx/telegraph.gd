extends Node2D
## Attack anticipation readability: a brush-flare glint at a body point and an
## optional faint ground danger band, both owned by the enemy (mirrors with
## its facing because positions are given in forward-facing local space).

var flare_pos := Vector2.ZERO
var flare_t := 0.0
var flare_len := 0.0
var flare_col := Color(1, 0.3, 0.2)
var area := Rect2()
var area_t := 0.0
var area_len := 0.0
var area_col := Color(0.8, 0.1, 0.05, 0.25)


func _ready() -> void:
	z_index = 14


func flare(pos: Vector2, dur: float, col := Color(1, 0.35, 0.2)) -> void:
	flare_pos = pos
	flare_t = dur
	flare_len = dur
	flare_col = col


func danger(r: Rect2, dur: float, col := Color(0.75, 0.1, 0.05, 0.22)) -> void:
	area = r
	area_t = dur
	area_len = dur
	area_col = col


func stop() -> void:
	flare_t = 0.0
	area_t = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if flare_t > 0.0 or area_t > 0.0:
		flare_t = maxf(0.0, flare_t - delta)
		area_t = maxf(0.0, area_t - delta)
		queue_redraw()


func _draw() -> void:
	var f: int = get_parent().facing if get_parent() else 1
	if area_t > 0.0:
		var k := 1.0 - area_t / area_len
		var r := area
		var x0 := r.position.x if f > 0 else -r.position.x - r.size.x
		var a := area_col.a * (0.4 + 0.6 * k)
		draw_rect(Rect2(x0, r.position.y, r.size.x, r.size.y), Color(area_col.r, area_col.g, area_col.b, a))
		draw_line(Vector2(x0, -2), Vector2(x0 + r.size.x, -2), Color(0.9, 0.2, 0.1, 0.7 * k + 0.2), 3.0)
	if flare_t > 0.0:
		var k2 := 1.0 - flare_t / flare_len
		var p := Vector2(flare_pos.x * f, flare_pos.y)
		var s := 6.0 + 22.0 * ease(k2, 0.3)
		var a2 := 0.95 if flare_t > 0.08 else flare_t / 0.08
		var c := Color(flare_col.r, flare_col.g, flare_col.b, a2)
		# four-point brush glint
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s * 1.6), p + Vector2(s * 0.22, 0),
			p + Vector2(0, s * 1.6), p + Vector2(-s * 0.22, 0)]), c)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 1.6, 0), p + Vector2(0, s * 0.22),
			p + Vector2(s * 1.6, 0), p + Vector2(0, -s * 0.22)]), c)
		draw_circle(p, s * 0.28, Color(1, 1, 0.92, a2))
