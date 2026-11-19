extends Control
## Demo completion: the elite is sealed, the road continues. Shows run stats.

const BRUSH_FONT := preload("res://assets/fonts/MaShanZheng-subset.ttf")
const HERO_VISUAL := preload("res://scripts/actors/hero_visual.gd")
const DUSK_LIGHT := {
	"key_dir": Vector3(0.66, -0.46, 0.59),
	"key": Color(1.16, 0.96, 0.76),
	"shadow": Color(0.62, 0.56, 0.54),
	"rim": Color(1.26, 0.94, 0.64),
	"rim_str": 0.40,
	"bounce": Color(0.90, 0.74, 0.56),
	"bounce_str": 0.22,
	"haze": Color(0.86, 0.72, 0.56, 0.14),
	"soil": Color(0.56, 0.44, 0.34),
	"shadow_lean": -0.58,
	"point_dir": Vector3(0.0, 0.0, 1.0),
	"point_color": Color(1.0, 0.58, 0.22),
	"point_strength": 0.0,
}
const WALK_SPEED := 78.0
var hero: RigVisual
var holder: Node2D
var shadow_node: Node2D
var motes_node: Node2D
var _motes: Array = []
var t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.9, 0.85, 0.74)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	if ResourceLoader.exists("res://assets/env/ending_bg.png"):
		var tr := TextureRect.new()
		tr.texture = load("res://assets/env/ending_bg.png")
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(tr)
	holder = Node2D.new()
	holder.position = Vector2(260, 616)
	add_child(holder)
	shadow_node = Node2D.new()
	shadow_node.draw.connect(_draw_shadow)
	holder.add_child(shadow_node)
	hero = HERO_VISUAL.new()
	hero.extra_scale = 1.28
	hero.facing = 1
	hero.walk_speed = 92.0
	hero.locomotion_speed = WALK_SPEED
	hero.light_override = DUSK_LIGHT
	holder.add_child(hero)
	hero.play_clip.call_deferred("walk", 0.0, true)
	motes_node = Node2D.new()
	motes_node.draw.connect(_draw_motes)
	add_child(motes_node)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261119
	for i in 26:
		_motes.append({
			"x": rng.randf_range(0.0, 1280.0),
			"y": rng.randf_range(120.0, 670.0),
			"vx": rng.randf_range(-24.0, -9.0),
			"vy": rng.randf_range(4.0, 14.0),
			"r": rng.randf_range(1.6, 3.8),
			"ph": rng.randf_range(0.0, TAU),
			"leaf": i < 8,
		})
	var lines := [
		["第一章 · 序　完", BRUSH_FONT, 72, Color(0.12, 0.09, 0.08), Vector2(0, 90)],
		["尸将已镇，乱葬岗归于沉寂。前路秽气未散 —— 道行者仍要前行。", null, 22, Color(0.20, 0.14, 0.11), Vector2(0, 198)],
		["%s　·　用时 %s　·　战死 %d 次　·　斩祟 %d　·　弹反 %d" % [["故事", "常规", "修行"][Game.difficulty], Game.format_time(Game.run_time), Game.deaths, Game.kills, Game.parries], null, 22, Color(0.50, 0.13, 0.09), Vector2(0, 256)],
		["感谢试玩　Thank you for playing the Taoist Wanderer vertical slice", null, 18, Color(0.26, 0.20, 0.16), Vector2(0, 314)],
		["按 %s 返回标题" % Game.binding_label("confirm", true), null, 18, Color(0.18, 0.13, 0.10), Vector2(0, 668)],
	]
	for l in lines:
		var lb := Label.new()
		lb.text = l[0]
		if l[1]:
			lb.add_theme_font_override("font", l[1])
		lb.add_theme_font_size_override("font_size", l[2])
		lb.add_theme_color_override("font_color", l[3])
		lb.add_theme_color_override("font_outline_color", Color(0.95, 0.89, 0.78, 0.72))
		lb.add_theme_constant_override("outline_size", 4)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.anchor_right = 1.0
		lb.offset_top = l[4].y
		lb.modulate.a = 0.0
		add_child(lb)
		var tw := lb.create_tween()
		tw.tween_interval(0.4 + lines.find(l) * 0.5)
		tw.tween_property(lb, "modulate:a", 1.0, 1.0)
	Sfx.play_music("music_title")
	print("DEMO_COMPLETE time=%s deaths=%d kills=%d parries=%d" % [Game.format_time(Game.run_time), Game.deaths, Game.kills, Game.parries])


func _process(delta: float) -> void:
	t += delta
	# the wanderer walks on toward the horizon
	holder.position.x += WALK_SPEED * delta
	hero.locomotion_speed = WALK_SPEED
	hero.sway = 0.008
	hero.lean = 1.5
	if holder.position.x > 1400:
		holder.position.x = -100
	for m in _motes:
		m.x += m.vx * delta
		m.y += (m.vy + sin(t * 1.8 + m.ph) * 8.0) * delta
		if m.x < -20.0:
			m.x = 1300.0
		if m.y > 700.0:
			m.y = 120.0
	shadow_node.queue_redraw()
	motes_node.queue_redraw()


func _draw_shadow() -> void:
	if hero == null:
		return
	var lean: float = float(DUSK_LIGHT.shadow_lean)
	var sc := hero.extra_scale
	var cast_w := 56.0 * sc
	var cast_x := lean * 36.0 * sc
	shadow_node.draw_set_transform(Vector2(cast_x, 3.0), 0.0, Vector2(1.0, 0.22))
	shadow_node.draw_circle(Vector2.ZERO, cast_w * 0.58, Color(0.14, 0.09, 0.07, 0.24))
	shadow_node.draw_set_transform(Vector2(0.0, 2.0), 0.0, Vector2(1.0, 0.25))
	shadow_node.draw_circle(Vector2.ZERO, 34.0 * sc, Color(0.11, 0.08, 0.06, 0.24))
	var contacts := hero.boot_contacts()
	var drawn: Array[float] = []
	for foot in contacts:
		var fx: float = float(foot.x)
		var dup := false
		for prev_x in drawn:
			if absf(fx - prev_x) < 10.0 * sc:
				dup = true
				break
		if dup:
			continue
		drawn.append(fx)
		var fy: float = float(foot.y)
		var lift := clampf(-fy / (30.0 * sc), 0.0, 1.0)
		var w := lerpf(14.0, 8.0, lift) * sc
		var a := lerpf(0.42, 0.12, lift)
		shadow_node.draw_set_transform(Vector2(fx + lean * 3.0, 1.5), 0.0, Vector2(1.0, 0.28))
		shadow_node.draw_circle(Vector2.ZERO, w, Color(0.08, 0.05, 0.04, a))
	shadow_node.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_motes() -> void:
	for m in _motes:
		var mr: float = float(m.r)
		var mph: float = float(m.ph)
		var mx: float = float(m.x)
		var my: float = float(m.y)
		var pulse := 0.55 + 0.45 * sin(t * 2.2 + mph)
		if bool(m.leaf):
			var ang: float = t * 1.4 + mph
			var dir := Vector2(cos(ang), sin(ang))
			var side := Vector2(-dir.y, dir.x) * (mr * 0.55)
			var p := Vector2(mx, my)
			var pts := PackedVector2Array([p + dir * mr * 1.9, p + side, p - dir * mr * 1.9, p - side])
			motes_node.draw_colored_polygon(pts, Color(0.68, 0.34, 0.18, 0.48 * pulse))
		else:
			motes_node.draw_circle(Vector2(mx, my), mr * 0.7, Color(1.0, 0.88, 0.68, 0.34 * pulse))


func _unhandled_input(e: InputEvent) -> void:
	if t > 1.5 and (e.is_action_pressed("confirm") or e.is_action_pressed("attack")):
		Game.to_title()
