class_name CutoutRig
extends CanvasGroup
## Skinned cut-out character built from a rig exported by tools/rig/make_rig.py:
## Skeleton2D + Bone2D hierarchy, one Polygon2D mesh per body part (bone
## weights per vertex), AnimationPlayer clips compiled from keyframe tables,
## crossfade blending, and spring-driven secondary motion for ribbons/panels.
## The CanvasGroup composites all parts so the ink outline / flash / burn
## shader applies to the whole figure.

const GROUP_SHADER := preload("res://shaders/rig_group.gdshader")
const SPRING_BONES := {"ribbon1": [0.9, 120.0, 11.0], "ribbon2": [1.0, 140.0, 9.0],
	"panel_b1": [0.55, 110.0, 12.0], "panel_b2": [0.7, 130.0, 10.0],
	"panel_f1": [0.5, 110.0, 12.0], "panel_f2": [0.65, 130.0, 10.0]}   # drag, stiffness, damping

var pivot: Node2D
var skeleton: Skeleton2D
var player: AnimationPlayer
var bones := {}           # name -> Bone2D
var rest_rot := {}        # name -> rest rotation
var rest_pos := {}
var px_scale := 1.0
var facing := 1
var lean := 0.0
var squash := Vector2.ONE
var bob := 0.0
var nudge := Vector2.ZERO
var flash := 0.0
var tint := Color.WHITE
var dissolve := 0.0
var alpha := 1.0
var speed_scale := 1.0
var current := ""
var _springs := {}        # bone -> [angle, vel]
var _last_head := {}
var _mat: ShaderMaterial
static var _cache := {}


func setup(rig_dir: String, clips: Dictionary) -> void:
	var data: Dictionary = _load(rig_dir)
	px_scale = data.scale
	fit_margin = 16.0
	clear_margin = 16.0
	_mat = ShaderMaterial.new()
	_mat.shader = GROUP_SHADER
	material = _mat
	pivot = Node2D.new()
	pivot.name = "Pivot"
	add_child(pivot)
	skeleton = Skeleton2D.new()
	skeleton.name = "Skeleton2D"
	pivot.add_child(skeleton)
	var heads := {}
	for b in data.bones:
		heads[b.name] = Vector2(b.head[0], b.head[1])
	for b in data.bones:
		var bone := Bone2D.new()
		bone.name = b.name
		var parent: Node = skeleton if b.parent == null else bones[b.parent]
		var ppos: Vector2 = Vector2.ZERO if b.parent == null else heads[b.parent]
		bone.position = (heads[b.name] as Vector2) - ppos
		bone.rest = Transform2D(0.0, bone.position)
		bone.set_autocalculate_length_and_angle(false)
		var tail: Vector2 = Vector2(b.tail[0], b.tail[1]) - heads[b.name]
		bone.set_length(maxf(tail.length(), 1.0))
		bone.set_bone_angle(tail.angle())
		parent.add_child(bone)
		bones[b.name] = bone
		rest_rot[b.name] = 0.0
		rest_pos[b.name] = bone.position
	var parts: Array = data.parts.duplicate()
	parts.sort_custom(func(a, b): return a.z < b.z)
	for p in parts:
		var poly := Polygon2D.new()
		poly.name = "part_" + p.name
		poly.texture = data.tex[p.name]
		var pts := PackedVector2Array()
		for v in p.verts:
			pts.append(Vector2(v[0], v[1]))
		var uvs := PackedVector2Array()
		for u in p.uv:
			uvs.append(Vector2(u[0], u[1]))
		poly.polygon = pts
		poly.uv = uvs
		var tris := []
		for t in p.tris:
			tris.append(PackedInt32Array(t))
		poly.polygons = tris
		pivot.add_child(poly)
		poly.skeleton = poly.get_path_to(skeleton)
		for bname in p.weights:
			poly.add_bone(NodePath(_bone_path(bname)), PackedFloat32Array(p.weights[bname]))
	for s in SPRING_BONES:
		if bones.has(s):
			_springs[s] = [0.0, 0.0]
	player = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	add_child(player)
	player.root_node = player.get_path_to(pivot)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var lib := AnimationLibrary.new()
	for cname in clips:
		lib.add_animation(cname, _build(clips[cname]))
	player.add_animation_library("", lib)
	pivot.scale = Vector2(px_scale, px_scale)


func _bone_path(bname: String) -> String:
	var path := bname
	var n: Node = bones[bname].get_parent()
	while n is Bone2D:
		path = n.name + "/" + path
		n = n.get_parent()
	return path


static func _load(rig_dir: String) -> Dictionary:
	if _cache.has(rig_dir):
		return _cache[rig_dir]
	var f := FileAccess.open(rig_dir + "/rig.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	data["tex"] = {}
	for p in data.parts:
		data.tex[p.name] = load(rig_dir + "/" + p.png)
	_cache[rig_dir] = data
	return data


func _build(clip: Dictionary) -> Animation:
	var a := Animation.new()
	a.length = clip.len
	a.loop_mode = Animation.LOOP_LINEAR if clip.get("loop", false) else Animation.LOOP_NONE
	for bname in clip.tracks:
		var keys: Array = clip.tracks[bname]
		if bname == "@root":
			var tr := a.add_track(Animation.TYPE_VALUE)
			a.track_set_path(tr, "Skeleton2D/root:position")
			a.track_set_interpolation_type(tr, Animation.INTERPOLATION_CUBIC)
			for k in keys:
				a.track_insert_key(tr, k[0] * clip.len, rest_pos["root"] + k[1])
			continue
		if not bones.has(bname):
			continue
		var tr2 := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(tr2, "Skeleton2D/" + _bone_path(bname) + ":rotation")
		a.track_set_interpolation_type(tr2, Animation.INTERPOLATION_CUBIC)
		for k in keys:
			a.track_insert_key(tr2, k[0] * clip.len, deg_to_rad(k[1]))
	return a


## Play a clip with a crossfade (seconds). Bones not keyed by the clip ease back to rest.
func play(clip: String, blend := 0.1, restart := false) -> void:
	if clip == current and not restart:
		return
	current = clip
	player.play(clip, blend)
	if restart:
		player.seek(0.0, true)


## Rest-pose figure height in game pixels (top of the body mesh to the feet).
func height_px() -> float:
	var top := 0.0
	for n in pivot.get_children():
		if n is Polygon2D and n.name == "part_body":
			for v in n.polygon:
				top = minf(top, v.y)
	return -top * px_scale


func clip_progress() -> float:
	if not player.is_playing() and player.current_animation == "":
		return 1.0
	return player.current_animation_position / maxf(player.current_animation_length, 0.001)


func _process(delta: float) -> void:
	if player == null:
		return
	# un-keyed bones relax toward rest so blends never leave stale angles
	for bname in bones:
		if _springs.has(bname):
			continue
		var b: Bone2D = bones[bname]
		b.rotation = lerp_angle(b.rotation, 0.0, minf(1.0, delta * 8.0))
	bones["root"].position = bones["root"].position.lerp(rest_pos["root"], minf(1.0, delta * 8.0))
	player.advance(delta * speed_scale)
	_update_springs(delta)
	pivot.scale = Vector2(px_scale * facing * squash.x, px_scale * squash.y)
	pivot.rotation = deg_to_rad(lean) * facing
	pivot.position = Vector2(nudge.x * facing, nudge.y - bob)
	nudge = nudge.lerp(Vector2.ZERO, minf(1.0, delta * 10.0))
	flash = maxf(0.0, flash - delta * 6.0)
	_mat.set_shader_parameter("flash", flash)
	_mat.set_shader_parameter("tint", tint)
	_mat.set_shader_parameter("dissolve", dissolve)
	_mat.set_shader_parameter("alpha_mul", alpha)


func _update_springs(delta: float) -> void:
	if delta <= 0.0:
		return
	for bname in _springs:
		var b: Bone2D = bones[bname]
		# head velocity expressed in the rig's own (unflipped) frame
		var head := pivot.global_transform.affine_inverse() * b.global_position
		var vel: Vector2 = (head - _last_head.get(bname, head)) / delta
		_last_head[bname] = head
		var cfg: Array = SPRING_BONES[bname]
		var st: Array = _springs[bname]
		# cloth trails opposite to motion (forward motion = +x in rig space)
		var target := clampf(vel.x * 0.0011 * cfg[0] - vel.y * 0.0005 * cfg[0], -1.1, 1.1)
		var acc: float = cfg[1] * (target - st[0]) - cfg[2] * st[1]
		st[1] += acc * delta
		st[0] += st[1] * delta
		b.rotation = st[0]
