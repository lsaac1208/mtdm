class_name PoseSprite
extends Node2D
## Key-pose sprite renderer. Each pose is a transparent cut-out from the
## concept sheets (tools/art/extract.py) anchored at the feet. Motion between
## poses comes from short cross-fades plus procedural transforms (lean,
## squash, bob) and the ink_sprite shader (cloth sway, stride, flash, burn).

const META_PATH := "res://assets/sprites/sprites_meta.json"
const SHADER := preload("res://shaders/ink_sprite.gdshader")
static var _meta := {}
static var _tex := {}
static var _rig := {}
var arm_rot := [0.0, 0.0]
var arm_off := [Vector2.ZERO, Vector2.ZERO]

var rig: Node2D
var cur: Sprite2D
var prev: Sprite2D
var pose := ""
var facing := 1
var lean := 0.0            # degrees, positive = lean forward
var squash := Vector2.ONE
var bob := 0.0             # px, upward positive
var nudge := Vector2.ZERO  # px, x forward
var extra_scale := 1.0
var sway := 0.004
var stride := 0.0
var legs := 0.0
var leg_lift := 0.0
var tuck := 0.0
var torso_twist := 0.0
var ribbon := 0.0
var hip_frac := 0.47       # hip height as a fraction of body height
var phase := 0.0
var breathe := 0.0
var flash := 0.0
var tint := Color.WHITE
var dissolve := 0.0
var jitter := 0.0
var alpha := 1.0
var painted_mul := 1.0
var _fade := 0.0
var _fade_len := 0.0
var _toff := randf() * 10.0


static func meta(name_: String) -> Dictionary:
	if _meta.is_empty():
		var f := FileAccess.open(META_PATH, FileAccess.READ)
		_meta = JSON.parse_string(f.get_as_text())
	return _meta.get(name_, {})


static func rig_data(name_: String) -> Dictionary:
	if _rig.is_empty():
		var f := FileAccess.open("res://assets/sprites/rig.json", FileAccess.READ)
		_rig = JSON.parse_string(f.get_as_text()) if f else {"_": {}}
	return _rig.get(name_, {})


static func tex(name_: String) -> Texture2D:
	if not _tex.has(name_):
		_tex[name_] = load("res://assets/sprites/%s.png" % name_)
	return _tex[name_]


func _init() -> void:
	rig = Node2D.new()
	add_child(rig)
	prev = _make_sprite()
	cur = _make_sprite()


func _make_sprite() -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("time_offset", _toff)
	s.material = m
	rig.add_child(s)
	s.visible = false
	return s


func _apply(s: Sprite2D, name_: String) -> void:
	var md := meta(name_)
	if md.is_empty():
		push_warning("missing pose " + name_)
		return
	s.texture = tex(name_)
	(s.material as ShaderMaterial).set_shader_parameter("src_tex", s.texture)
	var sc: float = md.scale
	s.scale = Vector2(sc, sc)
	s.position = Vector2(-md.foot_x * sc, -md.foot_y * sc)
	s.visible = true


func set_pose(name_: String, fade := 0.06) -> void:
	if name_ == pose:
		return
	if pose != "" and fade > 0.0:
		_apply(prev, pose)
		prev.visible = true
		_fade = fade
		_fade_len = fade
	else:
		prev.visible = false
	pose = name_
	_apply(cur, name_)


func pose_height() -> float:
	var md := meta(pose)
	return md.get("body_h", 0.0) * md.get("scale", 1.0)


func _process(delta: float) -> void:
	rig.scale = Vector2(facing * squash.x, squash.y) * extra_scale
	rig.rotation = deg_to_rad(lean) * facing
	var jit := Vector2.ZERO
	if jitter > 0.0:
		jitter = maxf(0.0, jitter - delta)
		jit = Vector2(randf_range(-1, 1) * 4.0, randf_range(-1, 1) * 1.5) * (jitter / 0.15)
	rig.position = Vector2(nudge.x * facing, nudge.y - bob) + jit
	nudge = nudge.lerp(Vector2.ZERO, minf(1.0, delta * 10.0))
	if _fade > 0.0:
		_fade -= delta
		if _fade <= 0.0:
			prev.visible = false
	var fa := clampf(_fade / maxf(_fade_len, 0.001), 0.0, 1.0)
	_set_params(cur, alpha * painted_mul * (1.0 - fa * 0.5))
	if prev.visible:
		_set_params(prev, alpha * painted_mul * fa)
	flash = maxf(0.0, flash - delta * 6.0)


func _set_params(s: Sprite2D, a: float) -> void:
	var m: ShaderMaterial = s.material
	m.set_shader_parameter("sway", sway)
	m.set_shader_parameter("stride", stride)
	m.set_shader_parameter("legs", legs)
	m.set_shader_parameter("leg_lift", leg_lift)
	m.set_shader_parameter("tuck", tuck)
	m.set_shader_parameter("torso_twist", torso_twist)
	var arms: Array = rig_data(pose).get("arms", [])
	for i in 2:
		var pre := "arm%d_" % i
		if i < arms.size():
			var b: Dictionary = arms[i]
			var tip: Array = b.get("t", b.h)
			m.set_shader_parameter(pre + "sh", Vector4(b.s[0], b.s[1], b.h[0], b.h[1]))
			m.set_shader_parameter(pre + "tp", Vector4(tip[0], tip[1], b.w, b.get("tw", 0.0)))
			m.set_shader_parameter(pre + "x", Vector3(arm_rot[i], arm_off[i].x, arm_off[i].y))
		else:
			m.set_shader_parameter(pre + "tp", Vector4.ZERO)
	m.set_shader_parameter("ribbon", ribbon)
	var md := meta(pose)
	if not md.is_empty():
		m.set_shader_parameter("split_x", md.foot_x / md.w)
		m.set_shader_parameter("foot_v", md.foot_y / md.h)
		m.set_shader_parameter("hip_y", (md.foot_y - md.body_h * hip_frac) / md.h)
	m.set_shader_parameter("phase", phase)
	m.set_shader_parameter("breathe", breathe)
	m.set_shader_parameter("flash", flash)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("dissolve", dissolve)
	m.set_shader_parameter("alpha_mul", a)
