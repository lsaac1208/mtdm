class_name Fx
extends RefCounted
## Spawn helpers for combat VFX. All effects are procedural ink/brush shapes
## so they read in the same hand-inked language as the concept art:
## sword qi = cinnabar rim + white-hot core + dry-brush ink tail (spec §3.2).

const SlashFx := preload("res://scripts/fx/slash_fx.gd")
const RingFx := preload("res://scripts/fx/ring_fx.gd")
const HitFx := preload("res://scripts/fx/hit_fx.gd")

const C_CINNABAR := Color(0.70, 0.13, 0.09)
const C_GOLD := Color(1.0, 0.78, 0.32)
const C_TAINT := Color(0.62, 0.78, 0.22)
const C_INK := Color(0.07, 0.06, 0.05)
const C_BONE := Color(0.86, 0.82, 0.74)


static func layer() -> Node:
	if Game.level and is_instance_valid(Game.level) and Game.level.has_node("Fx"):
		return Game.level.get_node("Fx")
	return Engine.get_main_loop().current_scene


static func slash(pos: Vector2, facing: int, a0: float, a1: float, radius: float, width: float,
		life := 0.2, rim := C_CINNABAR, core := Color(1, 0.97, 0.9), squash := 1.0,
		style := "arc", accent := C_GOLD, tilt := 0.0, length := 165.0) -> Node2D:
	var s := SlashFx.new()
	s.position = pos
	s.facing = facing
	s.a0 = a0
	s.a1 = a1
	s.radius = radius
	s.width = width
	s.life = life
	s.rim = rim
	s.core = core
	s.squash_y = squash
	s.style = style
	s.accent = accent
	s.tilt = tilt
	s.length = length
	layer().add_child(s)
	return s


static func hit_impact(pos: Vector2, dir: int, tag := "slash1", heavy := false,
		col := C_CINNABAR, accent := C_GOLD) -> Node2D:
	var h := HitFx.new()
	h.mode = "hit"
	h.position = pos
	h.dir = dir if dir != 0 else 1
	h.heavy = heavy
	h.color = col
	h.accent = accent
	h.life = 0.20 if heavy else 0.15
	match tag:
		"slash2", "down":
			h.cut_angle = 1.08
		"slash3":
			h.cut_angle = -0.06
		"dash_attack":
			h.cut_angle = -0.14
		"jump_attack":
			h.cut_angle = 0.72
		_:
			h.cut_angle = -0.32
	layer().add_child(h)
	return h


static func blade_glint(pos: Vector2, dir := 1, col := C_GOLD, size := 22.0) -> Node2D:
	var h := HitFx.new()
	h.mode = "glint"
	h.position = pos
	h.dir = dir
	h.accent = col
	h.size = size
	h.life = 0.13
	layer().add_child(h)
	return h


static func parry_burst(pos: Vector2, dir: int) -> Node2D:
	var d: int = dir if dir != 0 else 1
	var h := HitFx.new()
	h.mode = "parry"
	h.position = pos
	h.dir = d
	h.heavy = true
	h.color = C_GOLD
	h.accent = Color(1.0, 0.90, 0.52)
	h.core = Color(1.0, 0.99, 0.94)
	h.life = 0.28
	layer().add_child(h)
	ring(pos, 10.0, 128.0, Color(1.0, 0.82, 0.34, 0.95), 0.32, 9.0, 0.88)
	ring(pos, 6.0, 86.0, Color(1.0, 0.98, 0.90, 0.95), 0.22, 4.5, 0.95)
	particles(pos, 26, Color(1.0, 0.95, 0.72, 0.98), 460.0, 120.0, Vector2(d, -0.35).normalized(), 820.0, 0.38, 4.0, 15)
	particles(pos, 12, Color(0.08, 0.06, 0.05, 0.82), 260.0, 180.0, Vector2.UP, 320.0, 0.32, 5.5, 12)
	return h


static func heal_spiral(target: Node2D, life := 0.72) -> Node2D:
	var h := HitFx.new()
	h.mode = "heal"
	h.follow_target = target
	h.position = target.global_position
	h.accent = C_GOLD
	h.core = Color(1.0, 0.98, 0.88)
	h.life = life
	layer().add_child(h)
	return h


static func afterimage(vis: Node, pos: Vector2, tint := Color(0.95, 0.74, 0.36, 0.48), life := 0.22) -> Node2D:
	var src: Sprite2D = null
	if vis is RigVisual:
		var rv := vis as RigVisual
		if rv.rig_on and rv.frame_on and rv.frames != null and rv.frames.sprite != null and rv.frames.sprite.texture != null:
			src = rv.frames.sprite
		else:
			src = rv.active_sprite()
	elif vis != null and vis.has_method("active_sprite"):
		src = vis.active_sprite()
	if src == null or src.texture == null:
		return null
	var g := Sprite2D.new()
	g.texture = src.texture
	g.centered = src.centered
	g.offset = src.offset
	g.flip_h = src.flip_h
	g.flip_v = src.flip_v
	g.region_enabled = src.region_enabled
	g.region_rect = src.region_rect
	var xf: Transform2D = src.global_transform
	if vis is Node2D:
		xf.origin += pos - (vis as Node2D).global_position
	g.global_transform = xf
	g.modulate = tint
	g.z_index = 4
	layer().add_child(g)
	var tw := g.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(g, "modulate", Color(0.16, 0.11, 0.08, 0.0), maxf(life, 0.04)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(g.queue_free)
	return g


static func ground_slam(pos: Vector2, facing := 1, power := 1.0) -> void:
	var h := HitFx.new()
	h.mode = "slam"
	h.position = pos
	h.dir = facing
	h.size = power
	h.life = 0.34
	layer().add_child(h)
	Sfx.play("ground_slam", -5.0 + (power - 1.0) * 3.5, 0.04)
	dust(pos + Vector2(-18.0 * power, -2.0), int(roundf(6 * power)), Vector2(-0.85, -0.45))
	dust(pos + Vector2(18.0 * power, -2.0), int(roundf(6 * power)), Vector2(0.85, -0.45))
	particles(pos + Vector2(0, -4), int(roundf(8 * power)), Color(0.28, 0.22, 0.17, 0.92),
		240.0 * power, 65.0, Vector2.UP, 980.0, 0.42, 4.5)


static func ring(pos: Vector2, r0: float, r1: float, color: Color, life := 0.4, width := 10.0, squash := 0.35) -> Node2D:
	var r := RingFx.new()
	r.position = pos
	r.r0 = r0
	r.r1 = r1
	r.color = color
	r.life = life
	r.width = width
	r.squash_y = squash
	layer().add_child(r)
	return r


static var _dot: Texture2D
static var _vignette_tex: Texture2D


static func _vignette_texture() -> Texture2D:
	if _vignette_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0.0))
		g.set_color(1, Color(1, 1, 1, 1.0))
		g.add_point(0.46, Color(1, 1, 1, 0.0))
		g.add_point(0.76, Color(1, 1, 1, 0.42))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_vignette_tex = t
	return _vignette_tex


static func _screen_overlay() -> CanvasLayer:
	var host: Node = null
	if Game.level and is_instance_valid(Game.level):
		host = Game.level
	else:
		var ml := Engine.get_main_loop()
		if ml is SceneTree:
			host = (ml as SceneTree).current_scene
	if host == null or not is_instance_valid(host):
		return null
	var existing := host.get_node_or_null("FxScreenOverlay")
	if existing is CanvasLayer:
		return existing as CanvasLayer
	var cl := CanvasLayer.new()
	cl.name = "FxScreenOverlay"
	cl.layer = 8
	var flash := ColorRect.new()
	flash.name = "Flash"
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1, 1, 1, 0)
	flash.visible = false
	cl.add_child(flash)
	var pulse := TextureRect.new()
	pulse.name = "Pulse"
	pulse.set_anchors_preset(Control.PRESET_FULL_RECT)
	pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pulse.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pulse.stretch_mode = TextureRect.STRETCH_SCALE
	pulse.texture = _vignette_texture()
	pulse.modulate = Color(1, 1, 1, 0)
	pulse.visible = false
	cl.add_child(pulse)
	host.add_child(cl)
	return cl


static func screen_flash(color: Color, dur := 0.14) -> void:
	color.a *= Game.flash_scale
	if color.a <= 0.005:
		return
	var cl := _screen_overlay()
	if cl == null:
		return
	var rect := cl.get_node_or_null("Flash") as ColorRect
	if rect == null:
		return
	if rect.has_meta("_tw"):
		var old_tw = rect.get_meta("_tw")
		if old_tw is Tween and (old_tw as Tween).is_valid():
			(old_tw as Tween).kill()
	rect.color = color
	rect.visible = true
	var tw := rect.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(rect, "color:a", 0.0, maxf(dur, 0.04)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): rect.visible = false)
	rect.set_meta("_tw", tw)


static func screen_pulse(color: Color, dur := 0.32) -> void:
	color.a *= Game.flash_scale
	if color.a <= 0.005:
		return
	var cl := _screen_overlay()
	if cl == null:
		return
	var vig := cl.get_node_or_null("Pulse") as TextureRect
	if vig == null:
		return
	if vig.has_meta("_tw"):
		var old_tw = vig.get_meta("_tw")
		if old_tw is Tween and (old_tw as Tween).is_valid():
			(old_tw as Tween).kill()
	vig.modulate = Color(color.r, color.g, color.b, color.a * 0.45)
	vig.visible = true
	var tw := vig.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(vig, "modulate:a", color.a, 0.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(vig, "modulate:a", 0.0, maxf(dur - 0.045, 0.08)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): vig.visible = false)
	vig.set_meta("_tw", tw)


## Soft round brush dab. Untextured CPU particles render as hard squares,
## which read as digital noise against the painted scenes.
static func dot_texture() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.55, Color(1, 1, 1, 0.85))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 24
		t.height = 24
		_dot = t
	return _dot


static func particles(pos: Vector2, amount: int, color: Color, speed := 220.0, spread := 180.0,
		dir := Vector2.UP, gravity := 600.0, life := 0.5, size := 4.0, z := 8) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = Game.fx_amount(maxi(amount, 1))
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = life
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.texture = dot_texture()
	# the dab's opaque core is ~2/3 of its 24 px texture
	p.scale_amount_min = size * 0.5 / 15.0
	p.scale_amount_max = size / 15.0
	p.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = ramp
	p.z_index = z
	p.emitting = true
	layer().add_child(p)
	p.finished.connect(p.queue_free)


static func spark(pos: Vector2, color := C_GOLD, n := 10) -> void:
	particles(pos, n, color, 380.0, 70.0, Vector2.UP, 900.0, 0.3, 3.5)


static func hit_ink(pos: Vector2, dir: int, color := C_INK) -> void:
	particles(pos, 14, color, 340.0, 35.0, Vector2(dir, -0.3).normalized(), 900.0, 0.45, 5.0)


static func dust(pos: Vector2, n := 8, dir := Vector2.UP) -> void:
	particles(pos, n, Color(0.55, 0.48, 0.38, 0.55), 110.0, 70.0, dir, -30.0, 0.6, 7.0, 4)


static func ash(pos: Vector2, n := 24, color := Color(0.2, 0.18, 0.16, 0.8)) -> void:
	particles(pos, n, color, 90.0, 80.0, Vector2.UP, -60.0, 1.4, 4.0)


static var _shard_tex: Texture2D
static var _paper_tex: Texture2D


static func _rect_tex(w: int, h: int, col: Color, edge: Color) -> Texture2D:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(col)
	for x in w:
		img.set_pixel(x, 0, edge)
		img.set_pixel(x, h - 1, edge)
	for y in h:
		img.set_pixel(0, y, edge)
		img.set_pixel(w - 1, y, edge)
	return ImageTexture.create_from_image(img)


## Tumbling debris pieces (paper scraps, armour shards).
static func debris(pos: Vector2, n: int, tex: Texture2D, speed: float, gravity: float, life: float, dir := Vector2.UP, spread := 80.0, scale := 1.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = Game.fx_amount(n)
	p.one_shot = true
	p.explosiveness = 0.9
	p.lifetime = life
	p.texture = tex
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.damping_min = 20.0
	p.damping_max = 60.0
	p.scale_amount_min = 0.6 * scale
	p.scale_amount_max = 1.2 * scale
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.add_point(0.7, Color(1, 1, 1, 1))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	p.z_index = 9
	p.emitting = true
	layer().add_child(p)
	p.finished.connect(p.queue_free)


## Hit effect by material: flesh / paper / taint / armor.
static func material_hit(pos: Vector2, dir: int, material: String, heavy := false) -> void:
	var d := Vector2(dir, -0.35).normalized()
	match material:
		"paper":
			if _paper_tex == null:
				_paper_tex = _rect_tex(5, 8, Color(0.82, 0.68, 0.32), Color(0.5, 0.12, 0.08))
			debris(pos, 8 if not heavy else 14, _paper_tex, 260.0, 260.0, 1.1, d, 70.0)
			particles(pos, 6, Color(0.75, 0.68, 0.55, 0.6), 120.0, 90.0, d, -40.0, 0.6, 6.0)
		"taint":
			particles(pos, 16, Color(0.55, 0.74, 0.2, 0.95), 320.0, 50.0, d, 900.0, 0.5, 5.0)
			particles(pos, 6, Color(0.35, 0.45, 0.12, 0.6), 80.0, 120.0, Vector2.UP, -60.0, 0.9, 9.0)
		"armor":
			spark(pos, Color(1.0, 0.72, 0.35), 12 if not heavy else 20)
			if _shard_tex == null:
				_shard_tex = _rect_tex(6, 4, Color(0.28, 0.24, 0.22), Color(0.6, 0.35, 0.2))
			debris(pos, 3 if not heavy else 8, _shard_tex, 300.0, 1200.0, 0.8, d, 60.0)
		_:
			hit_ink(pos, dir, Color(0.22, 0.05, 0.04))
			particles(pos, 4, Color(0.85, 0.82, 0.74), 260.0, 40.0, d, 1100.0, 0.4, 3.0)


static func splat(pos: Vector2, size := 18.0, color := Color(0.12, 0.05, 0.04, 0.8)) -> void:
	var s = preload("res://scripts/fx/ink_splat.gd").new()
	s.position = pos + Vector2(0, 2)
	s.size = size
	s.color = color
	layer().add_child(s)


static func punch(amount := 0.04, dur := 0.22) -> void:
	if Game.level and is_instance_valid(Game.level) and Game.level.has_method("punch"):
		Game.level.punch(amount, dur)


static func shake(amount: float, dur := 0.2) -> void:
	if Game.level and is_instance_valid(Game.level) and Game.level.has_method("shake"):
		Game.level.shake(amount, dur)


static func kick(vec: Vector2, dur := 0.11) -> void:
	if Game.level and is_instance_valid(Game.level) and Game.level.has_method("kick"):
		Game.level.kick(vec, dur)


static var _recent_numbers: Array = []   # [Vector2 spawn pos, msec]


## Stack numbers that land on the same target within a short window so a
## combo reads as a rising column instead of digits printed over each other.
static func _number_slot(pos: Vector2) -> Vector2:
	var now := Time.get_ticks_msec()
	_recent_numbers = _recent_numbers.filter(func(e): return now - int(e[1]) < 420)
	var lift := 0
	for e in _recent_numbers:
		if absf((e[0] as Vector2).x - pos.x) < 70.0 and absf((e[0] as Vector2).y - pos.y) < 90.0:
			lift += 1
	_recent_numbers.append([pos, now])
	return pos + Vector2(float(lift % 2) * 14.0 - 7.0 if lift > 0 else 0.0, -28.0 * float(mini(lift, 4)))


static func damage_number(pos: Vector2, amount: float, dir := 1, style := "normal") -> void:
	pos = _number_slot(pos)
	var l := Label.new()
	l.text = str(maxi(1, int(roundf(amount))))
	var font_sz := 24
	var col := Color(0.97, 0.93, 0.84)
	var outline := Color(0.08, 0.05, 0.04)
	match style:
		"heavy":
			font_sz = 31
			col = Color(1.0, 0.78, 0.34)
			outline = Color(0.32, 0.07, 0.04)
		"finisher":
			font_sz = 37
			col = Color(1.0, 0.46, 0.22)
			outline = Color(0.18, 0.03, 0.02)
		"talisman":
			font_sz = 26
			col = Color(1.0, 0.86, 0.48)
			outline = Color(0.26, 0.10, 0.04)
		"armor":
			font_sz = 22
			col = Color(0.84, 0.82, 0.78)
			outline = Color(0.10, 0.09, 0.08)
	l.add_theme_font_size_override("font_size", font_sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", 6 if style == "normal" else 7)
	var jitter_x := randf_range(-4.0, 4.0)
	var jitter_y := randf_range(-3.0, 3.0)
	l.size = Vector2(120, 46)
	l.pivot_offset = Vector2(60, 23)
	l.position = pos + Vector2(-60.0 + jitter_x, -23.0 + jitter_y)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.scale = Vector2.ONE * (1.55 if style == "finisher" else 1.38)
	l.z_index = 32
	layer().add_child(l)
	var drift_x := float(dir if dir != 0 else 1) * randf_range(16.0, 34.0)
	var rise_y := 42.0 if style != "finisher" else 56.0
	var tw := l.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:x", l.position.x + drift_x, 0.62).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", l.position.y - rise_y, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - rise_y + 12.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.28)
	tw.tween_callback(l.queue_free)


static func float_text(pos: Vector2, text: String, color: Color, size := 26) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
	l.add_theme_constant_override("outline_size", 6)
	l.position = pos - Vector2(60, 20)
	l.size = Vector2(120, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.z_index = 30
	layer().add_child(l)
	var tw := l.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(l, "position:y", l.position.y - 46, 0.8).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.35)
	tw.tween_callback(l.queue_free)
