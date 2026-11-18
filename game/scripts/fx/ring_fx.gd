extends Node2D
## Expanding ellipse ring (shockwaves, prayer-bead formation, seal burst).

var r0 := 10.0
var r1 := 120.0
var color := Color(1, 0.8, 0.3)
var life := 0.4
var width := 10.0
var squash_y := 0.35
var t := 0.0
var glyphs := 0      # >0: draw rotating rune ticks (prayer-bead array)


func _ready() -> void:
	z_index = 11


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := t / life
	var r := lerpf(r0, r1, ease(k, 0.35))
	var a := color.a * (1.0 - k)
	var w := width * (1.0 - k * 0.6)
	var pts := PackedVector2Array()
	for i in 49:
		var ang := TAU * i / 48.0
		pts.append(Vector2(cos(ang) * r, sin(ang) * r * squash_y))
	draw_polyline(pts, Color(0.05, 0.04, 0.03, a * 0.5), w * 1.6, true)
	draw_polyline(pts, Color(color.r, color.g, color.b, a), w, true)
	if glyphs > 0:
		for i in glyphs:
			var ang := TAU * i / glyphs + t * 3.0
			var p := Vector2(cos(ang) * r, sin(ang) * r * squash_y)
			draw_circle(p, w * 0.9, Color(0.35, 0.08, 0.06, a))
			draw_circle(p, w * 0.5, Color(1, 0.85, 0.45, a))
