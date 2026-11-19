extends Node2D
## The sealed road beyond the burial mound. Glows once the elite falls; the
## player walks into the light to finish the demo.

var t := 0.0


func _ready() -> void:
	z_index = 1


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


const STONE_LIT := Color(0.50, 0.50, 0.54)
const STONE := Color(0.34, 0.34, 0.38)
const STONE_DARK := Color(0.20, 0.20, 0.24)
const MOSS := Color(0.30, 0.34, 0.28, 0.55)


## Vertical stone member lit from the upper left, shaded on the right, so the
## gate reads as weathered rock inside the burial-mound mist rather than as a
## flat black rectangle.
func _stone(r: Rect2) -> void:
	var lt := r.position
	var rt := r.position + Vector2(r.size.x, 0)
	var rb := r.end
	var lb := r.position + Vector2(0, r.size.y)
	var mid := r.size.x * 0.38
	draw_polygon(PackedVector2Array([lt, lt + Vector2(mid, 0), lb + Vector2(mid, 0), lb]),
		PackedColorArray([STONE_LIT, STONE, STONE, STONE_LIT.darkened(0.25)]))
	draw_polygon(PackedVector2Array([lt + Vector2(mid, 0), rt, rb, lb + Vector2(mid, 0)]),
		PackedColorArray([STONE, STONE_DARK, STONE_DARK.darkened(0.2), STONE.darkened(0.15)]))
	draw_rect(r, Color(0.08, 0.08, 0.1, 0.55), false, 1.5)


func _draw() -> void:
	var open := Game.cleared.has("e8_elite")
	var a := 0.55 + 0.25 * sin(t * 2.0) if open else 0.10
	# light of the opened road
	draw_rect(Rect2(-62, -330, 124, 330), Color(1.0, 0.85, 0.55, a * 0.18))
	draw_rect(Rect2(-26, -330, 52, 330), Color(1.0, 0.92, 0.7, a * 0.32))
	draw_rect(Rect2(-8, -330, 16, 330), Color(1.0, 0.97, 0.86, a * 0.4))
	# pillars on plinths, with cracks and moss
	for x in [-96.0, 96.0]:
		_stone(Rect2(x - 26, -34, 52, 34))
		_stone(Rect2(x - 15, -292, 30, 260))
		for k in 4:
			var cy := -60.0 - k * 58.0 - fposmod(x, 23.0)
			draw_line(Vector2(x - 13, cy), Vector2(x - 3, cy + 9), STONE_DARK, 1.2)
			draw_line(Vector2(x - 3, cy + 9), Vector2(x + 6, cy + 4), STONE_DARK, 1.0)
		draw_rect(Rect2(x - 15, -46, 30, 12), MOSS)
	# lower tie beam and upper lintel
	_stone(Rect2(-124, -262, 248, 16))
	_stone(Rect2(-142, -306, 284, 20))
	# upturned eave roof
	var roof := PackedVector2Array([
		Vector2(-172, -300), Vector2(-150, -312), Vector2(-120, -330), Vector2(0, -350),
		Vector2(120, -330), Vector2(150, -312), Vector2(172, -300), Vector2(140, -304),
		Vector2(0, -334), Vector2(-140, -304)])
	draw_colored_polygon(roof, STONE_DARK)
	for k in range(-6, 7):
		var x0 := k * 22.0
		draw_line(Vector2(x0, -336 + absf(x0) * 0.13), Vector2(x0 * 1.05, -322 + absf(x0) * 0.1), Color(0.12, 0.12, 0.15, 0.8), 1.0)
	draw_polyline(PackedVector2Array([Vector2(-172, -300), Vector2(-120, -330), Vector2(0, -350), Vector2(120, -330), Vector2(172, -300)]), STONE_LIT.darkened(0.1), 2.0)
	# sealed plaque: dull before the elite falls, glowing cinnabar after
	var plaque := Rect2(-34, -290, 68, 28)
	draw_rect(plaque.grow(3), Color(0.62, 0.50, 0.28) if open else Color(0.32, 0.28, 0.22))
	draw_rect(plaque, Color(0.62, 0.14, 0.08) if open else Color(0.30, 0.11, 0.08))
	if open:
		draw_rect(plaque.grow(8), Color(1.0, 0.8, 0.45, a * 0.25), false, 4.0)
	# ground mist so the gate settles into the fog instead of standing on it
	for k in 5:
		draw_rect(Rect2(-190 + k * 6, -18 + k * 3, 380 - k * 12, 22), Color(0.78, 0.80, 0.86, 0.07))
