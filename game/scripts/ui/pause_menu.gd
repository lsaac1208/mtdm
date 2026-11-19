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
var buttons: Array = []


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.035, 0.03, 0.82)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -360
	box.offset_right = 360
	box.offset_top = -250
	box.offset_bottom = 250
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	root.add_child(box)
	var title := Label.new()
	title.text = "暂 停"
	title.add_theme_font_override("font", BRUSH_FONT)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.92, 0.84, 0.66))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var ctl := Label.new()
	_ctl = ctl
	Game.prompts_changed.connect(_refresh_controls)
	_refresh_controls()
	ctl.add_theme_font_size_override("font_size", 17)
	ctl.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62))
	ctl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(ctl)
	for b in [["继续", "_resume"], ["设置 Options", "_options"], ["回到篝火（重开本段）", "_restart"], ["返回标题", "_title"]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(320, 46)
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(Callable(self, b[1]))
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
	root.visible = true
	get_tree().paused = true
	_set_hud(false)
	buttons[0].grab_focus()


func _set_hud(v: bool) -> void:
	if Game.level and is_instance_valid(Game.level) and Game.level.hud:
		Game.level.hud.visible = v


func _resume() -> void:
	root.visible = false
	get_tree().paused = false
	_set_hud(true)


func _options() -> void:
	var o := OptionsMenu.new()
	add_child(o)
	o.closed.connect(func(): buttons[1].grab_focus())


func _restart() -> void:
	root.visible = false
	get_tree().paused = false
	get_tree().reload_current_scene()


func _title() -> void:
	Game.to_title()


func _options_open() -> bool:
	for c in get_children():
		if c is OptionsMenu:
			return true
	return false
