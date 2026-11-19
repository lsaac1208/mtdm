extends Node2D
## Crisp DNF-inspired combat detail effects rendered in unscaled real time so
## they stay silky-smooth right through impact hit-lag:
##   - "hit"  : oblique blade cut scar + 4-point cross-flash star + kinetic speed needles + hit ring
##   - "glint": sharp calligraphic blade draw/startup glint
##   - "slam" : ground cleave shock flare + ink crack spikes + twin earth-dust shock rings

var mode := "hit"      # "hit" | "glint" | "slam"
var dir := 1
var heavy := false
var cut_angle := -0.35 # radians in forward-facing space
var life := 0.18
var color := Color(0.82, 0.18, 0.10)
var accent := Color(1.0, 0.82, 0.38)
var core := Color(1.0, 0.99, 0.94)
var size := 28.0
var t := 0.0
var _seed := randi()
var _needles: Array = []
var _cracks: Array = []


func _ready() -> void:
	z_index = 14 if mode != "slam" else 11
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	if mode == "hit":
		var n := 10 if heavy else 6
		for i in n:
			var base_a := 0.0 if dir >= 0 else PI
			var spread := rng.randf_range(-1.05, 1.05) if i < n - 2 else rng.randf_range(-PI, PI)
			_needles.append({
				"ang": base_a + spread,
				"dist": rng.randf_range(34.0, 88.0 if heavy else 62.0),
				"len": rng.randf_range(14.0, 32.0 if heavy else 22.0),
				"w": rng.randf_range(1.6, 3.2 if heavy else 2.4),
				"gold": rng.randf() < 0.72,
			})
	elif mode == "slam":
		for i in 7:
			var side := -1.0 if i % 2 == 0 else 1.0
			_cracks.append({
				"dx": side * rng.randf_range(16.0, 62.0) * size,
				"dy": rng.randf_range(-4.0, 5.0),
				"mid_y": rng.randf_range(-6.0, 6.0),
				"w": rng.randf_range(1.4, 2.8),
			})


func _process(delta: float) -> void:
	t += Game.unscaled_delta(delta)
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _diamond(p: Vector2, ax: Vector2, half_l: float, half_w: float, col: Color) -> void:
	if half_l < 1.0 or half_w < 0.4 or col.a <= 0.01:
		return
	var perp := Vector2(-ax.y, ax.x)
	draw_colored_polygon(PackedVector2Array([
		p + ax * half_l, p + perp * half_w, p - ax * half_l, p - perp * half_w
	]), col)


func _draw() -> void:
	var k := clampf(t / maxf(life, 0.001), 0.0, 1.0)
	match mode:
		"glint":
			_draw_glint(k)
		"slam":
			_draw_slam(k)
		_:
			_draw_hit(k)


func _draw_hit(k: float) -> void:
	var pop := ease(clampf(k / 0.16, 0.0, 1.0), 0.25)
	var fade := 1.0 - smoothstep(0.22, 1.0, k)
	var flash_a := 1.0 - smoothstep(0.0, 0.42, k)
	var sc := 1.35 if heavy else 1.0

	# 1. Brief blazing core impact flash disc (first 2-3 frames)
	if flash_a > 0.02:
		draw_circle(Vector2.ZERO, (24.0 if heavy else 16.0) * pop * sc, Color(accent.r, accent.g, accent.b, 0.36 * flash_a))
		draw_circle(Vector2.ZERO, (13.0 if heavy else 9.0) * pop * sc, Color(core.r, core.g, core.b, 0.92 * flash_a))

	# 2. Expanding crisp hit ripple ring
	var ring_r := lerpf(8.0, (54.0 if heavy else 36.0) * sc, ease(k, 0.32))
	var ring_a := (1.0 - k) * (0.78 if heavy else 0.56)
	var pts := PackedVector2Array()
	for i in 29:
		var ang := TAU * i / 28.0
		pts.append(Vector2(cos(ang) * ring_r, sin(ang) * ring_r * (0.85 if heavy else 0.95)))
	draw_polyline(pts, Color(color.r, color.g, color.b, ring_a * 0.65), (3.8 if heavy else 2.4) * (1.0 - k * 0.65), true)
	draw_polyline(pts, Color(core.r, core.g, core.b, ring_a), (1.6 if heavy else 1.1) * (1.0 - k * 0.5), true)

	# 3. Primary razor oblique slash cut scar ripping through the enemy
	var ang := cut_angle * dir
	var ax := Vector2.RIGHT.rotated(ang)
	var cut_len := (64.0 if heavy else 44.0) * sc * pop
	var cut_w := (8.5 if heavy else 5.5) * sc * (1.0 - k * 0.82)
	_diamond(Vector2.ZERO, ax, cut_len * 1.18, cut_w * 1.65, Color(color.r, color.g, color.b, 0.72 * fade))
	_diamond(Vector2.ZERO, ax, cut_len, cut_w * 0.95, Color(accent.r, accent.g, accent.b, 0.92 * fade))
	_diamond(Vector2.ZERO, ax, cut_len * 0.88, cut_w * 0.45, Color(core.r, core.g, core.b, 1.0 * fade))

	# 4. Perpendicular DNF cross-flash star
	var cross_ax := Vector2(-ax.y, ax.x)
	var cross_l := (36.0 if heavy else 24.0) * sc * pop * (1.0 - k * 0.4)
	var cross_w := (4.8 if heavy else 3.2) * sc * (1.0 - k * 0.85)
	_diamond(Vector2.ZERO, cross_ax, cross_l * 1.12, cross_w * 1.4, Color(accent.r, accent.g, accent.b, 0.62 * fade))
	_diamond(Vector2.ZERO, cross_ax, cross_l, cross_w * 0.65, Color(core.r, core.g, core.b, 0.95 * fade))

	# 5. Directional tapered kinetic spark needles
	var travel := ease(k, 0.32)
	for nd in _needles:
		var v := Vector2.RIGHT.rotated(float(nd.ang))
		var head := v * (float(nd.dist) * travel + 10.0)
		var nlen: float = float(nd.len) * (1.0 - k * 0.62)
		var tail := head - v * nlen
		var na := (1.0 - smoothstep(0.25, 1.0, k)) * 0.95
		var ncol := Color(accent.r, accent.g, accent.b, na) if bool(nd.gold) else Color(color.r, color.g, color.b, na)
		draw_line(head, tail, ncol, float(nd.w) * (1.0 - k * 0.55), true)
		draw_line(head, head.lerp(tail, 0.45), Color(core.r, core.g, core.b, na), maxf(1.0, float(nd.w) * 0.45), true)


func _draw_glint(k: float) -> void:
	var pulse := sin(k * PI)
	var ax := Vector2.RIGHT.rotated(deg_to_rad(-18.0 * dir))
	var ay := Vector2(-ax.y, ax.x)
	_diamond(Vector2.ZERO, ax, size * 1.35 * pulse, size * 0.16 * pulse, Color(accent.r, accent.g, accent.b, 0.58 * pulse))
	_diamond(Vector2.ZERO, ax, size * pulse, size * 0.09 * pulse, Color(core.r, core.g, core.b, 0.98 * pulse))
	_diamond(Vector2.ZERO, ay, size * 0.65 * pulse, size * 0.09 * pulse, Color(core.r, core.g, core.b, 0.92 * pulse))
	draw_circle(Vector2.ZERO, size * 0.15 * pulse, Color(core.r, core.g, core.b, 0.95 * pulse))


func _draw_slam(k: float) -> void:
	var expand := ease(k, 0.30)
	var fade := 1.0 - smoothstep(0.32, 1.0, k)
	var flash := 1.0 - smoothstep(0.0, 0.32, k)
	# Ground impact hot flare
	if flash > 0.02:
		_diamond(Vector2.ZERO, Vector2.RIGHT, 62.0 * size * (0.6 + 0.5 * expand), 11.0 * size * flash,
			Color(accent.r, accent.g, accent.b, 0.55 * flash))
		_diamond(Vector2.ZERO, Vector2.RIGHT, 42.0 * size * (0.6 + 0.5 * expand), 5.0 * size * flash,
			Color(core.r, core.g, core.b, 0.92 * flash))
	# Crisp jagged ground ink cracks
	for cr in _cracks:
		var tip := Vector2(cr.dx * minf(1.0, k * 6.0), cr.dy)
		var mid := Vector2(tip.x * 0.52, cr.mid_y)
		draw_polyline(PackedVector2Array([Vector2.ZERO, mid, tip]), Color(0.08, 0.06, 0.05, 0.72 * fade), cr.w, true)
	# Flattened ground shockwave ellipses
	for pass_i in 2:
		var r := lerpf(12.0, (92.0 if pass_i == 0 else 64.0) * size, expand)
		var pts := PackedVector2Array()
		for i in 33:
			var ang := TAU * i / 32.0
			pts.append(Vector2(cos(ang) * r, sin(ang) * r * 0.22))
		var col := Color(0.18, 0.14, 0.11, 0.65 * fade) if pass_i == 0 else Color(accent.r, accent.g, accent.b, 0.78 * fade)
		draw_polyline(pts, col, (6.0 if pass_i == 0 else 2.8) * (1.0 - k * 0.6), true)
