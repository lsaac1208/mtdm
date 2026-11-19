extends CanvasLayer
## In-game HUD: portrait, 气血 (HP) and 道力 (Qi) brush bars, gourd charges,
## skill readiness, boss bar, tutorial hints, zone title cards, fades.

const BRUSH_FONT := preload("res://assets/fonts/MaShanZheng-subset.ttf")

var player: Player
var boss: Node = null
var hp_disp := 1.0
var hp_lag := 1.0
var qi_disp := 0.4
var boss_lag := 1.0
var combo_disp := 0
var combo_pop := 0.0
var combo_alpha := 0.0
var hint_label: Label
var hint_panel: Panel
var hint_t := 0.0
var hint_template := ""
var skill_keys := {}
var zone_cn: Label
var zone_en: Label
var zone_t := 0.0
var fade: ColorRect
var draw_root: Control
var portrait: Texture2D
var icons := {}


func _ready() -> void:
	layer = 10
	draw_root = Control.new()
	draw_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	draw_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_root.draw.connect(_draw_hud)
	add_child(draw_root)
	if ResourceLoader.exists("res://assets/ui/portrait.png"):
		portrait = load("res://assets/ui/portrait.png")
	for k in ["icon_gourd", "icon_talisman", "icon_beads"]:
		icons[k] = PoseSprite.tex(k)
	# hint strip
	hint_panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.06, 0.78)
	sb.border_color = Color(0.6, 0.48, 0.28, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	hint_panel.add_theme_stylebox_override("panel", sb)
	hint_panel.anchor_left = 0.5
	hint_panel.anchor_right = 0.5
	hint_panel.anchor_top = 1.0
	hint_panel.anchor_bottom = 1.0
	hint_panel.offset_left = -430
	hint_panel.offset_right = 430
	hint_panel.offset_top = -132
	hint_panel.offset_bottom = -84
	hint_panel.modulate.a = 0.0
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint_panel)
	hint_label = Label.new()
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_font_size_override("font_size", 20)
	hint_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.7))
	hint_panel.add_child(hint_label)
	# zone card
	zone_cn = _label(BRUSH_FONT, 64, Color(0.93, 0.86, 0.7))
	zone_cn.anchor_left = 0.5
	zone_cn.anchor_right = 0.5
	zone_cn.offset_left = -400
	zone_cn.offset_right = 400
	zone_cn.offset_top = 120
	zone_cn.offset_bottom = 200
	zone_en = _label(null, 18, Color(0.85, 0.75, 0.55))
	zone_en.anchor_left = 0.5
	zone_en.anchor_right = 0.5
	zone_en.offset_left = -400
	zone_en.offset_right = 400
	zone_en.offset_top = 198
	zone_en.offset_bottom = 226
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.03, 0.03, 0.03, 1.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	if Game.run_time < 0.5 and Game.checkpoint_id == 0 and Game.deaths == 0 and not Game.args.has("startx"):
		_opening()
	else:
		create_tween().tween_property(fade, "color:a", 0.0, 0.8)
	Game.hint.connect(_on_hint)
	Game.prompts_changed.connect(_refresh_prompts)
	_refresh_prompts()
	Game.zone_entered.connect(_on_zone)
	Game.boss_changed.connect(_on_boss)


func _opening() -> void:
	var l1 := _label(BRUSH_FONT, 46, Color(0.92, 0.85, 0.7))
	l1.text = "末日废土之上，道法不灭，万物异变。"
	l1.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l1.offset_left = -500
	l1.offset_right = 500
	l1.offset_top = -60
	l1.offset_bottom = 10
	var l2 := _label(null, 18, Color(0.75, 0.66, 0.5))
	l2.text = "In the wasteland, the Tao endures; all things rot and transform."
	l2.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l2.offset_left = -500
	l2.offset_right = 500
	l2.offset_top = 20
	l2.offset_bottom = 50
	move_child(fade, get_child_count() - 1)
	move_child(l1, get_child_count() - 1)
	move_child(l2, get_child_count() - 1)
	if player:
		player.controls_locked = true
	var tw := create_tween()
	tw.tween_property(l1, "modulate:a", 1.0, 0.9)
	tw.parallel().tween_property(l2, "modulate:a", 1.0, 0.9).set_delay(0.4)
	tw.tween_interval(1.8)
	tw.tween_property(l1, "modulate:a", 0.0, 0.7)
	tw.parallel().tween_property(l2, "modulate:a", 0.0, 0.7)
	tw.tween_property(fade, "color:a", 0.0, 1.0)
	tw.tween_callback(func():
		if player and is_instance_valid(player):
			player.controls_locked = false
		zone_t = 3.2
		l1.queue_free()
		l2.queue_free())


func _label(font: Font, size: int, col: Color) -> Label:
	var l := Label.new()
	if font:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.03, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.modulate.a = 0.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func bind(p: Player) -> void:
	player = p
	p.died.connect(_on_player_died)
	p.combo_changed.connect(_on_combo)


func _on_combo(count: int) -> void:
	if count > combo_disp and count >= 2:
		combo_pop = 1.0
	combo_disp = count


func _on_boss(b) -> void:
	var first := boss == null and b != null
	boss = b
	boss_lag = 1.0
	if first:
		zone_cn.text = "尸将 · 前期精英"
		zone_en.text = "残甲不毁，重压前行  ·  UNDEAD WARRIOR ELITE"
		zone_t = 3.2


func _on_player_died() -> void:
	zone_cn.text = "身 陨"
	zone_en.text = "道心未灭 —— 篝火处再起"
	zone_t = 2.6


func _on_hint(text: String, dur: float) -> void:
	hint_template = text
	hint_label.text = Game.fmt_keys(hint_template)
	hint_t = dur


func _refresh_prompts() -> void:
	hint_label.text = Game.fmt_keys(hint_template)
	for action in ["gourd", "talisman", "beads"]:
		skill_keys[action] = Game.binding_label(action, true)
	draw_root.queue_redraw()


func _on_zone(cn: String, en: String) -> void:
	zone_cn.text = cn
	zone_en.text = en.to_upper()
	zone_t = 3.2


func _process(delta: float) -> void:
	var udt := Game.unscaled_delta(delta)
	if player and is_instance_valid(player):
		var target := player.hp / player.max_hp
		hp_disp = lerpf(hp_disp, target, minf(1.0, delta * 14.0))
		hp_lag = maxf(target, hp_lag - delta * 0.35) if hp_lag > target else target
		qi_disp = lerpf(qi_disp, player.qi / player.MAX_QI, minf(1.0, delta * 10.0))
		var want_combo := 1.0 if player.combo_hits >= 2 else 0.0
		combo_alpha = lerpf(combo_alpha, want_combo, minf(1.0, udt * 12.0))
		combo_pop = maxf(0.0, combo_pop - udt * 5.5)
	if boss and is_instance_valid(boss):
		var bt: float = maxf(0.0, boss.hp) / boss.max_hp
		boss_lag = maxf(bt, boss_lag - delta * 0.25)
	hint_t = maxf(0.0, hint_t - delta)
	# During the boss fight the bottom band holds the boss bar and the fight
	# itself fills the ground line, so the hint moves under the top HUD
	# instead of covering both fighters' feet.
	var boss_on: bool = boss != null and is_instance_valid(boss)
	var anchor := 0.0 if boss_on else 1.0
	var hy := 238.0 if boss_on else -132.0   # below the boss title card
	hint_panel.anchor_top = anchor
	hint_panel.anchor_bottom = anchor
	hint_panel.offset_top = hy
	hint_panel.offset_bottom = hy + 48.0
	hint_panel.modulate.a = lerpf(hint_panel.modulate.a, 1.0 if hint_t > 0.0 else 0.0, minf(1.0, delta * 8.0))
	zone_t = maxf(0.0, zone_t - delta)
	var za := clampf(minf(zone_t, 3.2 - zone_t) / 0.6, 0.0, 1.0)
	zone_cn.modulate.a = za
	zone_en.modulate.a = za
	draw_root.queue_redraw()


func _brush_bar(pos: Vector2, w: float, h: float, frac: float, lag: float, col: Color) -> void:
	var ci := draw_root
	# ink backing stroke with ragged ends
	var back := PackedVector2Array([pos + Vector2(-8, 2), pos + Vector2(w + 10, -2), pos + Vector2(w + 4, h + 3), pos + Vector2(-4, h + 5)])
	ci.draw_colored_polygon(back, Color(0.05, 0.04, 0.04, 0.85))
	if lag > frac:
		ci.draw_rect(Rect2(pos + Vector2(0, 2), Vector2(w * lag, h - 4)), Color(0.95, 0.85, 0.7, 0.55))
	var fw := w * clampf(frac, 0.0, 1.0)
	if fw > 6.0:
		var fill := PackedVector2Array([pos + Vector2(0, 3), pos + Vector2(fw, 1), pos + Vector2(fw - 3, h - 1), pos + Vector2(0, h - 3)])
		ci.draw_colored_polygon(fill, col)
		ci.draw_line(pos + Vector2(2, 5), pos + Vector2(fw - 4, 4), Color(1, 1, 1, 0.18), 2.0)


func _draw_hud() -> void:
	if player == null or not is_instance_valid(player):
		return
	var ci := draw_root
	var f: Font = ci.get_theme_default_font()
	var ink := Color(0.10, 0.09, 0.08, 0.91)
	var paper := Color(0.96, 0.90, 0.76)
	var brass := Color(0.72, 0.54, 0.32)
	var skills := [
		["gourd", "葫芦 ×%d" % player.gourd, player.gourd > 0],
		["talisman", "符箓", player.qi >= player.TALISMAN_COST],
		["beads", "念珠", player.qi >= player.BEADS_COST],
	]
	# Let long rebound key names extend the ink backing, without moving the bars.
	var skill_x := 26.0
	var slots: Array[float] = []
	for skill in skills:
		slots.append(skill_x)
		skill_x += 26.0 + f.get_string_size("%s  %s" % [skill_keys[skill[0]], skill[1]], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 16.0
	var right := maxf(360.0, skill_x)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(17, 17), Vector2(right + 8, 16), Vector2(right, 65),
		Vector2(right + 2, 99), Vector2(20, 101), Vector2(15, 62)]), ink)
	ci.draw_line(Vector2(28, 68), Vector2(right - 12, 68), Color(brass, 0.45), 1.0)
	var c := Vector2(49, 44)
	ci.draw_circle(c, 25.0, ink)
	if portrait:
		ci.draw_texture_rect(portrait, Rect2(c - Vector2(23, 23), Vector2(46, 46)), false, Color(0.89, 0.84, 0.76))
	ci.draw_arc(c, 25.0, 0, TAU, 48, brass, 1.5, true)
	ci.draw_string(f, Vector2(86, 40), "气血", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, paper)
	ci.draw_string(f, Vector2(86, 62), "道力", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, paper)
	_brush_bar(Vector2(130, 26), 210, 13, hp_disp, hp_lag, Color(0.78, 0.24, 0.16))
	_brush_bar(Vector2(130, 48), 168, 11, qi_disp, qi_disp, Color(0.90, 0.67, 0.29))
	for cost in [player.TALISMAN_COST, player.BEADS_COST]:
		var x: float = 130 + 168 * cost / player.MAX_QI
		ci.draw_line(Vector2(x, 50), Vector2(x, 57), ink, 2.0)
	for i in skills.size():
		var skill: Array = skills[i]
		_skill(Vector2(slots[i], 74), skill[0], skill[1], skill[2])
	# boss bar
	if boss and is_instance_valid(boss):
		var vs := ci.size
		var w := minf(640.0, vs.x - 200)
		var x0 := (vs.x - w) / 2.0
		var y0 := vs.y - 62
		var bf: float = maxf(0.0, boss.hp) / boss.max_hp
		ci.draw_string(BRUSH_FONT, Vector2(x0, y0 - 10), "尸将 · 前期精英", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.92, 0.82, 0.66))
		ci.draw_string(f, Vector2(x0 + 220, y0 - 12), "UNDEAD WARRIOR ELITE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.6, 0.45))
		_brush_bar(Vector2(x0, y0), w, 16, bf, boss_lag, Color(0.48, 0.1, 0.08))
		var pf: float = clampf(boss.poise / boss.max_poise, 0.0, 1.0)
		ci.draw_rect(Rect2(x0, y0 + 22, w * pf, 5), Color(0.85, 0.75, 0.55, 0.85))
		ci.draw_string(f, Vector2(x0 + w + 8, y0 + 30), "甲", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.75, 0.55))
	if combo_alpha > 0.02 and combo_disp >= 2:
		_draw_combo(ci)


func _draw_combo(ci: Control) -> void:
	var vs := ci.size
	var cx := vs.x - 122.0
	var cy := 132.0
	var a := combo_alpha
	var pop := 1.0 + 0.28 * sin(combo_pop * PI * 0.5)
	var num_sz := int(roundf(58.0 * pop))
	var num_txt := str(combo_disp)
	var num_col := Color(1.0, 0.78, 0.34, a) if combo_disp < 6 else Color(0.96, 0.36, 0.18, a)
	var ink_bg := PackedVector2Array([
		Vector2(cx - 58.0, cy - 34.0), Vector2(cx + 88.0, cy - 38.0),
		Vector2(cx + 76.0, cy + 20.0), Vector2(cx - 46.0, cy + 24.0),
	])
	ci.draw_colored_polygon(ink_bg, Color(0.07, 0.05, 0.05, 0.68 * a))
	ci.draw_string_outline(BRUSH_FONT, Vector2(cx - 52.0, cy + 12.0), num_txt, HORIZONTAL_ALIGNMENT_RIGHT, 84.0, num_sz, 7, Color(0.06, 0.04, 0.04, 0.92 * a))
	ci.draw_string(BRUSH_FONT, Vector2(cx - 52.0, cy + 12.0), num_txt, HORIZONTAL_ALIGNMENT_RIGHT, 84.0, num_sz, num_col)
	ci.draw_string_outline(BRUSH_FONT, Vector2(cx + 36.0, cy + 6.0), "连斩", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 5, Color(0.06, 0.04, 0.04, 0.88 * a))
	ci.draw_string(BRUSH_FONT, Vector2(cx + 36.0, cy + 6.0), "连斩", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.96, 0.90, 0.76, a))
	var frac := clampf(player.combo_timer / player.COMBO_WINDOW, 0.0, 1.0)
	var bar_w := 118.0
	ci.draw_rect(Rect2(cx - 42.0, cy + 22.0, bar_w, 4.0), Color(0.12, 0.09, 0.08, 0.72 * a))
	ci.draw_rect(Rect2(cx - 42.0, cy + 22.0, bar_w * frac, 4.0), Color(num_col.r, num_col.g, num_col.b, 0.92 * a))


func _skill(pos: Vector2, action: String, name_: String, ready: bool) -> void:
	var ci := draw_root
	var icon: Texture2D = icons.get("icon_" + action)
	if icon:
		var tint := Color.WHITE if ready else Color(0.52, 0.50, 0.46)
		ci.draw_texture_rect(icon, Rect2(pos, Vector2(23, 23)), false, tint)
	var text := "%s  %s" % [skill_keys[action], name_]
	ci.draw_string(ci.get_theme_default_font(), pos + Vector2(26, 17), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
		Color(0.96, 0.90, 0.76) if ready else Color(0.74, 0.70, 0.63))


func fade_out(dur: float, col := Color(0.03, 0.03, 0.03)) -> void:
	fade.color = Color(col.r, col.g, col.b, fade.color.a)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, dur)
	await tw.finished


func fade_in(dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, dur)
	await tw.finished


## Boss defeat: white flash, letterbox, red 镇 seal stamp with caption.
func boss_defeated(cn: String, en: String) -> void:
	var flash := ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 0.97, 0.9, 0.85)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	create_tween().set_ignore_time_scale(true).tween_property(flash, "color:a", 0.0, 0.6)
	var bars := []
	for top in [true, false]:
		var b := ColorRect.new()
		b.color = Color(0.03, 0.03, 0.03, 1)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.anchor_right = 1.0
		if top:
			b.offset_bottom = 0.0
		else:
			b.anchor_top = 1.0
			b.anchor_bottom = 1.0
			b.offset_top = 0.0
		add_child(b)
		bars.append(b)
		var tw := create_tween().set_ignore_time_scale(true)
		if top:
			tw.tween_property(b, "offset_bottom", 70.0, 0.4)
		else:
			tw.tween_property(b, "offset_top", -70.0, 0.4)
	var seal := Control.new()
	seal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(seal)
	var sq := ColorRect.new()
	sq.color = Color(0.62, 0.12, 0.08, 0.92)
	sq.size = Vector2(150, 150)
	sq.position = Vector2(-75, -120)
	seal.add_child(sq)
	var inner := ReferenceRect.new()
	inner.border_color = Color(0.95, 0.85, 0.7, 0.9)
	inner.border_width = 4.0
	inner.editor_only = false
	inner.size = Vector2(130, 130)
	inner.position = Vector2(-65, -110)
	seal.add_child(inner)
	var ch := Label.new()
	ch.text = "镇"
	ch.add_theme_font_override("font", BRUSH_FONT)
	ch.add_theme_font_size_override("font_size", 112)
	ch.add_theme_color_override("font_color", Color(0.97, 0.9, 0.78))
	ch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ch.position = Vector2(-75, -128)
	ch.size = Vector2(150, 150)
	seal.add_child(ch)
	var cap := Label.new()
	cap.text = "%s · 已镇\n%s SEALED" % [cn, en]
	cap.add_theme_font_override("font", BRUSH_FONT)
	cap.add_theme_font_size_override("font_size", 34)
	cap.add_theme_color_override("font_color", Color(0.93, 0.86, 0.7))
	cap.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.03))
	cap.add_theme_constant_override("outline_size", 8)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.position = Vector2(-300, 44)
	cap.size = Vector2(600, 100)
	seal.add_child(cap)
	seal.scale = Vector2(2.4, 2.4)
	seal.modulate.a = 0.0
	seal.rotation = -0.12
	var st := create_tween().set_ignore_time_scale(true)
	st.tween_interval(0.5)
	st.tween_property(seal, "modulate:a", 1.0, 0.08)
	st.parallel().tween_property(seal, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	st.parallel().tween_property(seal, "rotation", -0.05, 0.18)
	st.tween_callback(func(): Sfx.play("seal_burst", -4.0, 0.0, 0.7); Fx.shake(5.0, 0.2))
	st.tween_interval(2.4)
	st.tween_property(seal, "modulate:a", 0.0, 0.8)
	for b in bars:
		var bt := create_tween().set_ignore_time_scale(true)
		bt.tween_interval(3.0)
		if b.anchor_top == 0.0:
			bt.tween_property(b, "offset_bottom", 0.0, 0.6)
		else:
			bt.tween_property(b, "offset_top", 0.0, 0.6)
		bt.tween_callback(b.queue_free)
	st.tween_callback(func(): seal.queue_free(); flash.queue_free())
