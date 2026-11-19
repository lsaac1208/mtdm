class_name RigVisual
extends PoseSprite
## Character renderer: a skinned cut-out rig (CutoutRig, Skeleton2D + Polygon2D)
## for locomotion, reactions and attack anticipation/recovery, crossfaded with
## the painted concept-art action poses (PoseSprite) used as contact frames.
## `pose_map` routes painted pose names to rig clips, so AI code that calls
## set_pose("grunt_walk") plays the rig's "walk" clip instead.

var rig_dir := "res://assets/rig/hero"
var clip_set: Dictionary = {}
var pose_map: Dictionary = {}
var locomotion_speed := 0.0   # set by the owner each frame (px/s)
var walk_speed := 100.0       # speed at which the walk clip plays at 1x
var cut: CutoutRig
var rig_on := false
var _w := 0.0          # 0 = painted pose, 1 = rig


func _ready() -> void:
	cut = CutoutRig.new()
	cut.name = "Cutout"
	add_child(cut)
	cut.setup(rig_dir, clip_set if not clip_set.is_empty() else HeroClips.clips())


## Switch to (or stay on) the rig and play `clip`.
func play_clip(clip: String, blend := 0.1, restart := false) -> void:
	if not rig_on:
		rig_on = true
		pose = ""   # next set_pose re-applies the painted pose
	cut.play(clip, blend, restart)


func set_pose(name_: String, fade := 0.06) -> void:
	if pose_map.has(name_):
		var c: String = pose_map[name_]
		if c == "walk" and locomotion_speed < 6.0 and cut.player.has_animation("idle"):
			c = "idle"
		play_clip(c, maxf(fade, 0.08), not rig_on or cut.current != c)
		return
	if rig_on:
		rig_on = false
		cut.current = ""
	super.set_pose(name_, fade)


func visual_center() -> Vector2:
	if _w > 0.5 or pose == "":
		return cut.bones["spine"].global_position
	var md := PoseSprite.meta(pose)
	return cur.global_transform * Vector2(md.foot_x, md.foot_y - md.body_h * 0.5)


func _process(delta: float) -> void:
	_w = move_toward(_w, 1.0 if rig_on else 0.0, delta / 0.035)
	painted_mul = 1.0 - _w
	super._process(delta)
	cur.visible = _w < 0.999 and cur.texture != null
	cut.visible = _w > 0.001
	if cut.current == "walk":
		cut.speed_scale = clampf(locomotion_speed / walk_speed, 0.35, 1.6)
	elif cut.current != "run":
		cut.speed_scale = 1.0
	cut.facing = facing
	cut.lean = lean
	cut.squash = squash
	cut.bob = bob
	cut.nudge = nudge
	cut.flash = flash
	cut.tint = tint
	cut.dissolve = dissolve
	cut.alpha = alpha * _w


func pose_height() -> float:
	if rig_on or pose == "":
		return cut.height_px()
	return super.pose_height()
