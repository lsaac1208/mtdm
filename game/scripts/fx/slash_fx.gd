extends Node2D
## Brush-stroke sword-qi arc: ink shadow, cinnabar rim, white-hot core,
## with a dry-brush (飞白) broken tail. Angles are in degrees, measured for a
## right-facing swing (0 = forward, -90 = up); mirrored when facing left.

var facing := 1
var a0 := -80.0
var a1 := 40.0
var radius := 90.0
var width := 26.0
var life := 0.2
var rim := Color(0.7, 0.13, 0.09)
var core := Color(1, 0.97, 0.9)
var squash_y := 1.0
var t := 0.0
var _seed := randi()


func _ready() -> void:
	z_index = 12


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _band(head: float, tail: float, r: float, w: float, col: Color, broken: bool) -> void:
	var steps := 28
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	for i in steps + 1:
		var k := float(i) / steps
		var ang := deg_to_rad(lerpf(tail, head, k))
		# stroke is thickest just behind the head, tapering to a hair at the tail
		var ww := w * pow(k, 0.7) * (1.0 - 0.6 * pow(k, 6.0))
		if broken:
			ww *= 0.65 + 0.35 * rng.randf()
		var d := Vector2(cos(ang) * facing, sin(ang) * squash_y)
		outer.append(d * (r + ww * 0.5))
		inner.append(d * (r - ww * 0.5))
	inner.reverse()
	var poly := outer + inner
	draw_colored_polygon(poly, col)


func _draw() -> void:
	var k := t / life
	var sweep := clampf(k / 0.35, 0.0, 1.0)
	var head := lerpf(a0, a1, ease(sweep, 0.4))
	var tail := lerpf(a0, a1, clampf((k - 0.25) / 0.75, 0.0, 1.0) * 0.85)
	var fade := 1.0 - clampf((k - 0.5) / 0.5, 0.0, 1.0)
	_band(head, tail - 10.0, radius + 3.0, width * 1.35, Color(0.05, 0.04, 0.03, 0.55 * fade), true)
	_band(head, tail, radius, width, Color(rim.r, rim.g, rim.b, 0.92 * fade), false)
	_band(head, tail + (head - tail) * 0.25, radius - width * 0.12, width * 0.42, Color(core.r, core.g, core.b, fade), false)
