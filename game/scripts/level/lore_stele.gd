class_name LoreStele
extends Node2D
## A readable inscribed stele (残碑). Environmental storytelling: when the hero
## stands beside it a small brush prompt rises; pressing {move_up} opens an
## ink-scroll reading card (pauses play — the player asked for it). Each stele
## is counted once per run in Game.lore_read and shown in the Journey Ledger.

const BRUSH_FONT := preload("res://assets/fonts/MaShanZheng-subset.ttf")
const REACH := 70.0

var data: Dictionary = {}
var zone_tint := Color.WHITE
var _sprite: Sprite2D
var _glow := 0.0
var _near := false
var _prompt: Label
var _t := 0.0


func _ready() -> void:
	z_index = 2
	_sprite = Sprite2D.new()
	var tex: Texture2D = load("res://assets/env/painted/tablet.webp")
	_sprite.texture = tex
	var h := 124.0 if data.has("after") else 104.0
	_sprite.scale = Vector2.ONE * h / tex.get_height()
	_sprite.offset.y = -tex.get_height() * 0.5
	_sprite.position.y = 1.0
	# lift out of the zone's shadow tint a little so the stone reads against
	# dark grounds (burial mound) without breaking the palette
	_sprite.modulate = zone_tint.lerp(Color(1.0, 0.95, 0.86), 0.35)
	add_child(_sprite)
	_prompt = Label.new()
	_prompt.add_theme_font_override("font", BRUSH_FONT)
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.9, 0.62))
	_prompt.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.9))
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(160, 34)
	_prompt.position = Vector2(-80, -212)
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.06, 0.045, 0.035, 0.72)
	plate.border_color = Color(0.76, 0.59, 0.34, 0.7)
	plate.border_width_bottom = 1
	plate.border_width_top = 1
	plate.set_corner_radius_all(3)
	_prompt.add_theme_stylebox_override("normal", plate)
	_prompt.modulate.a = 0.0
	_prompt.z_index = 20
	add_child(_prompt)
	_refresh_prompt()


func _refresh_prompt() -> void:
	var read := Game.lore_read.has(String(data.get("id", "")))
	_prompt.text = Game.fmt_keys("{move_up} 读碑") if not read else Game.fmt_keys("{move_up} 重读")


## Steles tied to an encounter ("after") stay buried until it is cleared,
## then rise out of the ground.
func is_available() -> bool:
	var dep := String(data.get("after", ""))
	return dep == "" or Game.cleared.has(dep)


var _rise := -1.0


func is_read() -> bool:
	return Game.lore_read.has(String(data.get("id", "")))


func _process(delta: float) -> void:
	_t += delta
	var avail := is_available()
	if _rise < 0.0:
		_rise = 1.0 if avail else 0.0
	_rise = move_toward(_rise, 1.0 if avail else 0.0, delta * 0.7)
	visible = _rise > 0.0
	_sprite.position.y = 1.0 + (1.0 - _rise) * 40.0
	_sprite.modulate.a = _rise
	var p = Game.player
	_near = false
	if _rise < 1.0:
		queue_redraw()
		return
	if p != null and is_instance_valid(p) and not p.dead:
		_near = absf(p.global_position.x - global_position.x) < REACH \
			and absf(p.global_position.y - global_position.y) < 40.0
	# unread steles breathe a faint gold inscription glow so they read as
	# "something here" from a distance without shouting over combat
	var want := 1.0 if _near else (0.6 if not is_read() else 0.0)
	_glow = move_toward(_glow, want, delta * 3.0)
	# never offer a read mid-fight: it clutters combat and would pause it
	var calm := Sfx.mix_state != "combat"
	_prompt.modulate.a = move_toward(_prompt.modulate.a, 1.0 if _near and calm else 0.0, delta * 6.0)
	_prompt.position.y = -212.0 - 3.0 * sin(_t * 2.4)
	queue_redraw()


func _physics_process(_delta: float) -> void:
	# physics tick: Props run before Actors, so a harness one-shot press is
	# still visible here before the player consumes it
	var p = Game.player
	if _near and p != null and is_instance_valid(p) and _can_read(p) and _up_pressed(p):
		open_reader()


func _can_read(p) -> bool:
	return p.is_on_floor() and String(p.state) in ["idle", "run", "land"] and not p.controls_locked \
		and not get_tree().paused and Sfx.mix_state != "combat"


func _up_pressed(p) -> bool:
	if p.input_override != null:
		return p.input_override.get("move_up_just", false)
	return Input.is_action_just_pressed("move_up")


func open_reader() -> void:
	var first := not is_read()
	Game.lore_read[String(data.id)] = true
	_refresh_prompt()
	var r := LoreReader.new()
	r.data = data
	r.first = first
	get_tree().root.add_child(r)


func _draw() -> void:
	# rising reveal: a soft column of light while a gated stele surfaces
	if _rise > 0.0 and _rise < 1.0:
		var k := sin(_rise * PI)
		draw_rect(Rect2(-34, -420, 68, 420), Color(1.0, 0.84, 0.5, 0.16 * k))
		draw_rect(Rect2(-14, -420, 28, 420), Color(1.0, 0.9, 0.66, 0.22 * k))
	if _glow <= 0.01:
		return
	var a := _glow * (0.6 + 0.25 * sin(_t * 2.0))
	var cy := -_sprite.texture.get_height() * _sprite.scale.y * 0.55
	for i in 4:
		var rr := 28.0 + i * 11.0
		draw_circle(Vector2(0, cy), rr, Color(1.0, 0.78, 0.36, a * 0.08))
	# a few rising gold motes off the inscription
	for i in 3:
		var ph := fmod(_t * 0.5 + i * 0.33, 1.0)
		draw_circle(Vector2(-12 + i * 12 + sin(_t + i) * 4.0, cy + 10.0 - ph * 70.0), 2.0, Color(1.0, 0.86, 0.5, a * (1.0 - ph)))
