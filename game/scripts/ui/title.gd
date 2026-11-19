extends Control
## Title screen: ink-wash dusk, the Wanderer on the ridge, brush title.

const BRUSH_FONT := preload("res://assets/fonts/MaShanZheng-subset.ttf")
var hero: PoseSprite
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
	add_child(holder)
	hero = PoseSprite.new()
	hero.extra_scale = 2.3
	hero.sway = 0.008
	hero.breathe = 0.004
	holder.add_child(hero)
	hero.set_pose("hero_01_ready", 0.0)
	holder.position = Vector2(930, 640)
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
