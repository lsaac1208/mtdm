class_name DestructibleProp
extends Node2D
## Breakable painted wasteland prop (ceramic urn, wooden crate, bronze brazier).
## Reacts to sword strikes with shards, sound, and Dao spirit wisp drops.

const WispScript := preload("res://scripts/level/spirit_wisp.gd")

const SPECS := {
	"urn": {
		"intact": "res://assets/env/painted/prop_urn.webp",
		"broken": "res://assets/env/painted/prop_urn_broken.webp",
		"h": 72.0, "broken_h": 46.0, "w": 54.0,
		"sfx": "pot_break", "debris": Color(0.64, 0.47, 0.35),
		"qi": 10.0, "hp": 0.0, "wisps": 1,
	},
	"crate": {
		"intact": "res://assets/env/painted/prop_crate.webp",
		"broken": "res://assets/env/painted/prop_crate_broken.webp",
		"h": 68.0, "broken_h": 44.0, "w": 78.0,
		"sfx": "wood_break", "debris": Color(0.50, 0.36, 0.24),
		"qi": 8.0, "hp": 0.0, "wisps": 1,
	},
	"brazier": {
		"intact": "res://assets/env/painted/prop_brazier.webp",
		"broken": "res://assets/env/painted/prop_brazier_broken.webp",
		"h": 82.0, "broken_h": 58.0, "w": 68.0,
		"sfx": "brazier_clang", "debris": Color(0.38, 0.32, 0.26),
		"qi": 12.0, "hp": 8.0, "wisps": 2,
	},
}

var prop_id := ""
var prop_type := "urn"
var broken := false
var zone_tint := Color(0.92, 0.90, 0.86)
var t := 0.0

var _spec: Dictionary = {}
var _sprite: Sprite2D
var _shadow: Sprite2D
var _hit_w := 56.0
var _hit_h := 70.0
var _jolt := 0.0
var _jolt_dir := 1


func _ready() -> void:
	add_to_group("destructible")
	z_index = 2
	_spec = SPECS.get(prop_type, SPECS["urn"])
	_hit_w = float(_spec.w)
	_hit_h = float(_spec.h)
	_shadow = Sprite2D.new()
	_shadow.texture = Fx.dot_texture()
	_shadow.scale = Vector2(_hit_w * 1.28, 18.0) / 24.0 * 1.4
	_shadow.position = Vector2(0.0, 2.0)
	_shadow.modulate = Color(0.09, 0.07, 0.05, 0.42)
	add_child(_shadow)
	_sprite = Sprite2D.new()
	if broken:
		_apply_tex(String(_spec.broken), float(_spec.broken_h))
		_sprite.modulate = zone_tint.darkened(0.08)
		_shadow.scale.x *= 1.18
		_shadow.modulate.a = 0.30
	else:
		_apply_tex(String(_spec.intact), float(_spec.h))
		_sprite.modulate = zone_tint
	add_child(_sprite)


func _apply_tex(path: String, target_h: float) -> void:
	var tex: Texture2D = load(path)
	if tex == null:
		return
	_sprite.texture = tex
	var sc := target_h / float(tex.get_height())
	_sprite.scale = Vector2.ONE * sc
	_sprite.offset = Vector2(0.0, -tex.get_height() * 0.5)
	_sprite.position = Vector2(0.0, 2.0)


func _process(delta: float) -> void:
	t += delta
	if _jolt > 0.0:
		_jolt = maxf(0.0, _jolt - delta * 6.5)
		_sprite.position.x = sin(_jolt * 38.0) * _jolt * 7.0 * float(_jolt_dir)
		_sprite.scale.y = (float(_spec.broken_h) / float(_sprite.texture.get_height())) * (1.0 - _jolt * 0.14) if _sprite.texture else 1.0
	elif _sprite.position.x != 0.0:
		_sprite.position.x = 0.0
	if is_lit_brazier():
		queue_redraw()


func is_lit_brazier() -> bool:
	return prop_type == "brazier" and not broken


func get_hit_rect() -> Rect2:
	if broken:
		return Rect2()
	return Rect2(global_position.x - _hit_w * 0.5, global_position.y - _hit_h, _hit_w, _hit_h)


func take_sword_hit(dir: int) -> bool:
	if broken:
		return false
	broken = true
	Game.mark_prop_broken(prop_id)
	_jolt = 1.0
	_jolt_dir = dir if dir != 0 else 1
	_apply_tex(String(_spec.broken), float(_spec.broken_h))
	_sprite.modulate = zone_tint.darkened(0.08)
	_shadow.scale.x *= 1.18
	_shadow.modulate.a = 0.30
	var sfx_name := String(_spec.sfx)
	Sfx.play(sfx_name, -2.5, 0.12)
	var burst_pos := global_position + Vector2(0.0, -_hit_h * 0.45)
	var debris: Color = _spec.debris
	var push_dir := Vector2(float(_jolt_dir) * 0.72, -0.69).normalized()
	Fx.particles(burst_pos, 16, debris, 210.0, 58.0, push_dir, 640.0, 0.55, 5.2)
	Fx.particles(burst_pos, 8, Color(0.84, 0.78, 0.68, 0.85), 115.0, 75.0, Vector2.UP, 90.0, 0.42, 4.0)
	if prop_type == "brazier":
		Fx.particles(burst_pos + Vector2(0.0, -14.0), 18, Color(1.0, 0.62, 0.22), 230.0, 70.0, Vector2.UP, 240.0, 0.72, 4.4)
		Fx.ring(burst_pos, 16.0, 78.0, Color(1.0, 0.70, 0.28), 0.28, 4.0, 0.75)
	else:
		Fx.ring(burst_pos, 10.0, 52.0, debris.lightened(0.28), 0.20, 3.0, 0.65)
	if Game.level and is_instance_valid(Game.level):
		Game.level.shake(2.4, 0.07)
	_spawn_wisps(burst_pos)
	queue_redraw()
	return true


func _spawn_wisps(origin: Vector2) -> void:
	var count := int(_spec.wisps)
	var total_qi := float(_spec.qi)
	var total_hp := float(_spec.hp)
	var parent_node: Node = Fx.layer()
	if parent_node == null:
		parent_node = get_parent()
	for i in count:
		var w := WispScript.new()
		w.position = origin + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 6.0))
		w.vel = Vector2(float(_jolt_dir) * randf_range(55.0, 125.0) + randf_range(-35.0, 35.0), randf_range(-255.0, -185.0))
		if i == 0:
			w.qi_amount = total_qi
			w.hp_amount = 0.0
			w.tint = Color(0.74, 0.94, 0.68)
			w.core = Color(1.0, 0.98, 0.86)
		else:
			w.qi_amount = 0.0
			w.hp_amount = total_hp
			w.tint = Color(1.0, 0.62, 0.28)
			w.core = Color(1.0, 0.93, 0.76)
		parent_node.add_child(w)


func _draw() -> void:
	if not is_lit_brazier():
		return
	var f := 0.86 + 0.14 * sin(t * 12.2) * sin(t * 6.9)
	var flame_y := -_hit_h + 14.0
	draw_set_transform(Vector2(0.0, flame_y), 0.0, Vector2(1.0, 0.62))
	draw_circle(Vector2.ZERO, 66.0 * f, Color(1.0, 0.56, 0.20, 0.07))
	draw_circle(Vector2.ZERO, 36.0 * f, Color(1.0, 0.68, 0.26, 0.13))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in 3:
		var ox := (i - 1) * 6.5
		var fh := (20.0 - absf(ox) * 1.1) * f
		var bend := sin(t * 9.0 + i * 2.1) * 2.6
		var base := Vector2(ox, flame_y + 2.0)
		var pts := PackedVector2Array([
			base + Vector2(-4.5, 0.0),
			base + Vector2(-3.5, -fh * 0.42),
			base + Vector2(bend, -fh),
			base + Vector2(3.8, -fh * 0.42),
			base + Vector2(4.5, 0.0),
		])
		draw_colored_polygon(pts, Color(1.0, 0.52 + i * 0.10, 0.16, 0.86))
