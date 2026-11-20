extends Node2D
## Crisp DNF-inspired combat detail effects rendered in unscaled real time so
## they stay silky-smooth right through impact hit-lag:
##   - "hit"  : oblique blade cut scar + 4-point cross-flash star + kinetic speed needles + hit ring
##   - "glint": sharp calligraphic blade draw/startup glint
##   - "slam" : ground cleave shock flare + ink crack spikes + twin earth-dust shock rings
##   - "parry": crossed-blade steel glint + twin ink-gold/ivory shockwaves + flying steel sparks
##   - "heal" : rising Yin-Yang spiral of golden vitality motes tracking the hero

var mode := "hit"      # "hit" | "glint" | "slam" | "parry" | "heal"
var dir := 1
var heavy := false
var cut_angle := -0.35 # radians in forward-facing space
var life := 0.18
var color := Color(0.82, 0.18, 0.10)
var accent := Color(1.0, 0.82, 0.38)
var core := Color(1.0, 0.99, 0.94)
var size := 28.0
var t := 0.0
var follow_target: Node2D = null
var _seed := randi()
var _needles: Array = []
var _cracks: Array = []
var _splashes: Array = []
var _motes: Array = []


func _ready() -> void:
	match mode:
		"slam":
			z_index = 11
		"parry":
			z_index = 16
		"heal":
			z_index = 15
		_:
			z_index = 14
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
	elif mode == "parry":
		var base_a: float = 0.0 if dir >= 0 else PI
		for i in 16:
			var spread: float = rng.randf_range(-1.15, 1.15) if i < 10 else rng.randf_range(-PI, PI)
			_needles.append({
				"ang": base_a + spread,
				"dist": rng.randf_range(48.0, 128.0),
				"len": rng.randf_range(18.0, 42.0),
				"w": rng.randf_range(1.8, 3.6),
				"ivory": rng.randf() < 0.45,
			})
		for i in 12:
			_splashes.append({
				"ang": TAU * float(i) / 12.0 + rng.randf_range(-0.18, 0.18),
				"r_mul": rng.randf_range(0.84, 1.18),
				"sz": rng.randf_range(2.2, 5.2),
				"ink": i % 3 == 0,
			})
	elif mode == "heal":
		for i in 14:
			_motes.append({
				"ang0": TAU * float(i) / 14.0 + rng.randf_range(-0.2, 0.2),
				"rad": rng.randf_range(16.0, 38.0),
				"y0": rng.randf_range(-4.0, -34.0),
				"rise": rng.randf_range(108.0, 152.0),
				"delay": rng.randf_range(0.0, 0.22),
				"sz": rng.randf_range(2.4, 5.2),
				"turns": rng.randf_range(1.1, 1.75) * (1.0 if i % 2 == 0 else -1.0),
				"ivory": i % 3 == 0,
			})


func _process(delta: float) -> void:
	t += Game.unscaled_delta(delta)
	if mode == "heal" and follow_target != null and is_instance_valid(follow_target):
		global_position = follow_target.global_position
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
		"parry":
			_draw_parry(k)
		"heal":
			_draw_heal(k)
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


func _draw_parry(k: float) -> void:
	var pop: float = ease(clampf(k / 0.12, 0.0, 1.0), 0.22)
	var fade: float = 1.0 - smoothstep(0.24, 1.0, k)
	var flash_a: float = 1.0 - smoothstep(0.0, 0.36, k)
	var expand: float = ease(k, 0.28)

	# 1. Blazing steel-clash core flash
	if flash_a > 0.02:
		draw_circle(Vector2.ZERO, 42.0 * pop, Color(accent.r, accent.g, accent.b, 0.42 * flash_a))
		draw_circle(Vector2.ZERO, 22.0 * pop, Color(core.r, core.g, core.b, 0.96 * flash_a))

	# 2. Concentric ink-gold + ivory shockwave rings
	var r_outer: float = lerpf(14.0, 114.0, expand)
	var r_inner: float = lerpf(8.0, 78.0, ease(k, 0.36))
	var a_ring: float = (1.0 - smoothstep(0.18, 1.0, k)) * 0.92
	var pts_out := PackedVector2Array()
	var pts_in := PackedVector2Array()
	for i in 37:
		var ang: float = TAU * float(i) / 36.0
		pts_out.append(Vector2(cos(ang) * r_outer, sin(ang) * r_outer * 0.90))
		pts_in.append(Vector2(cos(ang) * r_inner, sin(ang) * r_inner * 0.96))
	draw_polyline(pts_out, Color(0.07, 0.05, 0.04, a_ring * 0.65), 8.5 * (1.0 - k * 0.65), true)
	draw_polyline(pts_out, Color(color.r, color.g, color.b, a_ring * 0.92), 4.4 * (1.0 - k * 0.6), true)
	draw_polyline(pts_in, Color(core.r, core.g, core.b, a_ring), 2.8 * (1.0 - k * 0.55), true)

	# 3. Calligraphic ink-splash droplets flung along the outer ring
	for sp in _splashes:
		var sp_ang: float = float(sp.ang)
		var sp_r: float = r_outer * float(sp.r_mul)
		var sp_p := Vector2(cos(sp_ang) * sp_r, sin(sp_ang) * sp_r * 0.90)
		var sp_sz: float = float(sp.sz) * (1.0 - k * 0.72)
		if sp_sz < 0.6:
			continue
		var sp_col := Color(0.07, 0.05, 0.04, 0.78 * fade) if bool(sp.ink) else Color(accent.r, accent.g, accent.b, 0.85 * fade)
		draw_circle(sp_p, sp_sz, sp_col)

	# 4. Crisp 4-point calligraphic crossed-blade steel glint
	var glint_fade: float = 1.0 - smoothstep(0.16, 0.88, k)
	if glint_fade > 0.02:
		var ax_h := Vector2.RIGHT.rotated(deg_to_rad(-10.0 * float(dir)))
		var ax_v := Vector2(-ax_h.y, ax_h.x)
		var len_h: float = 104.0 * pop * (1.0 - k * 0.35)
		var len_v: float = 78.0 * pop * (1.0 - k * 0.38)
		var w_main: float = 9.5 * (1.0 - k * 0.82)
		_diamond(Vector2.ZERO, ax_h, len_h * 1.12, w_main * 1.65, Color(0.08, 0.06, 0.04, 0.45 * glint_fade))
		_diamond(Vector2.ZERO, ax_h, len_h, w_main, Color(accent.r, accent.g, accent.b, 0.90 * glint_fade))
		_diamond(Vector2.ZERO, ax_h, len_h * 0.86, w_main * 0.44, Color(core.r, core.g, core.b, 1.0 * glint_fade))
		_diamond(Vector2.ZERO, ax_v, len_v, w_main * 0.82, Color(accent.r, accent.g, accent.b, 0.84 * glint_fade))
		_diamond(Vector2.ZERO, ax_v, len_v * 0.85, w_main * 0.36, Color(core.r, core.g, core.b, 0.98 * glint_fade))

		# Crossed diagonal steel clash scars
		for side in [-1.0, 1.0]:
			var diag := Vector2.RIGHT.rotated(deg_to_rad(38.0 * side))
			var d_len: float = 68.0 * pop * (1.0 - k * 0.42)
			var d_w: float = 5.4 * (1.0 - k * 0.84)
			_diamond(Vector2.ZERO, diag, d_len * 1.08, d_w * 1.45, Color(color.r, color.g, color.b, 0.65 * glint_fade))
			_diamond(Vector2.ZERO, diag, d_len, d_w * 0.55, Color(core.r, core.g, core.b, 0.95 * glint_fade))

	# 5. Directional metallic flying golden-white spark needles
	var travel: float = ease(k, 0.28)
	for nd in _needles:
		var v := Vector2.RIGHT.rotated(float(nd.ang))
		var head := v * (float(nd.dist) * travel + 14.0)
		var nlen: float = float(nd.len) * (1.0 - k * 0.60)
		var tail := head - v * nlen
		var na: float = (1.0 - smoothstep(0.28, 1.0, k)) * 0.98
		var nw: float = float(nd.w) * (1.0 - k * 0.55)
		var ncol := Color(core.r, core.g, core.b, na) if bool(nd.ivory) else Color(accent.r, accent.g, accent.b, na)
		draw_line(head, tail, ncol, nw, true)
		draw_line(head, head.lerp(tail, 0.5), Color(1.0, 1.0, 0.96, na), maxf(1.1, nw * 0.48), true)


func _draw_heal(k: float) -> void:
	var env: float = smoothstep(0.0, 0.14, k) * (1.0 - smoothstep(0.65, 1.0, k))
	if env <= 0.01:
		return

	# Soft warm ground vitality halo around boots
	var g_fade: float = smoothstep(0.0, 0.15, k) * (1.0 - smoothstep(0.45, 0.95, k))
	if g_fade > 0.01:
		var gr: float = lerpf(22.0, 56.0, ease(k, 0.45))
		var gpts := PackedVector2Array()
		for i in 29:
			var ang: float = TAU * float(i) / 28.0
			gpts.append(Vector2(cos(ang) * gr, -4.0 + sin(ang) * gr * 0.24))
		draw_polyline(gpts, Color(accent.r, accent.g, accent.b, 0.52 * g_fade), 3.6 * (1.0 - k * 0.5), true)
		draw_polyline(gpts, Color(core.r, core.g, core.b, 0.68 * g_fade), 1.4, true)

	# Twin intertwined Yin-Yang golden & ivory spiral trails
	for strand in 2:
		var phase0: float = 0.0 if strand == 0 else PI
		var pts := PackedVector2Array()
		var segs: int = 20
		var head_k: float = clampf(k * 1.18, 0.0, 1.0)
		var tail_k: float = clampf(k * 1.18 - 0.42, 0.0, 1.0)
		for i in segs + 1:
			var fk: float = lerpf(tail_k, head_k, float(i) / float(segs))
			var ang: float = phase0 + fk * TAU * 1.65
			var rad: float = lerpf(34.0, 16.0, fk)
			var py: float = lerpf(-8.0, -152.0, fk)
			pts.append(Vector2(cos(ang) * rad, py + sin(ang) * 5.0))
		if pts.size() >= 2:
			var scol := Color(accent.r, accent.g, accent.b, 0.50 * env) if strand == 0 else Color(core.r, core.g, core.b, 0.58 * env)
			draw_polyline(pts, scol, 2.8 if strand == 0 else 1.8, true)

	# Rising glowing golden vitality motes
	for m in _motes:
		var delay: float = float(m.delay)
		var mk: float = clampf((k - delay) / maxf(1.0 - delay, 0.2), 0.0, 1.0)
		if mk <= 0.0 or mk >= 1.0:
			continue
		var ma: float = smoothstep(0.0, 0.16, mk) * (1.0 - smoothstep(0.62, 1.0, mk))
		var ang: float = float(m.ang0) + mk * TAU * float(m.turns)
		var rad: float = float(m.rad) * (1.0 - mk * 0.35)
		var py: float = float(m.y0) - float(m.rise) * ease(mk, 0.65)
		var mp := Vector2(cos(ang) * rad, py)
		var msz: float = float(m.sz) * (0.7 + 0.5 * sin(mk * PI))
		var outer_col := Color(accent.r, accent.g, accent.b, 0.40 * ma)
		var inner_col := Color(core.r, core.g, core.b, 0.94 * ma) if bool(m.ivory) else Color(1.0, 0.88, 0.46, 0.92 * ma)
		draw_circle(mp, msz * 1.9, outer_col)
		draw_circle(mp, msz * 0.85, inner_col)
