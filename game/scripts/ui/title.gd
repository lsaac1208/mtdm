extends Control
## Title screen: ink-wash dusk, the Wanderer on the ridge, brush title.

const BRUSH_FONT := preload("res://assets/fonts/MaShanZheng-subset.ttf")
const HERO_VISUAL := preload("res://scripts/actors/hero_visual.gd")
const TITLE_LIGHT := {
	"key_dir": Vector3(0.58, -0.56, 0.59),
	"key": Color(1.18, 0.96, 0.76),
	"shadow": Color(0.58, 0.52, 0.52),
	"rim": Color(1.30, 0.92, 0.58),
	"rim_str": 0.46,
	"bounce": Color(0.88, 0.72, 0.54),
	"bounce_str": 0.22,
	"haze": Color(0.88, 0.76, 0.60, 0.10),
	"soil": Color(0.52, 0.40, 0.30),
	"shadow_lean": -0.52,
	"point_dir": Vector3(0.0, 0.0, 1.0),
	"point_color": Color(1.0, 0.58, 0.22),
	"point_strength": 0.0,
}
var hero: RigVisual
var shadow_node: Node2D
var motes_node: Node2D
var _motes: Array = []
var t := 0.0
var menu: VBoxContainer
var help: Label
var _started := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sky := TextureRect.new()
	if ResourceLoader.exists("res://assets/env/title_bg.png"):
		sky.texture = load("res://assets/env/title_bg.png")
	elif ResourceLoader.exists("res://assets/env/sky.png"):
		sky.texture = load("res://assets/env/sky.png")
	sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sky)
	var holder := Node2D.new()
	holder.position = Vector2(904, 598)
	add_child(holder)
	shadow_node = Node2D.new()
	shadow_node.draw.connect(_draw_shadow)
	holder.add_child(shadow_node)
	hero = HERO_VISUAL.new()
	hero.extra_scale = 2.02
	hero.facing = -1
	hero.sway = 0.009
	hero.breathe = 0.003
	hero.light_override = TITLE_LIGHT
	holder.add_child(hero)
	hero.play_clip.call_deferred("idle", 0.0, true)
	motes_node = Node2D.new()
	motes_node.draw.connect(_draw_motes)
	add_child(motes_node)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90317
	for i in 22:
		_motes.append({
			"x": rng.randf_range(440.0, 1280.0),
			"y": rng.randf_range(90.0, 660.0),
			"vx": rng.randf_range(-20.0, -7.0),
			"vy": rng.randf_range(3.0, 11.0),
			"r": rng.randf_range(1.6, 3.6),
			"ph": rng.randf_range(0.0, TAU),
			"leaf": i < 7,
		})
	var title := Label.new()
	title.text = "道行者"
	title.add_theme_font_override("font", BRUSH_FONT)
	title.add_theme_font_size_override("font_size", 150)
	title.add_theme_color_override("font_color", Color(0.1, 0.08, 0.07))
	title.add_theme_color_override("font_outline_color", Color(0.85, 0.78, 0.62, 0.6))
	title.add_theme_constant_override("outline_size", 6)
	title.position = Vector2(110, 70)
	add_child(title)
	var sub := Label.new()
	sub.text = "TAOIST  WANDERER"
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Color(0.42, 0.12, 0.09))
	sub.position = Vector2(124, 262)
	add_child(sub)
	var tag := Label.new()
	tag.text = "一人、一剑、一道，行于废土。"
	tag.add_theme_font_override("font", BRUSH_FONT)
	tag.add_theme_font_size_override("font_size", 34)
	tag.add_theme_color_override("font_color", Color(0.18, 0.14, 0.12))
	tag.position = Vector2(120, 306)
	add_child(tag)
	menu = VBoxContainer.new()
	menu.position = Vector2(130, 410)
	menu.add_theme_constant_override("separation", 10)
	add_child(menu)
	for b in [["开始游戏  ·  Start", "_start"], ["操作说明  ·  Controls", "_help"], ["设置  ·  Options", "_options"], ["退出  ·  Quit", "_quit"]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(300, 48)
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(Callable(self, b[1]))
		menu.add_child(btn)
	help = Label.new()
	Game.prompts_changed.connect(_refresh_help)
	_refresh_help()
	help.add_theme_font_size_override("font_size", 17)
	help.add_theme_color_override("font_color", Color(0.12, 0.1, 0.08))
	help.position = Vector2(470, 410)
	help.visible = false
	add_child(help)
	var foot := Label.new()
	foot.text = "第一章 · 序　垂直切片试玩版 v%s　|　Vertical-slice demo" % ProjectSettings.get_setting("application/config/version")
	foot.add_theme_font_size_override("font_size", 14)
	foot.add_theme_color_override("font_color", Color(0.25, 0.2, 0.16))
	foot.position = Vector2(130, 680)
	add_child(foot)
	(menu.get_child(0) as Button).grab_focus()
	Sfx.play_music("music_title")
	Sfx.play_ambience("amb_wind")
	if Game.args.has("autostart"):
		_start.call_deferred()


func _process(delta: float) -> void:
	t += delta
	for m in _motes:
		m.x += m.vx * delta
		m.y += (m.vy + sin(t * 1.5 + m.ph) * 6.0) * delta
		if m.x < 400.0:
			m.x = 1295.0
		if m.y > 680.0:
			m.y = 90.0
	shadow_node.queue_redraw()
	motes_node.queue_redraw()


func _draw_shadow() -> void:
	if hero == null:
		return
	var lean: float = float(TITLE_LIGHT.shadow_lean)
	var sc := hero.extra_scale
	shadow_node.draw_set_transform(Vector2(lean * 22.0 * sc, 3.0), 0.0, Vector2(1.0, 0.20))
	shadow_node.draw_circle(Vector2.ZERO, 44.0 * sc * 0.62, Color(0.14, 0.09, 0.07, 0.20))
	shadow_node.draw_set_transform(Vector2(0.0, 2.0), 0.0, Vector2(1.0, 0.22))
	shadow_node.draw_circle(Vector2.ZERO, 32.0 * sc, Color(0.10, 0.07, 0.05, 0.22))
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
		shadow_node.draw_set_transform(Vector2(fx + lean * 2.0, 1.5), 0.0, Vector2(1.0, 0.26))
		shadow_node.draw_circle(Vector2.ZERO, 13.5 * sc, Color(0.07, 0.05, 0.04, 0.42))
	shadow_node.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_motes() -> void:
	for m in _motes:
		var mr: float = float(m.r)
		var mph: float = float(m.ph)
		var mx: float = float(m.x)
		var my: float = float(m.y)
		var pulse := 0.55 + 0.45 * sin(t * 2.0 + mph)
		if bool(m.leaf):
			var ang: float = t * 1.2 + mph
			var dir := Vector2(cos(ang), sin(ang))
			var side := Vector2(-dir.y, dir.x) * (mr * 0.55)
			var p := Vector2(mx, my)
			var pts := PackedVector2Array([p + dir * mr * 1.9, p + side, p - dir * mr * 1.9, p - side])
			motes_node.draw_colored_polygon(pts, Color(0.64, 0.30, 0.16, 0.46 * pulse))
		else:
			motes_node.draw_circle(Vector2(mx, my), mr * 0.65, Color(1.0, 0.88, 0.68, 0.32 * pulse))


func _start() -> void:
	if _started:
		return
	_started = true
	Sfx.play("ui_confirm", -2.0)
	Game.new_run()


func _refresh_help() -> void:
	help.text = Game.fmt_keys(preload("res://scripts/ui/pause_menu.gd").CONTROLS)


func _help() -> void:
	help.visible = not help.visible
	Sfx.play("ui_move", -6.0)


func _options() -> void:
	var o := OptionsMenu.new()
	add_child(o)
	o.closed.connect(func(): (menu.get_child(2) as Button).grab_focus())


func _quit() -> void:
	Game.quit()
