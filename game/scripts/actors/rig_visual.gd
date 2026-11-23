class_name RigVisual
extends PoseSprite
## Unified volumetric character renderer:
##  1. Hand-painted frame-by-frame animation (`FrameAnim`) with paired 2.5D
##     normal/thickness/crevice-AO maps for locomotion, airborne arcs, idle,
##     and core enemy cycles — zero split cutout seams or paper-doll limbs.
##  2. Painted concept-art combat key poses (`PoseSprite`) shaded by the same
##     2.5D lighting shader for snappy sword strikes and heavy telegraphs.
##  3. Fallback `CutoutRig` only for auxiliary clips that lack frame sheets.

var rig_dir := "res://assets/rig/hero"
var anim_dir := ""
var clip_set: Dictionary = {}
var pose_map: Dictionary = {}
var locomotion_speed := 0.0   # set by the owner each frame (px/s)
var walk_speed := 100.0       # speed at which the walk clip plays at 1x
var clip_speed_scale := 1.0
var cut: CutoutRig
var frames: FrameAnim
var rig_on := false
var frame_on := false
var _w := 0.0          # 0 = painted pose, 1 = rig/frame-anim
## Procedural life on held painted frames (enemies): see FrameAnim.hold_life.
var hold_life := false


func _ready() -> void:
	if anim_dir == "":
		anim_dir = rig_dir.replace("/rig/", "/anims/")
	frames = FrameAnim.new()
	frames.name = "FrameAnim"
	add_child(frames)
	if not frames.setup(anim_dir):
		frames.queue_free()
		frames = null
	cut = CutoutRig.new()
	cut.name = "Cutout"
	add_child(cut)
	cut.setup(rig_dir, clip_set if not clip_set.is_empty() else HeroClips.clips())


func has_frame_clip(clip: String) -> bool:
	return frames != null and frames.has_clip(clip)


## Play `clip` on FrameAnim when available, otherwise fall back to CutoutRig.
func play_clip(clip: String, blend := 0.1, restart := false) -> void:
	if not rig_on:
		rig_on = true
		pose = ""   # next set_pose re-applies the painted pose
	if has_frame_clip(clip):
		frame_on = true
		frames.sync_facing(facing)
		frames.play(clip, restart)
		cut.current = ""
		return
	frame_on = false
	if frames != null:
		frames.current = ""
	cut.play(clip, blend, restart)


## Display a phase-locked frame of a FrameAnim clip (sword combos, dash, skills).
func play_frame(clip: String, idx: int) -> bool:
	if not has_frame_clip(clip):
		return false
	if not rig_on:
		rig_on = true
		pose = ""
	frame_on = true
	cut.current = ""
	frames.sync_facing(facing)
	return frames.set_frame(clip, idx)


func set_pose(name_: String, fade := 0.06) -> void:
	if pose_map.has(name_):
		var c: String = pose_map[name_]
		if c == "walk" and locomotion_speed < 6.0 and (has_frame_clip("idle") or cut.player.has_animation("idle")):
			c = "idle"
		play_clip(c, maxf(fade, 0.08), not rig_on or current_clip() != c)
		return
	if rig_on:
		if frame_on:
			_w = 0.0
		rig_on = false
		frame_on = false
		cut.current = ""
		if frames != null:
			frames.current = ""
	super.set_pose(name_, fade)


func current_clip() -> String:
	if frame_on and frames != null:
		return frames.current
	return cut.current


func clip_progress() -> float:
	if frame_on and frames != null:
		return frames.clip_progress()
	return cut.clip_progress()


func active_sprite() -> Sprite2D:
	if rig_on and frame_on and frames != null and frames.sprite.texture != null:
		return frames.sprite
	return cur


func boot_contacts() -> Array:
	if rig_on and frame_on and frames != null:
		var md := frames.current_frame_meta()
		var bs: Array = md.get("boots", [])
		if bs.size() >= 2:
			return [
				Vector2(float(bs[0][0]) * facing * extra_scale, float(bs[0][1]) * extra_scale),
				Vector2(float(bs[1][0]) * facing * extra_scale, float(bs[1][1]) * extra_scale),
			]
	return []


func visual_center() -> Vector2:
	if _w > 0.5 or pose == "":
		if frame_on and frames != null:
			return frames.visual_center()
		return cut.bones["spine"].global_position
	var md := PoseSprite.meta(pose)
	return cur.global_transform * Vector2(md.foot_x, md.foot_y - md.body_h * 0.5)


func _process(delta: float) -> void:
	if frame_on:
		_w = 1.0 if rig_on else 0.0
	else:
		_w = move_toward(_w, 1.0 if rig_on else 0.0, delta / 0.035)
	painted_mul = 1.0 - _w
	super._process(delta)
	cur.visible = _w < 0.999 and cur.texture != null
	var use_frames := rig_on and frame_on and frames != null
	var use_cut := _w > 0.001 and not use_frames
	if frames != null:
		frames.visible = use_frames
	cut.visible = use_cut

	var spd := clip_speed_scale
	var cname := current_clip()
	if cname == "walk":
		spd = clampf(locomotion_speed / maxf(walk_speed, 1.0), 0.45, 1.65)
	elif cname != "run":
		spd = 1.0

	if use_frames:
		frames.speed_scale = spd
		frames.facing = facing
		frames.lean = lean
		frames.squash = squash
		frames.bob = bob
		frames.nudge = Vector2(nudge.x + _jit_off.x * facing, nudge.y + _jit_off.y)
		frames.extra_scale = extra_scale
		frames.breathe = 0.006 if cname in ["idle", "guard_idle"] else 0.0
		frames.hold_life = hold_life
		frames.flash = flash
		frames.tint = tint
		frames.dissolve = dissolve
		frames.alpha = alpha * _w
		frames.air_height = air_height
		frames.step_anim(delta, current_light())
	if use_cut:
		cut.speed_scale = spd
		cut.facing = facing
		cut.lean = lean
		cut.squash = squash
		cut.bob = bob
		cut.nudge = Vector2(nudge.x + _jit_off.x * facing, nudge.y + _jit_off.y)
		cut.flash = flash
		cut.tint = tint
		cut.dissolve = dissolve
		cut.alpha = alpha * _w
		cut.apply_light(current_light())


func pose_height() -> float:
	if rig_on or pose == "":
		if frame_on and frames != null:
			return frames.height_px() * extra_scale
		return cut.height_px() * extra_scale
	return super.pose_height() * extra_scale
