extends CanvasLayer
## In-game HUD: portrait, 气血 (HP) and 道力 (Qi) brush bars, gourd charges,
## skill readiness, boss bar, tutorial hints, zone title cards, fades.

const BRUSH_FONT := preload("res://assets/fonts/MaShanZheng-subset.ttf")

const COL_INK_PLAQUE := Color(0.085, 0.072, 0.060, 0.91)
const COL_INK_TRACK := Color(0.042, 0.035, 0.030, 0.95)
const COL_INK_KEYCAP := Color(0.115, 0.095, 0.078, 0.96)
const COL_BRASS := Color(0.76, 0.59, 0.34, 0.92)
const COL_BRASS_BRIGHT := Color(0.95, 0.80, 0.48, 0.98)
const COL_BRASS_DIM := Color(0.42, 0.34, 0.24, 0.72)
const COL_PAPER := Color(0.96, 0.91, 0.80)
const COL_PAPER_DIM := Color(0.66, 0.61, 0.54)
const COL_HP_FILL := Color(0.77, 0.21, 0.14)
const COL_HP_LOW := Color(0.95, 0.24, 0.14)
const COL_BOSS_HP := Color(0.56, 0.11, 0.09)
const COL_QI_FILL := Color(0.90, 0.67, 0.28)
const COL_QI_GLOW := Color(1.0, 0.86, 0.48)
const COL_BADGE_READY := Color(0.84, 0.74, 0.56, 0.98)
const COL_BADGE_DIM := Color(0.46, 0.41, 0.34, 0.88)
const COL_OUTLINE := Color(0.04, 0.03, 0.025, 0.92)

var player: Player
var boss: Node = null
var hp_disp := 1.0
var hp_lag := 1.0
var qi_disp := 0.4
var boss_lag := 1.0
var combo_disp := 0
var combo_pop := 0.0
var combo_alpha := 0.0
var hud_time := 0.0
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
var portrait_alert: Texture2D
var portrait_fierce: Texture2D
var portrait_combat: Texture2D
var portrait_hurt: Texture2D
var portrait_wistful: Texture2D
var portraits := {}
var _whisper_mood := "calm"
var _whisper_speaker := ""
var _whisper_text := ""
var _whisper_t := 0.0
var _whisper_dur := 4.4
var _whisper_alpha := 0.0
var icons := {}
var _sb_plaque: StyleBoxFlat
var _sb_track: StyleBoxFlat
var _sb_keycap_ready: StyleBoxFlat
var _sb_keycap_dim: StyleBoxFlat
var _sb_badge_ready: StyleBoxFlat
var _sb_badge_dim: StyleBoxFlat


func _ready() -> void:
	layer = 10
	draw_root = Control.new()
	draw_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	draw_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_root.draw.connect(_draw_hud)
	add_child(draw_root)
	_init_styleboxes()
	portrait = _load_portrait("res://assets/ui/portrait.png")
	portrait_alert = _load_portrait("res://assets/ui/portrait_alert.png")
	if portrait_alert == null:
		portrait_alert = portrait
	portrait_fierce = _load_portrait("res://assets/ui/portrait_fierce.png")
	if portrait_fierce == null:
		portrait_fierce = portrait
	portrait_combat = _load_portrait("res://assets/ui/portrait_combat.png")
	if portrait_combat == null:
		portrait_combat = portrait
	portrait_hurt = _load_portrait("res://assets/ui/portrait_hurt.png")
	if portrait_hurt == null:
		portrait_hurt = portrait
	portrait_wistful = _load_portrait("res://assets/ui/portrait_wistful.png")
	if portrait_wistful == null:
		portrait_wistful = portrait
	portraits = {
		"calm": portrait,
		"alert": portrait_alert,
		"fierce": portrait_fierce,
		"combat": portrait_combat,
		"hurt": portrait_hurt,
		"wistful": portrait_wistful,
	}
	for icon_key: String in ["icon_gourd", "icon_talisman", "icon_beads"]:
		icons[icon_key] = PoseSprite.tex(icon_key)
	# hint strip
	hint_panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.065, 0.055, 0.86)
	sb.border_color = COL_BRASS
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 2)
	sb.anti_aliasing = true
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
	Game.whisper.connect(_on_whisper)


func _init_styleboxes() -> void:
	_sb_plaque = StyleBoxFlat.new()
	_sb_plaque.bg_color = COL_INK_PLAQUE
	_sb_plaque.border_color = Color(COL_BRASS.r, COL_BRASS.g, COL_BRASS.b, 0.78)
	_sb_plaque.set_border_width_all(1)
	_sb_plaque.set_corner_radius_all(4)
	_sb_plaque.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
	_sb_plaque.shadow_size = 10
	_sb_plaque.shadow_offset = Vector2(0, 3)
	_sb_plaque.anti_aliasing = true

	_sb_track = StyleBoxFlat.new()
	_sb_track.bg_color = COL_INK_TRACK
	_sb_track.border_color = Color(COL_BRASS_DIM.r, COL_BRASS_DIM.g, COL_BRASS_DIM.b, 0.65)
	_sb_track.set_border_width_all(1)
	_sb_track.set_corner_radius_all(2)
	_sb_track.anti_aliasing = true

	_sb_keycap_ready = StyleBoxFlat.new()
	_sb_keycap_ready.bg_color = COL_INK_KEYCAP
	_sb_keycap_ready.border_color = COL_BRASS
	_sb_keycap_ready.set_border_width_all(1)
	_sb_keycap_ready.border_width_bottom = 2
	_sb_keycap_ready.set_corner_radius_all(3)
	_sb_keycap_ready.anti_aliasing = true

	_sb_keycap_dim = StyleBoxFlat.new()
	_sb_keycap_dim.bg_color = Color(0.08, 0.07, 0.06, 0.85)
	_sb_keycap_dim.border_color = COL_BRASS_DIM
	_sb_keycap_dim.set_border_width_all(1)
	_sb_keycap_dim.border_width_bottom = 2
	_sb_keycap_dim.set_corner_radius_all(3)
	_sb_keycap_dim.anti_aliasing = true

	_sb_badge_ready = StyleBoxFlat.new()
	_sb_badge_ready.bg_color = COL_BADGE_READY
	_sb_badge_ready.border_color = COL_BRASS_BRIGHT
	_sb_badge_ready.set_border_width_all(2)
	_sb_badge_ready.set_corner_radius_all(6)
	_sb_badge_ready.shadow_color = Color(0.95, 0.76, 0.42, 0.20)
	_sb_badge_ready.shadow_size = 4
	_sb_badge_ready.anti_aliasing = true

	_sb_badge_dim = StyleBoxFlat.new()
	_sb_badge_dim.bg_color = COL_BADGE_DIM
	_sb_badge_dim.border_color = COL_BRASS_DIM
	_sb_badge_dim.set_border_width_all(1)
	_sb_badge_dim.set_corner_radius_all(6)
	_sb_badge_dim.anti_aliasing = true


func _load_portrait(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var loaded: Resource = load(path)
	if loaded is Texture2D:
		return _round_portrait(loaded as Texture2D)
	return null


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
	# the intro card plays on the first meeting only; on retries it would sit
	# under the respawn line and slow the run-back (rendered review)
	if first and not Game.whispers_seen.has("_boss_intro"):
		Game.whispers_seen["_boss_intro"] = true
		zone_cn.text = "尸将 · 前期精英"
		zone_en.text = "残甲不毁，重压前行  ·  UNDEAD WARRIOR ELITE"
		zone_t = 3.2


func _on_player_died() -> void:
	zone_cn.text = "身 陨"
	zone_en.text = "道心未灭 —— 篝火处再起"
	zone_t = 2.6


## Cut the square portrait to a soft-edged disc so it sits inside the brass
## ring instead of poking its corners out of it.
static func _round_portrait(tex: Texture2D) -> Texture2D:
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var c := Vector2(w, h) * 0.5
	var r := minf(w, h) * 0.5
	for y in h:
		for x in w:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf((r - d) / 1.5, 0.0, 1.0)
			if a < 1.0:
				var px := img.get_pixel(x, y)
				px.a *= a
				img.set_pixel(x, y, px)
	return ImageTexture.create_from_image(img)


var _hint_presses := 0


## Contextual tutorial: once the player performs the move a hint teaches, the
## strip lingers ~1.2 s as confirmation and then gets out of the way.
func _track_hint_learning() -> void:
	if Game.hint_learn.is_empty() or hint_t <= 0.0:
		return
	for a in Game.hint_learn:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			_hint_presses += 1
	if _hint_presses >= Game.hint_need:
		Game.mark_hint_learned()
		hint_t = minf(hint_t, 1.2)
		hint_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.62))


func _on_hint(text: String, dur: float) -> void:
	_hint_presses = 0
	hint_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.7))
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


func _on_whisper(mood: String, speaker: String, text: String, dur: float) -> void:
	if String(Game.args.get("test", "")) == "readcap":
		return
	_whisper_mood = mood if portraits.has(mood) else "calm"
	_whisper_speaker = speaker
	_whisper_text = text
	_whisper_dur = maxf(2.0, dur)
	_whisper_t = _whisper_dur
	InkTheme.play_ui("whisper_chime", "", -8.0)


func _process(delta: float) -> void:
	var udt := Game.unscaled_delta(delta)
	hud_time += udt
	if player and is_instance_valid(player):
		var target: float = clampf(player.hp / maxf(1.0, player.max_hp), 0.0, 1.0)
		hp_disp = lerpf(hp_disp, target, minf(1.0, delta * 14.0))
		hp_lag = maxf(target, hp_lag - delta * 0.35) if hp_lag > target else target
		qi_disp = lerpf(qi_disp, clampf(player.qi / player.MAX_QI, 0.0, 1.0), minf(1.0, delta * 10.0))
		var want_combo := 1.0 if player.combo_hits >= 2 else 0.0
		combo_alpha = lerpf(combo_alpha, want_combo, minf(1.0, udt * 12.0))
		combo_pop = maxf(0.0, combo_pop - udt * 5.5)
	if boss and is_instance_valid(boss):
		var boss_max_hp: float = maxf(1.0, float(boss.max_hp))
		var bt: float = clampf(maxf(0.0, float(boss.hp)) / boss_max_hp, 0.0, 1.0)
		boss_lag = maxf(bt, boss_lag - delta * 0.25)
	hint_t = maxf(0.0, hint_t - delta)
	_track_hint_learning()
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
	if _whisper_t > 0.0:
		_whisper_t = maxf(0.0, _whisper_t - delta)
	var w_target := 0.0
	if _whisper_t > 0.0:
		var elapsed := _whisper_dur - _whisper_t
		w_target = clampf(minf(elapsed / 0.28, _whisper_t / 0.45), 0.0, 1.0)
	_whisper_alpha = lerpf(_whisper_alpha, w_target, minf(1.0, udt * 12.0))
	draw_root.queue_redraw()


func _draw_plaque(ci: Control, rect: Rect2) -> void:
	ci.draw_style_box(_sb_plaque, rect)
	# Subtle warm top highlight hairline
	ci.draw_line(
		Vector2(rect.position.x + 8.0, rect.position.y + 1.5),
		Vector2(rect.end.x - 8.0, rect.position.y + 1.5),
		Color(0.96, 0.86, 0.64, 0.22),
		1.0,
		true
	)
	# Subtle aged-brass corner bracket accents
	var corner_col := Color(COL_BRASS_BRIGHT.r, COL_BRASS_BRIGHT.g, COL_BRASS_BRIGHT.b, 0.72)
	var arm := 9.0
	var x0 := rect.position.x + 1.0
	var y0 := rect.position.y + 1.0
	var x1 := rect.end.x - 1.0
	var y1 := rect.end.y - 1.0
	ci.draw_line(Vector2(x0, y0 + arm), Vector2(x0, y0), corner_col, 1.5, true)
	ci.draw_line(Vector2(x0, y0), Vector2(x0 + arm, y0), corner_col, 1.5, true)
	ci.draw_line(Vector2(x1 - arm, y0), Vector2(x1, y0), corner_col, 1.5, true)
	ci.draw_line(Vector2(x1, y0), Vector2(x1, y0 + arm), corner_col, 1.5, true)
	ci.draw_line(Vector2(x0, y1 - arm), Vector2(x0, y1), corner_col, 1.5, true)
	ci.draw_line(Vector2(x0, y1), Vector2(x0 + arm, y1), corner_col, 1.5, true)
	ci.draw_line(Vector2(x1 - arm, y1), Vector2(x1, y1), corner_col, 1.5, true)
	ci.draw_line(Vector2(x1, y1 - arm), Vector2(x1, y1), corner_col, 1.5, true)


func _brush_bar(pos: Vector2, w: float, h: float, frac: float, lag: float, col: Color, pulse: float = 0.0) -> void:
	var ci := draw_root
	var outer := Rect2(pos, Vector2(w, h))
	if pulse > 0.01:
		ci.draw_rect(outer.grow(2.0), Color(0.92, 0.20, 0.12, 0.30 * pulse), true)
	ci.draw_style_box(_sb_track, outer)
	var ix := pos.x + 2.0
	var iy := pos.y + 2.0
	var iw := maxf(0.0, w - 4.0)
	var ih := maxf(2.0, h - 4.0)
	var cf := clampf(frac, 0.0, 1.0)
	var clag := clampf(lag, 0.0, 1.0)
	if clag > cf + 0.002:
		var lag_w := iw * clag
		ci.draw_rect(Rect2(Vector2(ix, iy), Vector2(lag_w, ih)), Color(0.96, 0.88, 0.72, 0.68), true)
	var fw := iw * cf
	if fw > 1.5:
		var fill_rect := Rect2(Vector2(ix, iy), Vector2(fw, ih))
		ci.draw_rect(fill_rect, col, true)
		# Top specular brush sheen and subtle lower ink weight for dimensional volume
		var sheen_h := maxf(2.0, floorf(ih * 0.34))
		ci.draw_rect(Rect2(Vector2(ix, iy), Vector2(fw, sheen_h)), Color(1.0, 0.95, 0.85, 0.22 + 0.10 * pulse), true)
		var shade_h := maxf(2.0, floorf(ih * 0.26))
		ci.draw_rect(Rect2(Vector2(ix, iy + ih - shade_h), Vector2(fw, shade_h)), Color(0.05, 0.02, 0.02, 0.32), true)
		# Bright leading tip highlight when bar is partially filled
		if cf < 0.992 and fw > 4.0:
			ci.draw_line(
				Vector2(ix + fw - 0.5, iy),
				Vector2(ix + fw - 0.5, iy + ih),
				Color(1.0, 0.94, 0.80, 0.55),
				1.5,
				true
			)
	if pulse > 0.01:
		ci.draw_rect(outer, Color(0.98, 0.34, 0.20, 0.65 * pulse), false, 1.5, true)


func _heartbeat_pulse() -> float:
	# Crisp double-beat cardiac pulse cycle (~1.15s) for critical HP readability
	var cycle := fmod(hud_time * 1.15, 1.0)
	var beat1 := exp(-pow((cycle - 0.14) / 0.075, 2.0))
	var beat2 := 0.72 * exp(-pow((cycle - 0.33) / 0.085, 2.0))
	return clampf(beat1 + beat2, 0.0, 1.0)


func _draw_portrait_medallion(ci: Control, center: Vector2, hp_ratio: float, low_pulse: float) -> void:
	var boss_active := boss != null and is_instance_valid(boss)
	var boss_p2: bool = boss_active and boss.get("phase2") == true
	var in_enc: bool = Game.level != null and is_instance_valid(Game.level) and Game.level.active_encounter_id() != ""
	var is_hurt := player.dead or player.state == "hit" or hp_ratio <= 0.35
	var is_fierce := boss_p2 or player.combo_hits >= 5
	var is_combat := player.guard_t > 0.0 or boss_active
	var tex: Texture2D = portrait
	if is_hurt and portrait_hurt != null:
		tex = portrait_hurt
	elif is_fierce and portrait_fierce != null:
		tex = portrait_fierce
	elif is_combat and portrait_combat != null:
		tex = portrait_combat
	elif in_enc and portrait_alert != null:
		tex = portrait_alert

	var outer_r := 30.0
	var disc_r := 27.5
	# Soft drop shadow and recessed dark well
	ci.draw_circle(center + Vector2(0.0, 2.0), outer_r + 2.5, Color(0.0, 0.0, 0.0, 0.48))
	if low_pulse > 0.01 and not player.dead:
		ci.draw_circle(center, outer_r + 3.5, Color(0.86, 0.18, 0.12, 0.26 * low_pulse))
	ci.draw_circle(center, outer_r, Color(0.06, 0.05, 0.045, 0.98))

	if tex != null:
		var tint := Color(0.96, 0.94, 0.90, 1.0)
		if player.dead:
			tint = Color(0.54, 0.52, 0.50, 0.92)
		elif is_hurt:
			tint = Color(0.98, 0.90, 0.86, 1.0)
		ci.draw_texture_rect(
			tex,
			Rect2(center - Vector2(disc_r, disc_r), Vector2(disc_r * 2.0, disc_r * 2.0)),
			false,
			tint
		)

	# Double-ring aged-brass frame with subtle state coloration
	var main_ring := COL_BRASS
	if player.dead:
		main_ring = COL_BRASS_DIM
	elif is_hurt:
		main_ring = COL_BRASS.lerp(Color(0.92, 0.32, 0.20, 0.98), 0.38 + 0.42 * low_pulse)
	elif is_combat:
		main_ring = COL_BRASS_BRIGHT

	ci.draw_arc(center, disc_r + 0.4, 0.0, TAU, 56, Color(0.09, 0.07, 0.05, 0.85), 2.0, true)
	ci.draw_arc(center, outer_r - 0.6, 0.0, TAU, 56, main_ring, 2.2, true)
	ci.draw_arc(center, outer_r + 2.0, 0.0, TAU, 56, Color(main_ring.r, main_ring.g, main_ring.b, 0.52), 1.0, true)
	# Four subtle cardinal brass rivets
	var stud_col := Color(COL_BRASS_BRIGHT.r, COL_BRASS_BRIGHT.g, COL_BRASS_BRIGHT.b, 0.85 if not player.dead else 0.4)
	for angle_idx in 4:
		var ang: float = float(angle_idx) * PI * 0.5
		var stud_pos := center + Vector2(cos(ang), sin(ang)) * (outer_r + 0.7)
		ci.draw_circle(stud_pos, 1.6, stud_col)


func _measure_skill_slot(font: Font, action: String, label_cn: String, is_gourd: bool) -> Dictionary:
	var key_txt: String = str(skill_keys.get(action, ""))
	if key_txt.is_empty():
		key_txt = "-"
	var key_sz: Vector2 = font.get_string_size(key_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	var key_w: float = maxf(20.0, ceilf(key_sz.x) + 10.0)
	var name_sz: Vector2 = font.get_string_size(label_cn, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	var row1_w: float = key_w + 6.0 + ceilf(name_sz.x)
	var row2_w: float = 58.0
	if is_gourd:
		var count_txt := "×%d" % player.gourd
		var cnt_sz: Vector2 = font.get_string_size(count_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		row2_w = float(player.GOURD_MAX) * 11.0 + 4.0 + ceilf(cnt_sz.x)
	var text_w: float = maxf(row1_w, row2_w)
	var total_w: float = 30.0 + 8.0 + text_w
	return {
		"key_txt": key_txt,
		"key_w": key_w,
		"text_w": text_w,
		"total_w": total_w,
	}


func _draw_skill_slot(ci: Control, font: Font, pos: Vector2, action: String, label_cn: String, ready: bool, metrics: Dictionary, qi_cost: float) -> void:
	var badge_size := 30.0
	var badge_rect := Rect2(pos, Vector2(badge_size, badge_size))
	ci.draw_style_box(_sb_badge_ready if ready else _sb_badge_dim, badge_rect)
	# Subtle warm inner sheen rim inside medallion
	var inner_rim := badge_rect.grow(-2.0)
	ci.draw_rect(
		inner_rim,
		Color(1.0, 0.94, 0.78, 0.28) if ready else Color(0.08, 0.06, 0.05, 0.30),
		false,
		1.0,
		true
	)

	var icon: Texture2D = icons.get("icon_" + action) as Texture2D
	if icon != null:
		var tex_sz: Vector2 = icon.get_size()
		var max_icon := 26.0
		var sc: float = minf(max_icon / maxf(1.0, tex_sz.x), max_icon / maxf(1.0, tex_sz.y))
		var draw_sz := tex_sz * sc
		var icon_pos := pos + (Vector2(badge_size, badge_size) - draw_sz) * 0.5
		var tint := Color(1.0, 1.0, 1.0, 1.0) if ready else Color(0.72, 0.68, 0.63, 0.86)
		ci.draw_texture_rect(icon, Rect2(icon_pos, draw_sz), false, tint)

	var text_x := pos.x + badge_size + 8.0
	var key_txt: String = str(metrics.get("key_txt", ""))
	var key_w: float = float(metrics.get("key_w", 20.0))
	var text_w: float = float(metrics.get("text_w", 58.0))

	# Compact brass-outlined dark keycap badge
	var key_rect := Rect2(Vector2(text_x, pos.y + 1.0), Vector2(key_w, 17.0))
	ci.draw_style_box(_sb_keycap_ready if ready else _sb_keycap_dim, key_rect)
	ci.draw_line(
		Vector2(key_rect.position.x + 2.0, key_rect.position.y + 1.5),
		Vector2(key_rect.end.x - 2.0, key_rect.position.y + 1.5),
		Color(1.0, 0.92, 0.74, 0.20 if ready else 0.08),
		1.0,
		true
	)
	var key_col := COL_BRASS_BRIGHT if ready else COL_PAPER_DIM
	ci.draw_string(
		font,
		Vector2(key_rect.position.x, key_rect.position.y + 13.0),
		key_txt,
		HORIZONTAL_ALIGNMENT_CENTER,
		key_w,
		12,
		key_col
	)

	# Chinese skill name beside keycap
	var name_col := COL_PAPER if ready else COL_PAPER_DIM
	var name_pos := Vector2(text_x + key_w + 6.0, pos.y + 14.5)
	ci.draw_string_outline(font, name_pos, label_cn, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 3, COL_OUTLINE)
	ci.draw_string(font, name_pos, label_cn, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, name_col)

	# Second micro-row: amber charge pips + count for gourd, mini Qi charge bar for talisman/beads
	var sub_y := pos.y + 24.0
	if qi_cost <= 0.0:
		var pip_x := text_x + 4.0
		for idx in player.GOURD_MAX:
			var filled: bool = idx < player.gourd
			var pc := Vector2(pip_x + float(idx) * 11.0, sub_y + 1.0)
			var diamond := PackedVector2Array([
				pc + Vector2(0.0, -4.0),
				pc + Vector2(4.0, 0.0),
				pc + Vector2(0.0, 4.0),
				pc + Vector2(-4.0, 0.0),
			])
			if filled:
				ci.draw_colored_polygon(diamond, Color(0.95, 0.68, 0.24, 0.98))
				ci.draw_circle(pc, 1.5, Color(1.0, 0.94, 0.74, 0.95))
			else:
				ci.draw_colored_polygon(diamond, Color(0.14, 0.11, 0.09, 0.90))
			ci.draw_polyline(
				PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]),
				COL_BRASS_BRIGHT if filled else COL_BRASS_DIM,
				1.0,
				true
			)
		var cnt_x := pip_x + float(player.GOURD_MAX) * 11.0 + 1.0
		var cnt_col := Color(0.98, 0.84, 0.50) if player.gourd > 0 else COL_PAPER_DIM
		ci.draw_string(font, Vector2(cnt_x, sub_y + 5.0), "×%d" % player.gourd, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, cnt_col)
	else:
		var cost_txt := str(int(roundf(qi_cost)))
		var cost_w := 16.0
		var prog_w := maxf(32.0, text_w - cost_w - 4.0)
		var prog_rect := Rect2(Vector2(text_x, sub_y - 1.5), Vector2(prog_w, 5.0))
		ci.draw_rect(prog_rect, COL_INK_TRACK, true)
		var prog_f := clampf(player.qi / qi_cost, 0.0, 1.0)
		if prog_f > 0.01:
			var fill_col := COL_QI_GLOW if ready else Color(0.76, 0.56, 0.25, 0.85)
			ci.draw_rect(Rect2(Vector2(text_x + 1.0, sub_y - 0.5), Vector2((prog_w - 2.0) * prog_f, 3.0)), fill_col, true)
		ci.draw_rect(prog_rect, COL_BRASS if ready else COL_BRASS_DIM, false, 1.0, true)
		ci.draw_string(
			font,
			Vector2(text_x + prog_w + 4.0, sub_y + 4.5),
			cost_txt,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			11,
			COL_QI_GLOW if ready else COL_PAPER_DIM
		)


func _draw_boss_bar(ci: Control, font: Font) -> void:
	var vs: Vector2 = ci.size
	var w: float = minf(620.0, vs.x - 220.0)
	var x0: float = (vs.x - w) * 0.5
	var y0: float = vs.y - 62.0
	var boss_max_hp: float = maxf(1.0, float(boss.max_hp))
	var bf: float = clampf(maxf(0.0, float(boss.hp)) / boss_max_hp, 0.0, 1.0)
	var boss_max_poise: float = maxf(1.0, float(boss.max_poise))
	var pf: float = clampf(maxf(0.0, float(boss.poise)) / boss_max_poise, 0.0, 1.0)
	var boss_state: String = str(boss.get("state"))
	var is_staggered: bool = boss_state == "stagger"
	var boss_phase: int = int(boss.get("phase")) if boss.get("phase") != null else 1

	# Layered ink-and-brass plaque backing
	var plaque_rect := Rect2(Vector2(x0 - 24.0, y0 - 42.0), Vector2(w + 48.0, 82.0))
	_draw_plaque(ci, plaque_rect)

	# Boss name + subtitle + phase indicator
	var title_cn := "尸将 · 前期精英"
	var title_pos := Vector2(x0, y0 - 11.0)
	ci.draw_string_outline(BRUSH_FONT, title_pos, title_cn, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 5, COL_OUTLINE)
	ci.draw_string(BRUSH_FONT, title_pos, title_cn, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.95, 0.87, 0.72))
	var title_w: float = BRUSH_FONT.get_string_size(title_cn, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	ci.draw_string(
		font,
		Vector2(x0 + title_w + 14.0, y0 - 13.0),
		"UNDEAD WARRIOR ELITE",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color(0.74, 0.64, 0.48, 0.92)
	)
	if boss_phase >= 2:
		var phase_txt := "二相 · 狂煞"
		ci.draw_string_outline(font, Vector2(x0, y0 - 13.0), phase_txt, HORIZONTAL_ALIGNMENT_RIGHT, w, 14, 3, COL_OUTLINE)
		ci.draw_string(font, Vector2(x0, y0 - 13.0), phase_txt, HORIZONTAL_ALIGNMENT_RIGHT, w, 14, Color(0.96, 0.42, 0.24))

	# Boss HP bar with clean brass end brackets and 50% phase tick
	_brush_bar(Vector2(x0, y0), w, 16.0, bf, boss_lag, COL_BOSS_HP, 0.0)
	var mid_x := x0 + w * 0.5
	ci.draw_line(Vector2(mid_x, y0 - 2.0), Vector2(mid_x, y0 + 18.0), Color(COL_BRASS.r, COL_BRASS.g, COL_BRASS.b, 0.65), 1.2, true)
	# Ornate brass end brackets
	for side_idx in 2:
		var sx: float = x0 - 4.0 if side_idx == 0 else x0 + w + 4.0
		var dir_x: float = 1.0 if side_idx == 0 else -1.0
		ci.draw_line(Vector2(sx, y0 - 3.0), Vector2(sx, y0 + 19.0), COL_BRASS_BRIGHT, 2.0, true)
		ci.draw_line(Vector2(sx, y0 - 3.0), Vector2(sx + dir_x * 6.0, y0 - 3.0), COL_BRASS_BRIGHT, 1.5, true)
		ci.draw_line(Vector2(sx, y0 + 19.0), Vector2(sx + dir_x * 6.0, y0 + 19.0), COL_BRASS_BRIGHT, 1.5, true)

	# Poise gauge directly beneath HP bar with clear 破甲 / 甲 badge
	var poise_y := y0 + 23.0
	var poise_label := "破甲" if is_staggered else "甲"
	var label_w := 34.0
	var poise_bar_x := x0 + label_w
	var poise_bar_w := w - label_w
	var poise_pulse := 0.5 + 0.5 * sin(hud_time * 12.0) if is_staggered else 0.0
	var label_col := Color(0.98, 0.56, 0.26).lerp(COL_BRASS_BRIGHT, poise_pulse) if is_staggered else Color(0.88, 0.77, 0.54)
	ci.draw_string_outline(font, Vector2(x0, poise_y + 9.0), poise_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, COL_OUTLINE)
	ci.draw_string(font, Vector2(x0, poise_y + 9.0), poise_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, label_col)
	var p_rect := Rect2(Vector2(poise_bar_x, poise_y + 1.0), Vector2(poise_bar_w, 7.0))
	ci.draw_style_box(_sb_track, p_rect)
	var p_fill_w: float = (poise_bar_w - 2.0) * (1.0 if is_staggered else pf)
	if p_fill_w > 1.0:
		var p_col := Color(0.96, 0.44, 0.20, 0.92) if is_staggered else Color(0.86, 0.75, 0.50, 0.92)
		ci.draw_rect(Rect2(Vector2(poise_bar_x + 1.0, poise_y + 2.0), Vector2(p_fill_w, 5.0)), p_col, true)
		ci.draw_rect(Rect2(Vector2(poise_bar_x + 1.0, poise_y + 2.0), Vector2(p_fill_w, 1.5)), Color(1.0, 0.96, 0.86, 0.30), true)


func _draw_hud() -> void:
	if player == null or not is_instance_valid(player):
		return
	var ci := draw_root
	var f: Font = ci.get_theme_default_font()
	var hp_ratio: float = clampf(player.hp / maxf(1.0, player.max_hp), 0.0, 1.0)
	var low_hp: bool = not player.dead and hp_ratio <= 0.30
	var low_pulse: float = _heartbeat_pulse() if low_hp else 0.0

	var skills: Array = [
		["gourd", "葫芦", player.gourd > 0, 0.0],
		["talisman", "符箓", player.qi >= player.TALISMAN_COST, player.TALISMAN_COST],
		["beads", "念珠", player.qi >= player.BEADS_COST, player.BEADS_COST],
	]
	# Measure skill row dynamically so long rebound key labels expand the plaque cleanly.
	var plaque_x := 18.0
	var plaque_y := 16.0
	var skill_x := plaque_x + 14.0
	var slots: Array[float] = []
	var slot_metrics: Array[Dictionary] = []
	for skill_idx in skills.size():
		var skill: Array = skills[skill_idx]
		var action_name: String = str(skill[0])
		var label_cn: String = str(skill[1])
		var qi_cost: float = float(skill[3])
		var m: Dictionary = _measure_skill_slot(f, action_name, label_cn, qi_cost <= 0.0)
		slots.append(skill_x)
		slot_metrics.append(m)
		skill_x += float(m.get("total_w", 96.0)) + 16.0

	var bar_x := plaque_x + 122.0
	var bar_w := 228.0
	var plaque_right := maxf(bar_x + bar_w + 18.0, skill_x)
	var plaque_h := 119.0
	var plaque_rect := Rect2(Vector2(plaque_x, plaque_y), Vector2(plaque_right - plaque_x, plaque_h))
	_draw_plaque(ci, plaque_rect)

	# Subtle horizontal aged-brass divider separating upper status bay and lower skill row
	var div_y := plaque_y + 73.0
	ci.draw_line(Vector2(plaque_x + 14.0, div_y), Vector2(plaque_right - 14.0, div_y), Color(COL_BRASS.r, COL_BRASS.g, COL_BRASS.b, 0.42), 1.0, true)

	# Dynamic 3-state circular bust portrait in double-ring aged-brass medallion
	var med_center := Vector2(plaque_x + 38.0, plaque_y + 36.5)
	_draw_portrait_medallion(ci, med_center, hp_ratio, low_pulse)

	# 气血 (HP) & 道力 (Qi) labels and bars
	var lbl_x := plaque_x + 82.0
	ci.draw_string_outline(f, Vector2(lbl_x, plaque_y + 29.0), "气血", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 3, COL_OUTLINE)
	ci.draw_string(f, Vector2(lbl_x, plaque_y + 29.0), "气血", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, COL_PAPER)
	ci.draw_string_outline(f, Vector2(lbl_x, plaque_y + 55.0), "道力", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 3, COL_OUTLINE)
	ci.draw_string(f, Vector2(lbl_x, plaque_y + 55.0), "道力", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, COL_PAPER)

	var hp_col := COL_HP_FILL.lerp(COL_HP_LOW, low_pulse * 0.78)
	var hp_pos := Vector2(bar_x, plaque_y + 15.0)
	_brush_bar(hp_pos, bar_w, 16.0, hp_disp, hp_lag, hp_col, low_pulse)
	var hp_cur := maxi(0, int(ceilf(player.hp)))
	var hp_max := maxi(1, int(roundf(player.max_hp)))
	var hp_txt := "%d/%d" % [hp_cur, hp_max]
	var hp_txt_col := COL_PAPER if not low_hp else Color(1.0, 0.86, 0.78)
	ci.draw_string_outline(f, Vector2(bar_x, hp_pos.y + 12.0), hp_txt, HORIZONTAL_ALIGNMENT_RIGHT, bar_w - 6.0, 12, 3, COL_OUTLINE)
	ci.draw_string(f, Vector2(bar_x, hp_pos.y + 12.0), hp_txt, HORIZONTAL_ALIGNMENT_RIGHT, bar_w - 6.0, 12, hp_txt_col)

	var qi_pos := Vector2(bar_x, plaque_y + 44.0)
	_brush_bar(qi_pos, bar_w, 11.0, qi_disp, qi_disp, COL_QI_FILL, 0.0)
	# Clear brass threshold notches on the Qi bar at TALISMAN_COST (20) and BEADS_COST (50)
	for cost_val: float in [player.TALISMAN_COST, player.BEADS_COST]:
		var met: bool = player.qi >= cost_val
		var nx: float = bar_x + 2.0 + (bar_w - 4.0) * (cost_val / player.MAX_QI)
		ci.draw_line(Vector2(nx, qi_pos.y + 1.0), Vector2(nx, qi_pos.y + 10.0), COL_INK_TRACK, 2.0, true)
		var tick_col := COL_QI_GLOW if met else COL_BRASS_DIM
		ci.draw_line(Vector2(nx, qi_pos.y - 2.5), Vector2(nx, qi_pos.y + 2.5), tick_col, 1.8 if met else 1.2, true)
		ci.draw_line(Vector2(nx, qi_pos.y + 8.5), Vector2(nx, qi_pos.y + 13.5), tick_col, 1.8 if met else 1.2, true)
		if met:
			ci.draw_circle(Vector2(nx, qi_pos.y - 2.5), 1.8, COL_QI_GLOW)

	# Skill row (葫芦, 符箓, 念珠)
	var skill_y := plaque_y + 80.0
	for i in skills.size():
		var skill: Array = skills[i]
		_draw_skill_slot(
			ci,
			f,
			Vector2(slots[i], skill_y),
			str(skill[0]),
			str(skill[1]),
			bool(skill[2]),
			slot_metrics[i],
			float(skill[3])
		)

	if boss and is_instance_valid(boss):
		_draw_boss_bar(ci, f)
	if _whisper_alpha > 0.02 and not _whisper_text.is_empty():
		_draw_whisper(ci, f)
	if combo_alpha > 0.02 and combo_disp >= 2:
		_draw_combo(ci)


func _draw_whisper(ci: Control, f: Font) -> void:
	var vs := ci.size
	var a := _whisper_alpha
	var slide := (1.0 - a) * 20.0
	var w := 428.0
	var h := 76.0
	var x := vs.x - w - 18.0 + slide
	var y := 18.0
	var rect := Rect2(Vector2(x, y), Vector2(w, h))
	ci.draw_rect(rect.grow(1.0), Color(0.0, 0.0, 0.0, 0.36 * a), true)
	ci.draw_rect(rect, Color(COL_INK_PLAQUE.r, COL_INK_PLAQUE.g, COL_INK_PLAQUE.b, 0.90 * a), true)
	ci.draw_rect(rect, Color(COL_BRASS.r, COL_BRASS.g, COL_BRASS.b, 0.80 * a), false, 1.2, true)
	# Cinnabar left scroll accent bar
	ci.draw_rect(Rect2(Vector2(x, y + 2.0), Vector2(3.5, h - 4.0)), Color(0.76, 0.22, 0.14, 0.92 * a), true)
	ci.draw_line(Vector2(x + 6.0, y + 1.5), Vector2(x + w - 6.0, y + 1.5), Color(1.0, 0.92, 0.75, 0.14 * a), 1.0, true)
	# Portrait medallion
	var p_center := Vector2(x + 40.0, y + h * 0.5)
	var disc_r := 25.0
	ci.draw_circle(p_center, disc_r + 2.5, Color(0.05, 0.04, 0.035, 0.95 * a))
	var ptex: Texture2D = portraits.get(_whisper_mood, portrait)
	if ptex != null:
		ci.draw_texture_rect(
			ptex,
			Rect2(p_center - Vector2(disc_r, disc_r), Vector2(disc_r * 2.0, disc_r * 2.0)),
			false,
			Color(0.98, 0.96, 0.92, a)
		)
	ci.draw_arc(p_center, disc_r + 1.8, 0.0, TAU, 48, Color(COL_BRASS_BRIGHT.r, COL_BRASS_BRIGHT.g, COL_BRASS_BRIGHT.b, 0.86 * a), 1.6, true)
	# Speaker & wrapped two-line dialogue
	var tx := x + 78.0
	var tw := w - 92.0
	var spk := _whisper_speaker if not _whisper_speaker.is_empty() else "道行者"
	ci.draw_string_outline(f, Vector2(tx, y + 23.0), spk, HORIZONTAL_ALIGNMENT_LEFT, tw, 13, 3, Color(0.04, 0.03, 0.025, 0.90 * a))
	ci.draw_string(f, Vector2(tx, y + 23.0), spk, HORIZONTAL_ALIGNMENT_LEFT, tw, 13, Color(COL_BRASS_BRIGHT.r, COL_BRASS_BRIGHT.g, COL_BRASS_BRIGHT.b, 0.95 * a))
	ci.draw_multiline_string_outline(f, Vector2(tx, y + 44.0), _whisper_text, HORIZONTAL_ALIGNMENT_LEFT, tw, 15, 2, 3, Color(0.04, 0.03, 0.025, 0.92 * a))
	ci.draw_multiline_string(f, Vector2(tx, y + 44.0), _whisper_text, HORIZONTAL_ALIGNMENT_LEFT, tw, 15, 2, Color(COL_PAPER.r, COL_PAPER.g, COL_PAPER.b, 0.96 * a))


func _draw_combo(ci: Control) -> void:
	var vs := ci.size
	var cx := vs.x - 122.0
	var cy := 152.0 if _whisper_alpha > 0.08 else 132.0
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
	# a still-visible boss intro / zone title would stack under the seal card
	zone_t = minf(zone_t, 0.25)
	var flash := ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 0.97, 0.9, 0.85 * Game.flash_scale)
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
	# lift the card into the sky band: centred it covered the falling elite
	# and the hero for the whole slow-motion payoff (rendered defeatcap)
	seal.offset_top -= 150.0
	seal.offset_bottom -= 150.0
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
	cap.text = "%s · 已镇" % cn
	cap.add_theme_font_override("font", BRUSH_FONT)
	cap.add_theme_font_size_override("font_size", 34)
	cap.add_theme_color_override("font_color", Color(0.93, 0.86, 0.7))
	cap.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.03))
	cap.add_theme_constant_override("outline_size", 8)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.position = Vector2(-300, 44)
	cap.size = Vector2(600, 50)
	seal.add_child(cap)
	# The brush face has no proper Latin glyphs; the English line uses the
	# body serif, small caps-sized and tracked, like the zone cards.
	var cap_en := Label.new()
	cap_en.text = "%s  SEALED" % en.to_upper()
	cap_en.add_theme_font_size_override("font_size", 17)
	cap_en.add_theme_color_override("font_color", Color(0.88, 0.80, 0.64))
	cap_en.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.03))
	cap_en.add_theme_constant_override("outline_size", 6)
	cap_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap_en.position = Vector2(-300, 96)
	cap_en.size = Vector2(600, 30)
	seal.add_child(cap_en)
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
