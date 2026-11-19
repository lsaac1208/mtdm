extends Node2D
## Multi-layered DNF-inspired calligraphic sword-qi VFX (arc / cleave / thrust / dash).
## Uses per-vertex alpha/color gradients, outer energy bloom, dry-brush ink bristles,
## wind-shear filaments, tip flares, and unscaled-time animation so slashes stay crisp
## and fluid even during impact hit-lag.

var facing := 1
var a0 := -80.0
var a1 := 40.0
var radius := 90.0
var width := 26.0
var life := 0.24
var rim := Color(0.78, 0.16, 0.10)
var core := Color(1.0, 0.98, 0.92)
var accent := Color(1.0, 0.78, 0.34)
var squash_y := 1.0
var style := "arc"   # "arc" | "cleave" | "thrust" | "dash"
var tilt := 0.0      # radians, mirrored by facing
var length := 165.0  # forward reach for thrust / dash styles
var t := 0.0
var _seed := randi()
var _sparks: Array = []


func _ready() -> void:
	z_index = 12
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var count := 9 if style in ["cleave", "thrust", "dash"] else 6
	for i in count:
		_sparks.append({
			"k": rng.randf_range(0.18, 0.96),
			"r_off": rng.randf_range(-0.35, 0.55),
			"v_rad": rng.randf_range(35.0, 110.0),
			"v_tan": rng.randf_range(40.0, 150.0),
			"len": rng.randf_range(9.0, 24.0),
			"w": rng.randf_range(1.4, 3.0),
			"gold": rng.randf() < 0.65,
		})


func _process(delta: float) -> void:
	t += Game.unscaled_delta(delta)
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _arc_pt(ang_deg: float, r: float) -> Vector2:
	var ang := deg_to_rad(ang_deg)
	var p := Vector2(cos(ang) * r, sin(ang) * r * squash_y)
	if tilt != 0.0:
		p = p.rotated(tilt)
	p.x *= facing
	return p


func _grad_band(head: float, tail: float, r_mid: float, w: float,
		col_outer: Color, col_inner: Color, dry_brush: bool, tip_pinch := 0.25) -> void:
	if absf(head - tail) < 1.5 or w <= 0.4:
		return
	var steps := 30
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var a_mul: Array[float] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + (31 if dry_brush else 7)
	for i in steps + 1:
		var k := float(i) / steps
		var ang_deg := lerpf(tail, head, k)
		var body_taper := pow(k, 0.62) * (1.0 - (1.0 - tip_pinch) * pow(k, 5.5))
		var ww := w * body_taper
		if dry_brush:
			ww *= 0.55 + 0.55 * rng.randf()
		var r_out := r_mid + ww * 0.42
		var r_in := r_mid - ww * 0.58
		outer.append(_arc_pt(ang_deg, r_out))
		inner.append(_arc_pt(ang_deg, r_in))
		var edge_a := smoothstep(0.0, 0.24, k) * (1.0 - 0.15 * pow(k, 8.0))
		if dry_brush and rng.randf() < 0.16:
			edge_a *= 0.38
		a_mul.append(edge_a)
	for i in steps:
		var q := PackedVector2Array([outer[i], outer[i + 1], inner[i + 1], inner[i]])
		if (q[0] - q[3]).length() < 0.25 and (q[1] - q[2]).length() < 0.25:
			continue
		var a0m := a_mul[i]
		var a1m := a_mul[i + 1]
		var c_o0 := Color(col_outer.r, col_outer.g, col_outer.b, col_outer.a * a0m)
		var c_o1 := Color(col_outer.r, col_outer.g, col_outer.b, col_outer.a * a1m)
		var c_i1 := Color(col_inner.r, col_inner.g, col_inner.b, col_inner.a * a1m)
		var c_i0 := Color(col_inner.r, col_inner.g, col_inner.b, col_inner.a * a0m)
		draw_primitive(q, PackedColorArray([c_o0, c_o1, c_i1, c_i0]), PackedVector2Array())


func _draw_filament(head: float, tail: float, r: float, w: float, col: Color) -> void:
	if absf(head - tail) < 3.0 or col.a <= 0.01:
		return
	var steps := 18
	var pts := PackedVector2Array()
	for i in steps + 1:
		var k := float(i) / steps
		pts.append(_arc_pt(lerpf(tail, head, k), r))
	draw_polyline(pts, col, w, true)


func _draw_star(pos: Vector2, r_long: float, r_short: float, rot: float, col_core: Color, col_outer: Color) -> void:
	if r_long < 2.0 or col_core.a <= 0.01:
		return
	for pass_idx in 2:
		var sc := 1.45 if pass_idx == 0 else 1.0
		var col := col_outer if pass_idx == 0 else col_core
		var rl := r_long * sc
		var rs := r_short * sc
		var w0 := maxf(1.5, rs * 0.24)
		var w1 := maxf(1.2, rl * 0.11)
		var ax := Vector2.RIGHT.rotated(rot)
		var ay := Vector2.DOWN.rotated(rot)
		draw_colored_polygon(PackedVector2Array([
			pos + ax * rl, pos + ay * w1, pos - ax * rl, pos - ay * w1
		]), col)
		draw_colored_polygon(PackedVector2Array([
			pos + ay * rs, pos + ax * w0, pos - ay * rs, pos - ax * w0
		]), col)


func _draw() -> void:
	var k := clampf(t / maxf(life, 0.001), 0.0, 1.0)
	match style:
		"thrust":
			_draw_thrust(k)
		"dash":
			_draw_dash_slash(k)
		_:
			_draw_arc_slash(k, style == "cleave")


func _draw_arc_slash(k: float, is_cleave: bool) -> void:
	var sweep := ease(clampf(k / 0.22, 0.0, 1.0), 0.28)
	var chase := ease(clampf((k - 0.14) / 0.78, 0.0, 1.0), 1.65) * 0.94
	var head := lerpf(a0, a1, sweep)
	var tail := lerpf(a0, a1, chase)
	var fade := 1.0 - smoothstep(0.36, 1.0, k)
	var core_fade := 1.0 - smoothstep(0.18, 0.82, k)
	var bloom_w := width * (1.72 if is_cleave else 1.55)
	var span := head - tail

	_grad_band(head, tail - signf(span) * 12.0, radius + width * 0.12, bloom_w,
		Color(accent.r, accent.g, accent.b, 0.34 * fade),
		Color(rim.r, rim.g, rim.b, 0.0), false, 0.18)

	_grad_band(head - span * 0.05, tail - signf(span) * 18.0, radius - width * 0.08, width * 1.28,
		Color(0.05, 0.04, 0.035, 0.62 * fade),
		Color(0.05, 0.04, 0.035, 0.0), true, 0.12)
	if is_cleave:
		_grad_band(head, tail - signf(span) * 10.0, radius + width * 0.28, width * 0.55,
			Color(0.06, 0.04, 0.03, 0.45 * fade),
			Color(0.06, 0.04, 0.03, 0.0), true, 0.08)

	_grad_band(head, tail, radius, width * (1.12 if is_cleave else 1.0),
		Color(rim.r, rim.g, rim.b, 0.96 * fade),
		Color(accent.r, accent.g, accent.b, 0.18 * fade), false, 0.10)

	_grad_band(head, tail + span * 0.18, radius + width * 0.14, width * 0.54,
		Color(accent.r, accent.g, accent.b, 0.92 * fade),
		Color(rim.r, rim.g, rim.b, 0.05 * fade), false, 0.06)

	_grad_band(head, tail + span * 0.34, radius + width * 0.24, width * 0.30,
		Color(core.r, core.g, core.b, 1.0 * core_fade),
		Color(accent.r, accent.g, accent.b, 0.0), false, 0.03)

	_draw_filament(head + signf(span) * 4.0, tail + span * 0.22, radius + width * 0.48, 1.8,
		Color(core.r, core.g, core.b, 0.58 * core_fade))
	_draw_filament(head - span * 0.10, tail - signf(span) * 8.0, radius - width * 0.44, 1.5,
		Color(rim.r, rim.g, rim.b, 0.48 * fade))

	if k < 0.45:
		var tf := 1.0 - k / 0.45
		var tip_pos := _arc_pt(head, radius + width * 0.20)
		var prev_pos := _arc_pt(head - signf(span) * 8.0, radius + width * 0.20)
		var tip_ang := (tip_pos - prev_pos).angle()
		_draw_star(tip_pos, (24.0 + width * 0.42) * tf, (7.0 + width * 0.12) * tf, tip_ang,
			Color(core.r, core.g, core.b, 0.95 * tf),
			Color(accent.r, accent.g, accent.b, 0.42 * tf))

	for sp in _sparks:
		var sp_k: float = float(sp.k)
		var spawn_k: float = sp_k * 0.26
		if k < spawn_k:
			continue
		var sk := clampf((k - spawn_k) / maxf(1.0 - spawn_k, 0.15), 0.0, 1.0)
		var ang_deg := lerpf(a0, a1, sp_k)
		var r_off: float = float(sp.r_off)
		var base := _arc_pt(ang_deg, radius + width * r_off)
		var next_p := _arc_pt(ang_deg + signf(a1 - a0) * 5.0, radius + width * r_off)
		var tan_dir := (next_p - base).normalized()
		var rad_dir := base.normalized() if base.length() > 1.0 else Vector2(facing, 0)
		var drift: Vector2 = (tan_dir * float(sp.v_tan) + rad_dir * float(sp.v_rad)) * ease(sk, 0.45) * life
		var p0 := base + drift
		var slen: float = float(sp.len) * (1.0 - sk * 0.65)
		var p1 := p0 - (tan_dir * 0.75 + rad_dir * 0.25).normalized() * slen
		var sa := (1.0 - sk) * 0.9
		var is_gold: bool = bool(sp.gold)
		var sw: float = float(sp.w)
		var scol := Color(accent.r, accent.g, accent.b, sa) if is_gold else Color(0.08, 0.05, 0.04, sa * 0.8)
		draw_line(p0, p1, scol, sw * (1.0 - sk * 0.5), true)
		if is_gold and sk < 0.55:
			draw_line(p0, p0.lerp(p1, 0.45), Color(core.r, core.g, core.b, sa), maxf(1.0, sw * 0.45), true)


func _draw_thrust(k: float) -> void:
	var extend := ease(clampf(k / 0.15, 0.0, 1.0), 0.25)
	var fade := 1.0 - smoothstep(0.28, 1.0, k)
	var core_fade := 1.0 - smoothstep(0.14, 0.78, k)
	var tip_x := facing * length * extend
	var tail_x := facing * lerpf(-26.0, length * 0.55, ease(clampf((k - 0.18) / 0.82, 0.0, 1.0), 1.5))
	var mid_x := lerpf(tail_x, tip_x, 0.38)
	var half_w := width * (1.05 - 0.35 * k)

	_draw_spear(tail_x - facing * 14.0, mid_x, tip_x + facing * 16.0, half_w * 1.65,
		Color(accent.r, accent.g, accent.b, 0.28 * fade),
		Color(rim.r, rim.g, rim.b, 0.0))
	_draw_spear(tail_x - facing * 18.0, mid_x, tip_x + facing * 6.0, half_w * 1.15,
		Color(0.06, 0.04, 0.035, 0.56 * fade),
		Color(0.06, 0.04, 0.035, 0.0))
	_draw_spear(tail_x, mid_x, tip_x + facing * 10.0, half_w * 0.88,
		Color(rim.r, rim.g, rim.b, 0.94 * fade),
		Color(accent.r, accent.g, accent.b, 0.18 * fade))
	_draw_spear(lerpf(tail_x, mid_x, 0.35), lerpf(mid_x, tip_x, 0.25), tip_x + facing * 18.0, half_w * 0.34,
		Color(core.r, core.g, core.b, 1.0 * core_fade),
		Color(accent.r, accent.g, accent.b, 0.10 * core_fade))

	for idx in 3:
		var rk := clampf((k - idx * 0.045) / 0.72, 0.0, 1.0)
		if rk <= 0.0 or rk >= 1.0:
			continue
		var rx := facing * length * (0.20 + idx * 0.27) * extend
		var rad_y := lerpf(10.0, 38.0 - idx * 6.0, ease(rk, 0.3))
		var rad_x := rad_y * 0.28
		var ra := (1.0 - rk) * (0.85 - idx * 0.12)
		var pts := PackedVector2Array()
		for i in 25:
			var ang := TAU * i / 24.0
			pts.append(Vector2(rx + cos(ang) * rad_x, sin(ang) * rad_y))
		draw_polyline(pts, Color(rim.r, rim.g, rim.b, ra * 0.7), (4.2 - idx * 0.8) * (1.0 - rk * 0.6), true)
		draw_polyline(pts, Color(core.r, core.g, core.b, ra), (1.8 - idx * 0.3) * (1.0 - rk * 0.5), true)

	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + 99
	for i in 7:
		var y_off := rng.randf_range(-half_w * 1.55, half_w * 1.55)
		var x_start := facing * rng.randf_range(0.0, length * 0.45) + facing * k * 90.0
		var l_len := rng.randf_range(38.0, 96.0) * (1.0 - k * 0.45)
		var la := fade * rng.randf_range(0.45, 0.9)
		var lcol := Color(core.r, core.g, core.b, la) if i % 2 == 0 else Color(accent.r, accent.g, accent.b, la)
		draw_line(Vector2(x_start, y_off), Vector2(x_start + facing * l_len, y_off), lcol, 1.8 if i % 2 == 0 else 1.3, true)

	if k < 0.42:
		var tf := 1.0 - k / 0.42
		_draw_star(Vector2(tip_x + facing * 8.0, 0.0), 42.0 * tf, 14.0 * tf, 0.0,
			Color(core.r, core.g, core.b, 0.98 * tf),
			Color(accent.r, accent.g, accent.b, 0.45 * tf))


func _draw_spear(x0: float, xm: float, x1: float, half_w: float, col_center: Color, col_edge: Color) -> void:
	if absf(x1 - x0) < 2.0 or half_w < 0.5:
		return
	var p_tail := Vector2(x0, 0.0)
	var p_tip := Vector2(x1, 0.0)
	var p_top := Vector2(xm, -half_w)
	var p_bot := Vector2(xm, half_w)
	var p_mid := Vector2(xm, 0.0)
	var c_tail := Color(col_edge.r, col_edge.g, col_edge.b, 0.0)
	var c_tip := Color(col_center.r, col_center.g, col_center.b, col_center.a * 0.95)
	draw_primitive(PackedVector2Array([p_tail, p_mid, p_top]), PackedColorArray([c_tail, col_center, col_edge]), PackedVector2Array())
	draw_primitive(PackedVector2Array([p_tail, p_bot, p_mid]), PackedColorArray([c_tail, col_edge, col_center]), PackedVector2Array())
	draw_primitive(PackedVector2Array([p_mid, p_tip, p_top]), PackedColorArray([col_center, c_tip, col_edge]), PackedVector2Array())
	draw_primitive(PackedVector2Array([p_mid, p_bot, p_tip]), PackedColorArray([col_center, col_edge, c_tip]), PackedVector2Array())


func _draw_dash_slash(k: float) -> void:
	_draw_arc_slash(k, false)
	var fade := 1.0 - smoothstep(0.25, 0.95, k)
	var extend := ease(clampf(k / 0.16, 0.0, 1.0), 0.25)
	var x0 := -facing * 45.0
	var x1 := facing * length * extend
	_draw_spear(x0, lerpf(x0, x1, 0.45), x1, 9.0 * (1.0 - k * 0.5),
		Color(core.r, core.g, core.b, 0.95 * fade),
		Color(rim.r, rim.g, rim.b, 0.0))
	if k < 0.35:
		var df := 1.0 - k / 0.35
		_draw_star(Vector2(x0 + facing * 18.0, 0.0), 34.0 * df, 12.0 * df, deg_to_rad(-12.0 * facing),
			Color(core.r, core.g, core.b, 0.95 * df),
			Color(accent.r, accent.g, accent.b, 0.45 * df))
