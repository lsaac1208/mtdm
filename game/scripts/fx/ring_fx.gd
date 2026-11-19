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
	t += Game.unscaled_delta(delta)
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
	var ww := w if glyphs == 0 else w * 0.35
	draw_polyline(pts, Color(0.05, 0.04, 0.03, a * 0.5), ww * 1.6, true)
	draw_polyline(pts, Color(color.r, color.g, color.b, a * (1.0 if glyphs == 0 else 0.75)), ww, true)
	if glyphs == 0 and k < 0.65:
		draw_polyline(pts, Color(1.0, 0.98, 0.92, a * 0.65 * (1.0 - k / 0.65)), maxf(1.2, ww * 0.32), true)
	if glyphs > 0:
		for i in glyphs:
			var ang := TAU * i / glyphs + t * 3.0
			var p := Vector2(cos(ang) * r, sin(ang) * r * squash_y)
			var br := clampf(w * 0.55, 3.0, 7.0)
			draw_circle(p, br + 1.2, Color(0.05, 0.03, 0.02, a * 0.8))
			draw_circle(p, br, Color(0.36, 0.07, 0.05, a))
			draw_circle(p + Vector2(-br * 0.35, -br * 0.35), br * 0.35, Color(1.0, 0.82, 0.5, a * 0.9))
