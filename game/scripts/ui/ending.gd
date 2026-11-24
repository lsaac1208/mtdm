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
var _action_taken := false
var rank_info: Dictionary = {}


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
	holder.position = Vector2(190, 666)
	add_child(holder)
	shadow_node = Node2D.new()
	shadow_node.draw.connect(_draw_shadow)
	holder.add_child(shadow_node)
	hero = HERO_VISUAL.new()
	hero.extra_scale = 1.12
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
	var rematch := Game.mode == "rematch"
	if rematch:
		# challenge result: never overwrites the story rank or best time
		Game.record_rematch(not Game.args.has("test"))
		rank_info = Game.compute_rank(Game.deaths, Game.parries, Game.run_time, Game.difficulty)
	else:
		rank_info = Game.record_clear(not Game.args.has("test"))
	# Top calligraphic heading & epilogue
	var head := Label.new()
	head.text = "尸将再战 · 已镇" if rematch else "第一章 · 序  完"
	head.add_theme_font_override("font", BRUSH_FONT)
	head.add_theme_font_size_override("font_size", 66)
	head.add_theme_color_override("font_color", Color(0.12, 0.09, 0.08))
	head.add_theme_color_override("font_outline_color", Color(0.95, 0.89, 0.78, 0.78))
	head.add_theme_constant_override("outline_size", 5)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.anchor_right = 1.0
	head.offset_top = 20
	head.modulate.a = 0.0
	add_child(head)
	var htw := head.create_tween()
	htw.tween_interval(0.2)
	htw.tween_property(head, "modulate:a", 1.0, 0.8)

	var sub := Label.new()
	sub.text = Game.t("尸将已镇，乱葬岗归于沉寂。前路秽气未散 —— 道行者仍要前行。", "The General is sealed and the Burial Mound falls silent. The taint lingers — the wanderer walks on.")
	if rematch:
		var best: float = Game.best_rematch[clampi(Game.difficulty, 0, 2)]
		sub.text = Game.t("再战用时 %s  ·  本难度最佳 %s%s", "Rematch %s  ·  Best on this difficulty %s%s") % [Game.format_time(Game.run_time), Game.format_time(best), Game.t("  ★ 新纪录", "  ★ New record") if Game.last_rematch_best else ""]
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.20, 0.14, 0.11))
	sub.add_theme_color_override("font_outline_color", Color(0.95, 0.89, 0.78, 0.75))
	sub.add_theme_constant_override("outline_size", 4)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.anchor_right = 1.0
	sub.offset_top = 96
	sub.modulate.a = 0.0
	add_child(sub)
	var subtw := sub.create_tween()
	subtw.tween_interval(0.45)
	subtw.tween_property(sub, "modulate:a", 1.0, 0.8)

	# Structured Journey Ledger (行旅录) + Animated Vermilion Seal Rank (甲 / 乙 / 丙)
	var ledger := PanelContainer.new()
	ledger.add_theme_stylebox_override("panel", InkTheme.scroll_panel(30, 16, 0.90))
	ledger.position = Vector2(276.0, 138.0)
	ledger.size = Vector2(728.0, 250.0)
	ledger.modulate.a = 0.0
	add_child(ledger)
	var ltw := ledger.create_tween()
	ltw.tween_interval(0.65)
	ltw.tween_property(ledger, "modulate:a", 1.0, 0.65)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 28)
	ledger.add_child(hbox)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 3)
	hbox.add_child(left)

	var ltitle := Label.new()
	var is_new_best := Game.last_rematch_best if rematch else Game.last_clear_is_best
	var best_tag := Game.t("  ★ 新纪录", "  ★ NEW RECORD") if is_new_best else ""
	ltitle.text = "行 旅 录  ·  JOURNEY LEDGER%s" % best_tag
	ltitle.add_theme_font_size_override("font_size", 17)
	ltitle.add_theme_color_override("font_color", Color(0.95, 0.80, 0.48))
	left.add_child(ltitle)

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(0.76, 0.59, 0.34, 0.45)
	left.add_child(sep)

	var diff_str: String = ["故事 · Story", "常规 · Normal", "修行 · Hard"][clampi(Game.difficulty, 0, 2)]
	var stats_rows := [
		[Game.t("修行难度", "Difficulty"), diff_str],
		[Game.t("行旅用时", "Time"), Game.format_time(Game.run_time)],
		[Game.t("战死次数", "Deaths"), Game.t("%d 次", "%d") % Game.deaths],
		[Game.t("斩除妖祟", "Kills"), "%d" % Game.kills],
		[Game.t("精准弹反", "Parries"), "%d" % Game.parries],
		[Game.t("破除残器", "Relics broken"), "%d" % Game.props_broken],
		[Game.t("拓得碑文", "Steles read"), "%d / %d" % [Game.lore_read.size(), LevelData.LORE.size()]],
	]
	if rematch:
		# props and steles along the route aren't part of the boss challenge
		stats_rows = stats_rows.slice(0, 5)
	for row_data in stats_rows:
		var rbox := HBoxContainer.new()
		var k := Label.new()
		k.text = String(row_data[0])
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		k.add_theme_font_size_override("font_size", 17)
		k.add_theme_color_override("font_color", Color(0.76, 0.70, 0.60))
		rbox.add_child(k)
		var v := Label.new()
		v.text = String(row_data[1])
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.add_theme_font_size_override("font_size", 18)
		v.add_theme_color_override("font_color", Color(0.96, 0.91, 0.80))
		rbox.add_child(v)
		left.add_child(rbox)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(196, 0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 10)
	hbox.add_child(right)

	var seal_holder := Control.new()
	seal_holder.custom_minimum_size = Vector2(150, 150)
	seal_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right.add_child(seal_holder)

	var seal := Control.new()
	seal.position = Vector2(75.0, 75.0)
	seal.scale = Vector2(2.1, 2.1)
	seal.rotation = -0.14
	seal.modulate.a = 0.0
	seal_holder.add_child(seal)

	var seal_col: Color = rank_info.color
	var sq := ColorRect.new()
	sq.color = Color(seal_col.r, seal_col.g, seal_col.b, 0.94)
	sq.position = Vector2(-60, -60)
	sq.size = Vector2(120, 120)
	seal.add_child(sq)

	var inner := ReferenceRect.new()
	inner.border_color = Color(0.96, 0.88, 0.74, 0.92)
	inner.border_width = 3.0
	inner.editor_only = false
	inner.position = Vector2(-52, -52)
	inner.size = Vector2(104, 104)
	seal.add_child(inner)

	var grade_lbl := Label.new()
	grade_lbl.text = String(rank_info.grade)
	grade_lbl.add_theme_font_override("font", BRUSH_FONT)
	grade_lbl.add_theme_font_size_override("font_size", 86)
	grade_lbl.add_theme_color_override("font_color", Color(0.97, 0.91, 0.79))
	grade_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grade_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grade_lbl.position = Vector2(-60, -66)
	grade_lbl.size = Vector2(120, 128)
	seal.add_child(grade_lbl)

	var stw := create_tween()
	stw.tween_interval(1.15)
	stw.tween_property(seal, "modulate:a", 1.0, 0.08)
	stw.parallel().tween_property(seal, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	stw.parallel().tween_property(seal, "rotation", -0.06, 0.22)
	stw.tween_callback(func(): InkTheme.play_ui("seal_stamp", "seal_burst", -4.0))

	var epithet := Label.new()
	epithet.text = String(rank_info.title)
	epithet.add_theme_font_override("font", BRUSH_FONT)
	epithet.add_theme_font_size_override("font_size", 30)
	epithet.add_theme_color_override("font_color", Color(0.95, 0.84, 0.62))
	epithet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(epithet)

	var rank_en := Label.new()
	rank_en.text = String(rank_info.en)
	rank_en.add_theme_font_size_override("font_size", 12)
	rank_en.add_theme_color_override("font_color", Color(0.76, 0.68, 0.56))
	rank_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(rank_en)

	# Interactive Replay / Title buttons
	var btn_row := HBoxContainer.new()
	# sit just below the ledger's real laid-out height so added ledger rows
	# can never run into the buttons
	var ledger_h := maxf(ledger.size.y, ledger.get_combined_minimum_size().y)
	btn_row.position = Vector2(360.0, ledger.position.y + ledger_h + 16.0)
	btn_row.size = Vector2(560.0, 48.0)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	btn_row.modulate.a = 0.0
	add_child(btn_row)
	var again_btn := Button.new()
	again_btn.text = "再行此道  ·  Play Again"
	again_btn.custom_minimum_size = Vector2(256, 46)
	again_btn.add_theme_font_size_override("font_size", 19)
	again_btn.pressed.connect(_play_again)
	InkTheme.wire_hover(again_btn)
	btn_row.add_child(again_btn)

	var title_btn := Button.new()
	title_btn.text = "返回标题  ·  Title"
	title_btn.custom_minimum_size = Vector2(236, 46)
	title_btn.add_theme_font_size_override("font_size", 19)
	title_btn.pressed.connect(_go_title)
	InkTheme.wire_hover(title_btn)
	btn_row.add_child(title_btn)
	var btw := btn_row.create_tween()
	btw.tween_interval(1.45)
	btw.tween_property(btn_row, "modulate:a", 1.0, 0.5)
	btw.tween_callback(func():
		if is_instance_valid(title_btn):
			title_btn.grab_focus())

	var thanks := Label.new()
	thanks.text = "感谢试玩《道行者》序章试玩版  ·  Thank you for playing Taoist Wanderer"
	thanks.add_theme_font_size_override("font_size", 15)
	thanks.add_theme_color_override("font_color", Color(0.24, 0.18, 0.14))
	thanks.add_theme_color_override("font_outline_color", Color(0.95, 0.89, 0.78, 0.72))
	thanks.add_theme_constant_override("outline_size", 3)
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thanks.anchor_right = 1.0
	thanks.offset_top = 668
	add_child(thanks)
	Sfx.play_music("music_title")
	print("DEMO_COMPLETE time=%s deaths=%d kills=%d parries=%d rank=%s" % [Game.format_time(Game.run_time), Game.deaths, Game.kills, Game.parries, String(rank_info.grade)])


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


func _play_again() -> void:
	if _action_taken:
		return
	_action_taken = true
	Sfx.play("ui_confirm", -2.0)
	if Game.mode == "rematch":
		Game.start_rematch()
	else:
		Game.new_run()


func _go_title() -> void:
	if _action_taken:
		return
	_action_taken = true
	InkTheme.play_ui("ui_back", "ui_move", -4.0)
	Game.to_title()


func _unhandled_input(e: InputEvent) -> void:
	# fallback only while no button is focused: otherwise the focused button
	# owns Enter / A (its release would lose to this press - Play Again with
	# Enter or A used to go to the title instead)
	if get_viewport().gui_get_focus_owner() is BaseButton:
		return
	if t > 1.5 and (e.is_action_pressed("confirm") or e.is_action_pressed("attack")):
		_go_title()
