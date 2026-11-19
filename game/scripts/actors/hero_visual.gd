extends RigVisual
## A planted boot stays on the floor while the pelvis travels over it. Solve
## the two existing leg bones after the gait keys so cloth, sword and arms keep
## their authored animation. Physics and combat still use the actor foot origin.

const SOLES := {"b": Vector2(-13, 76), "f": Vector2(9, 75)}
# Boot centres in game pixels, measured on the painted frames relative to the
# same ground origin as the rig. Used only to place contact shadows.
const PAINTED_FEET := {
	"hero_02_draw": Vector2(-46, 65), "hero_slash_pass": Vector2(-60, 65),
	"hero_03_hslash": Vector2(-48, 68), "hero_04_downslash": Vector2(-40, 70),
	"hero_05_thrust": Vector2(-46, 79), "hero_overhead_load": Vector2(-45, 70),
	"hero_thrust_load": Vector2(-46, 74), "hero_strike_settle": Vector2(-45, 68),
}
var on_ground := true
var contacts := [Vector2.ZERO, Vector2.ZERO]
var _planted_x := {}
var _last_gait := ""
var _last_facing := 1


func _ready() -> void:
	super._ready()
	cut.set_process(false)
	# The painter supplied a variable brush edge. Keep the post outline narrow
	# enough to pick out the figure in shadow, with no external paper halo.
	for sprite in [cur, prev]:
		var ink: ShaderMaterial = sprite.material
		ink.set_shader_parameter("outline_px", 1.1)
		ink.set_shader_parameter("outline_color", Color(0.16, 0.12, 0.11, 0.36))
		ink.set_shader_parameter("halo_px", 0.0)
	var ink_rig: ShaderMaterial = cut.material
	ink_rig.set_shader_parameter("outline_px", 0.6)
	ink_rig.set_shader_parameter("outline_color", Color(0.16, 0.12, 0.11, 0.36))
	ink_rig.set_shader_parameter("halo_color", Color.TRANSPARENT)


func set_pose(name_: String, _fade := 0.0) -> void:
	# In-betweens carry the turn. Two translucent whole bodies create double
	# heads and duplicate sword blades at the transition to a contact drawing.
	super.set_pose(name_, 0.0)
	_fade = 0.0
	prev.visible = false


func _process(delta: float) -> void:
	_w = 1.0 if rig_on else 0.0
	super._process(delta)
	cut._process(delta)
	if not rig_on:
		_planted_x.clear()
		var feet: Vector2 = PAINTED_FEET.get(pose, Vector2(-21, 23))
		contacts[0] = Vector2(feet.x * facing, 0)
		contacts[1] = Vector2(feet.y * facing, 0)
		return
	var gait := cut.current
	if gait != _last_gait or facing != _last_facing:
		_planted_x.clear()
	_last_gait = gait
	_last_facing = facing
	var phase := cut.clip_progress()
	for index in 2:
		var side := "b" if index == 0 else "f"
		var shin: Bone2D = cut.bones["shin_" + side]
		if on_ground:
			match gait:
				"run", "walk":
					var t := fposmod(phase + (0.5 if index == 0 else 0.0), 1.0)
					_support_step(side, t, 0.42 if gait == "run" else 0.5)
				"idle", "land":
					_set_sole(side, to_global(Vector2((-23.0 if index == 0 else 24.0) * facing, 0.0)), 1.0)
		else:
			_planted_x.erase(side)
		contacts[index] = to_local(shin.to_global(SOLES[side]))


func _support_step(side: String, phase: float, stance: float) -> void:
	if phase >= stance:
		_planted_x.erase(side)
		return
	var thigh: Bone2D = cut.bones["thigh_" + side]
	if not _planted_x.has(side):
		var period := cut.player.current_animation_length / maxf(cut.speed_scale, 0.01)
		_planted_x[side] = thigh.global_position.x + facing * locomotion_speed * period * (stance * 0.5 - phase)
	var target := Vector2(_planted_x[side], global_position.y)
	var weight := smoothstep(0.0, 0.045, phase) * (1.0 - smoothstep(stance - 0.045, stance, phase))
	_set_sole(side, target, weight)


func _set_sole(side: String, target: Vector2, weight: float) -> void:
	var thigh: Bone2D = cut.bones["thigh_" + side]
	var shin: Bone2D = cut.bones["shin_" + side]
	var leg: Vector2 = thigh.get_parent().to_local(target) - thigh.position
	var upper := shin.position.length()
	var lower: float = SOLES[side].length()
	# At the end of stance the planted shin is nearly straight. Let the pelvis
	# settle the last few pixels so the full sole can meet the painted surface.
	var reach := upper + lower - 0.05
	var reach_y := sqrt(maxf(reach * reach - leg.x * leg.x, 0.0))
	var settle := clampf(leg.y - reach_y, 0.0, 14.0) * weight
	cut.bones["root"].position.y += settle
	leg.y -= settle
	var distance := clampf(leg.length(), absf(upper - lower) + 0.01, upper + lower - 0.01)
	var bend := acos(clampf((upper * upper + distance * distance - lower * lower) / (2.0 * upper * distance), -1.0, 1.0))
	var aim := leg.angle() - bend - shin.position.angle()
	thigh.rotation = lerp_angle(thigh.rotation, aim, weight)
	var to_sole := thigh.to_local(target) - shin.position
	shin.rotation = lerp_angle(shin.rotation, to_sole.angle() - SOLES[side].angle(), weight)
