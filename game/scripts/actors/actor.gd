class_name Actor
extends CharacterBody2D
## Shared body for the player and enemies: feet-origin hurtbox, health,
## poise, gravity, facing, and the strike helper that converts forward-facing
## local attack rects into world rects.

const GRAVITY := 2100.0

@export var team := 1
@export var max_hp := 30.0
@export var max_poise := 10.0
var hp := 30.0
var poise := 10.0
var hurt_size := Vector2(46, 124)
var dead := false
var facing := 1
var vis: PoseSprite
var state := "idle"
var state_t := 0.0
var invuln := 0.0
var knock_v := 0.0
var shadow_w := 50.0
var gravity_scale := 1.0
var _was_on_floor := true


func _ready() -> void:
	hp = max_hp
	poise = max_poise
	collision_layer = 2 if team == Combat.TEAM_PLAYER else 4
	collision_mask = 1
	floor_snap_length = 8.0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(minf(hurt_size.x, 40.0), minf(hurt_size.y, 120.0))
	cs.shape = shape
	cs.position = Vector2(0, -shape.size.y / 2.0)
	add_child(cs)
	vis = _make_visual()
	add_child(vis)
	Combat.register(self)
	z_index = 5


func _exit_tree() -> void:
	Combat.unregister(self)


func _make_visual() -> PoseSprite:
	return PoseSprite.new()


func get_hurtbox() -> Rect2:
	return Rect2(global_position.x - hurt_size.x / 2.0, global_position.y - hurt_size.y, hurt_size.x, hurt_size.y)


func is_hittable() -> bool:
	return not dead and invuln <= 0.0


func set_state(s: String) -> void:
	state = s
	state_t = 0.0


func local_rect(r: Rect2) -> Rect2:
	var p := global_position
	if facing >= 0:
		return Rect2(p.x + r.position.x, p.y + r.position.y, r.size.x, r.size.y)
	return Rect2(p.x - r.position.x - r.size.x, p.y + r.position.y, r.size.x, r.size.y)


func strike(r: Rect2, dmg: float, poise_dmg: float, knock: float, hit_set: Dictionary, extra := {}) -> Array:
	var atk := {
		"owner": self, "team": team, "rect": local_rect(r), "damage": dmg,
		"poise": poise_dmg, "knock": knock, "dir": facing, "kind": "melee",
		"unblockable": false, "tag": "",
	}
	atk.merge(extra, true)
	return Combat.strike(atk, hit_set)


func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * gravity_scale * delta, 1400.0)


func face_toward(x: float) -> void:
	if absf(x - global_position.x) > 2.0:
		facing = 1 if x > global_position.x else -1


func _draw() -> void:
	# soft ink blob shadow at the feet (hidden while airborne)
	if dead and vis.dissolve > 0.6:
		return
	var a := 0.32 if is_on_floor() else 0.12
	var pts := PackedVector2Array()
	for i in 20:
		var ang := TAU * i / 20.0
		pts.append(Vector2(cos(ang) * shadow_w * 0.5, sin(ang) * 6.0 - 1.0))
	draw_colored_polygon(pts, Color(0.05, 0.04, 0.03, a))


func _physics_process(_delta: float) -> void:
	queue_redraw()
