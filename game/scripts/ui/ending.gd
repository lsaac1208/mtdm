extends Control
## Demo completion: the elite is sealed, the road continues. Shows run stats.

const BRUSH_FONT := preload("res://assets/fonts/MaShanZheng-subset.ttf")
var hero: PoseSprite
var holder: Node2D
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
	holder.position = Vector2(300, 610)
	add_child(holder)
	hero = PoseSprite.new()
	hero.extra_scale = 1.3
	holder.add_child(hero)
	hero.set_pose("hero_01_ready", 0.0)
	var lines := [
		["第一章 · 序　完", BRUSH_FONT, 72, Color(0.12, 0.09, 0.08), Vector2(0, 90)],
		["尸将已镇，乱葬岗归于沉寂。前路秽气未散 —— 道行者仍要前行。", null, 22, Color(0.25, 0.18, 0.14), Vector2(0, 200)],
		["%s　·　用时 %s　·　战死 %d 次　·　斩祟 %d　·　弹反 %d" % [["故事", "常规", "修行"][Game.difficulty], Game.format_time(Game.run_time), Game.deaths, Game.kills, Game.parries], null, 22, Color(0.45, 0.12, 0.09), Vector2(0, 260)],
		["感谢试玩　Thank you for playing the Taoist Wanderer vertical slice", null, 18, Color(0.3, 0.25, 0.2), Vector2(0, 320)],
		["按 Enter / A 返回标题", null, 18, Color(0.3, 0.25, 0.2), Vector2(0, 660)],
	]
	for l in lines:
		var lb := Label.new()
		lb.text = l[0]
		if l[1]:
			lb.add_theme_font_override("font", l[1])
		lb.add_theme_font_size_override("font_size", l[2])
		lb.add_theme_color_override("font_color", l[3])
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
	holder.position.x += 60.0 * delta
	hero.phase = t * 9.0
	hero.stride = 0.04
	hero.bob = absf(sin(t * 9.0)) * 4.0
	hero.lean = 5.0
	if holder.position.x > 1400:
		holder.position.x = -100


func _unhandled_input(e: InputEvent) -> void:
	if t > 1.5 and (e.is_action_pressed("confirm") or e.is_action_pressed("attack")):
		Game.to_title()
