extends CanvasLayer
## Esc / Start: pause with controls reference, resume, restart from the last
## campfire, or return to title.

const BRUSH_FONT := preload("res://assets/fonts/MaShanZheng-subset.ttf")
const CONTROLS := """移动  {move_left} / {move_right}　　跳跃  {jump}　　冲刺  {dash}
攻击  {attack}（三段连斩）　　下劈  {move_down} + {attack}　　冲刺斩  冲刺中按 {attack}　　跳劈  空中按 {attack}
格挡  按住 {block}（出手瞬间格挡 = 弹反）
符箓  {talisman}（20 道力）　　阴阳葫芦  {gourd}（回血 + 震开）　　念珠  {beads}（50 道力）
暂停  {pause}　　F11 全屏"""

var root: Control
var _ctl: Label
var _summary: Label
var buttons: Array = []


func _ready() -> void:
	name = "Pause"
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.theme = InkTheme.shared()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.025, 0.02, 0.78)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", InkTheme.scroll_panel(34, 24, 0.94))
	panel.custom_minimum_size = Vector2(740, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "暂 停"
	title.add_theme_font_override("font", BRUSH_FONT)
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_color_override("font_color", Color(0.92, 0.84, 0.66))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 15)
	_summary.add_theme_color_override("font_color", Color(0.88, 0.72, 0.44))
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_summary)
	var ctl_card := PanelContainer.new()
	ctl_card.add_theme_stylebox_override("panel", InkTheme.inset_card(20, 12))
	box.add_child(ctl_card)
	var ctl := Label.new()
	_ctl = ctl
	Game.prompts_changed.connect(_refresh_controls)
	_refresh_controls()
	ctl.add_theme_font_size_override("font_size", 16)
	ctl.add_theme_color_override("font_color", Color(0.90, 0.84, 0.71))
	ctl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctl_card.add_child(ctl)
	for b in [["继续", "_resume"], ["设置 Options", "_options"], ["回到篝火（重开本段）", "_restart"], ["返回标题", "_title"]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(320, 46)
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(Callable(self, b[1]))
		InkTheme.wire_hover(btn)
		box.add_child(btn)
		buttons.append(btn)
	for btn in buttons:
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER



func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause") and not _options_open():
		if root.visible:
			_resume()
		else:
			_open()
		get_viewport().set_input_as_handled()


func _refresh_controls() -> void:
	_ctl.text = Game.fmt_keys(CONTROLS)


func _open() -> void:
	if Game.player and Game.player.dead:
		return
	var zname := "荒村"
	if Game.level and is_instance_valid(Game.level):
		var zidx: int = clampi(int(Game.level.zone_idx), 0, LevelData.ZONES.size() - 1)
		zname = String(LevelData.ZONES[zidx].cn)
	var diff_cn: String = ["故事", "常规", "修行"][clampi(Game.difficulty, 0, 2)]
	_summary.text = "%s　·　%s　·　用时 %s　·　斩祟 %d　·　弹反 %d" % [zname, diff_cn, Game.format_time(Game.run_time), Game.kills, Game.parries]
	root.visible = true
	get_tree().paused = true
	_set_hud(false)
	InkTheme.play_ui("ui_click", "ui_move", -7.0)
	buttons[0].grab_focus()


func _set_hud(v: bool) -> void:
	if Game.level and is_instance_valid(Game.level) and Game.level.hud:
		Game.level.hud.visible = v


func _resume() -> void:
	InkTheme.play_ui("ui_back", "ui_move", -7.0)
	root.visible = false
	get_tree().paused = false
	_set_hud(true)


func _options() -> void:
	InkTheme.play_ui("ui_click", "ui_move", -6.0)
	var o := OptionsMenu.new()
	add_child(o)
	o.closed.connect(func(): buttons[1].grab_focus())


func _restart() -> void:
	InkTheme.play_ui("ui_click", "ui_confirm", -4.0)
	root.visible = false
	get_tree().paused = false
	get_tree().reload_current_scene()


func _title() -> void:
	InkTheme.play_ui("ui_back", "ui_move", -5.0)
	Game.to_title()


func _options_open() -> bool:
	for c in get_children():
		if c is OptionsMenu:
			return true
	return false
