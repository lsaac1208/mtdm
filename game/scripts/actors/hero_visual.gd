class_name HeroVisual
extends PoseSprite
## Hero renderer: a skinned cut-out rig (CutoutRig, Skeleton2D + Polygon2D) for
## locomotion, reactions and attack anticipation/recovery, crossfaded with the
## painted concept-art action poses (PoseSprite) used as attack contact frames.

var cut: CutoutRig
var rig_on := false
var _w := 0.0          # 0 = painted pose, 1 = rig


func _ready() -> void:
	cut = CutoutRig.new()
	cut.name = "Cutout"
	add_child(cut)
	cut.setup("res://assets/rig/hero", HeroClips.clips())


## Switch to (or stay on) the rig and play `clip`.
func play_clip(clip: String, blend := 0.1, restart := false) -> void:
	if not rig_on:
		rig_on = true
		pose = ""   # next set_pose re-applies the painted pose
	cut.play(clip, blend, restart)


func set_pose(name_: String, fade := 0.06) -> void:
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
