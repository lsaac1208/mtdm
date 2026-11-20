class_name FrameAnim
extends Node2D
## Hand-painted frame-by-frame sprite animation player with paired 2.5D normal,
## thickness, and crevice-AO maps baked by tools/art/build_anim_sheets.py.
## Replaces cutout paper-doll limbs for locomotion, airborne arcs, and core
## monster animations so figures stay anatomically cohesive with 3D volume.

const SHADER := preload("res://shaders/ink_sprite.gdshader")
static var _cache := {}
static var _tex_cache := {}

var pivot: Node2D
var sprite: Sprite2D
var _mat: ShaderMaterial
var _dir := ""
var _data := {}
var _target_h := 150.0

var current := ""
var speed_scale := 1.0
var facing := 1
var lean := 0.0
var squash := Vector2.ONE
var bob := 0.0
var nudge := Vector2.ZERO
var extra_scale := 1.0
var breathe := 0.0
var flash := 0.0
var tint := Color.WHITE
var dissolve := 0.0
var alpha := 1.0
var air_height := 0.0

var _time := 0.0
var _frame_idx := 0
var _locked := false
var _frame_meta := {}
var _toff := randf() * 10.0


func _init() -> void:
	pivot = Node2D.new()
	pivot.name = "FramePivot"
	add_child(pivot)
	sprite = Sprite2D.new()
	sprite.name = "FrameSprite"
	sprite.centered = false
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("time_offset", _toff)
	_mat.set_shader_parameter("outline_px", 0.0)
	_mat.set_shader_parameter("halo_px", 0.0)
	sprite.material = _mat
	pivot.add_child(sprite)
	sprite.visible = false


static func _load_manifest(anim_dir: String) -> Dictionary:
	if _cache.has(anim_dir):
		return _cache[anim_dir]
	var path := anim_dir + "/anims.json"
	if not FileAccess.file_exists(path):
		_cache[anim_dir] = {}
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f else null
	var data: Dictionary = parsed if parsed is Dictionary else {}
	_cache[anim_dir] = data
	return data


static func _load_tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	if not ResourceLoader.exists(path):
		_tex_cache[path] = null
		return null
	var t: Texture2D = load(path)
	_tex_cache[path] = t
	return t


func setup(anim_dir: String) -> bool:
	_dir = anim_dir
	_data = _load_manifest(anim_dir)
	if _data.is_empty() or not _data.has("clips"):
		return false
	_target_h = float(_data.get("target_h", 150.0))
	return true


func has_clip(clip: String) -> bool:
	return _data.has("clips") and (_data.clips as Dictionary).has(clip)


func play(clip: String, restart := false) -> bool:
	if not has_clip(clip):
		return false
	_locked = false
	if clip == current and not restart:
		return true
	current = clip
	_time = 0.0
	_frame_idx = -1
	_apply_frame(0)
	return true


func set_frame(clip: String, idx: int) -> bool:
	if not has_clip(clip):
		return false
	var c: Dictionary = _data.clips[clip]
	var frames: Array = c.frames
	if frames.is_empty():
		return false
	var clamped := clampi(idx, 0, frames.size() - 1)
	_locked = true
	if clip != current or clamped != _frame_idx:
		current = clip
		var fps := maxf(float(c.get("fps", 8.0)), 0.001)
		_time = float(clamped) / fps
		_apply_frame(clamped)
	return true


func current_frame_index() -> int:
	return _frame_idx


func sync_facing(f: int) -> void:
	facing = f
	pivot.scale = Vector2(facing * squash.x, squash.y) * extra_scale


func clip_duration() -> float:
	if current == "" or not has_clip(current):
		return 0.5
	var c: Dictionary = _data.clips[current]
	var frames: Array = c.frames
	var fps := maxf(float(c.get("fps", 8.0)), 0.001)
	return maxf(float(frames.size()) / fps, 0.001)


func clip_progress() -> float:
	if current == "" or not has_clip(current):
		return 0.0
	var c: Dictionary = _data.clips[current]
	var dur := clip_duration()
	if bool(c.get("loop", false)):
		return fposmod(_time / dur, 1.0)
	return clampf(_time / dur, 0.0, 1.0)


func current_frame_meta() -> Dictionary:
	return _frame_meta


func height_px() -> float:
	if not _frame_meta.is_empty():
		var h := float(_frame_meta.get("body_h", 0.0)) * float(_frame_meta.get("scale", 0.5))
		if h > 10.0:
			return h
	return _target_h


func visual_center() -> Vector2:
	if not _frame_meta.is_empty() and sprite.texture != null:
		var fx := float(_frame_meta.get("foot_x", 0.0))
		var fy := float(_frame_meta.get("foot_y", 0.0))
		var bh := float(_frame_meta.get("body_h", _target_h * 2.0))
		return sprite.global_transform * Vector2(fx, fy - bh * 0.5)
	return global_position + Vector2(0.0, -_target_h * 0.5)


func step_anim(delta: float, light: Dictionary) -> void:
	pivot.scale = Vector2(facing * squash.x, squash.y) * extra_scale
	pivot.rotation = deg_to_rad(lean) * facing
	pivot.position = Vector2(nudge.x * facing, nudge.y - bob)
	if not _locked and current != "" and has_clip(current):
		var c: Dictionary = _data.clips[current]
		var frames: Array = c.frames
		var n := frames.size()
		if n > 0:
			var fps := maxf(float(c.get("fps", 8.0)), 0.001)
			var dur := float(n) / fps
			_time += delta * maxf(speed_scale, 0.0)
			var idx := 0
			if bool(c.get("loop", false)):
				_time = fposmod(_time, dur)
				idx = mini(int(floor(_time * fps)), n - 1)
			else:
				_time = minf(_time, dur)
				idx = mini(int(floor(_time * fps)), n - 1)
			if idx != _frame_idx:
				_apply_frame(idx)
	_update_shader(light)


func _apply_frame(idx: int) -> void:
	var c: Dictionary = _data.clips[current]
	var frames: Array = c.frames
	if idx < 0 or idx >= frames.size():
		return
	_frame_idx = idx
	var md: Dictionary = frames[idx]
	_frame_meta = md
	var fname: String = md.file
	var tex := _load_tex(_dir + "/" + fname)
	if tex == null:
		sprite.visible = false
		return
	sprite.texture = tex
	_mat.set_shader_parameter("src_tex", tex)
	var npath := _dir + "/" + fname.get_basename() + "_n.png"
	var ntex := _load_tex(npath)
	if ntex != null:
		_mat.set_shader_parameter("normal_tex", ntex)
		_mat.set_shader_parameter("use_normal", 1.0)
	else:
		_mat.set_shader_parameter("use_normal", 0.0)
	var sc := float(md.get("scale", 0.5))
	sprite.scale = Vector2(sc, sc)
	sprite.position = Vector2(-float(md.foot_x) * sc, -float(md.foot_y) * sc)
	sprite.visible = true


func _update_shader(light: Dictionary) -> void:
	_mat.set_shader_parameter("facing_sign", float(facing))
	_mat.set_shader_parameter("air_height", air_height)
	_mat.set_shader_parameter("sway", 0.0)
	_mat.set_shader_parameter("stride", 0.0)
	_mat.set_shader_parameter("legs", 0.0)
	_mat.set_shader_parameter("leg_lift", 0.0)
	_mat.set_shader_parameter("tuck", 0.0)
	_mat.set_shader_parameter("torso_twist", 0.0)
	_mat.set_shader_parameter("ribbon", 0.0)
	_mat.set_shader_parameter("arm0_tp", Vector4.ZERO)
	_mat.set_shader_parameter("arm1_tp", Vector4.ZERO)
	_mat.set_shader_parameter("breathe", breathe)
	_mat.set_shader_parameter("flash", flash)
	_mat.set_shader_parameter("tint", tint)
	_mat.set_shader_parameter("dissolve", dissolve)
	_mat.set_shader_parameter("alpha_mul", alpha)
	if not _frame_meta.is_empty():
		_mat.set_shader_parameter("foot_v", float(_frame_meta.foot_y) / maxf(float(_frame_meta.h), 1.0))
	if not light.is_empty():
		PoseSprite.apply_light_uniforms(_mat, light)
