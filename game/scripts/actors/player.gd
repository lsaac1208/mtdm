class_name Player
extends Actor
## The Taoist Wanderer (道行者). Spec: docs/02_PROTAGONIST_SPEC.md and
## docs/05 §2.1 (150 px tall, hurtbox 44x138, run 260 px/s, dash 520 px/s).
##
## Pose map (concept sheet 02):
##  01 ready  idle/run      02 draw   combo start     03 hslash combo-1
##  04 down   combo-2/S+J   05 thrust combo-3         06 dash   dash/dash-slash
##  07 jump   air/jump-atk  08 talisman               09 gourd
##  10a/b beads charge/burst 11 defense block/parry   12 hit    13 recovery/land

signal hp_changed(hp, max_hp)
signal qi_changed(qi, max_qi)
signal gourd_changed(charges)
signal died

const RUN_SPEED := 260.0
const DASH_SPEED := 540.0
const JUMP_V := -760.0
const MAX_QI := 100.0
const PARRY_WINDOW := 0.17
const COYOTE := 0.1
const BUFFER := 0.16
const TALISMAN_COST := 20.0
const BEADS_COST := 50.0
const GOURD_MAX := 3

# Attack table. rect = Rect2(forward x, y above feet (negative), w, h).
const ATK := {
	"slash1": {"pre": "hero_02_draw", "pose": "hero_03_hslash", "startup": 0.07, "active": 0.09,
		"recover": 0.22, "rect": Rect2(0, -145, 118, 90), "dmg": 10.0, "poise": 8.0, "knock": 170.0,
		"lunge": 170.0, "next": "slash2", "fx": [-70.0, 55.0, 88.0, 34.0, 0.6], "fx_off": Vector2(10, -96),
		"lean": 6.0, "arm": [-0.55, 0.3, 0.0, 0.0]},
	"slash2": {"pre": "hero_04_downslash", "pose": "hero_04_downslash", "startup": 0.12, "active": 0.09,
		"recover": 0.26, "rect": Rect2(4, -160, 104, 160), "dmg": 14.0, "poise": 16.0, "knock": 120.0,
		"lunge": 120.0, "next": "slash3", "fx": [-120.0, 80.0, 86.0, 38.0, 1.0], "fx_off": Vector2(24, -80),
		"lean": 10.0, "low": true, "arm": [-0.25, 0.85, 0.0, 0.0]},
	"slash3": {"pre": "hero_02_draw", "pose": "hero_05_thrust", "startup": 0.11, "active": 0.1,
		"recover": 0.32, "rect": Rect2(10, -132, 160, 62), "dmg": 17.0, "poise": 20.0, "knock": 300.0,
		"lunge": 360.0, "next": "", "fx": [-80.0, 80.0, 120.0, 22.0, 0.14], "fx_off": Vector2(60, -100),
		"lean": 4.0, "arm": [0.0, 0.0, -0.09, 0.03]},
	"down": {"pre": "hero_04_downslash", "pose": "hero_04_downslash", "startup": 0.14, "active": 0.1,
		"recover": 0.28, "rect": Rect2(4, -160, 106, 160), "dmg": 16.0, "poise": 20.0, "knock": 140.0,
		"lunge": 90.0, "next": "slash3", "fx": [-120.0, 85.0, 88.0, 40.0, 1.0], "fx_off": Vector2(24, -80),
		"lean": 12.0, "low": true, "arm": [-0.3, 0.9, 0.0, 0.0]},
}

var qi := 40.0
var gourd := GOURD_MAX
var coyote := 0.0
var jump_buf := 0.0
var atk_buf := 0.0
var atk_buf_down := false
var dash_cd := 0.0
var air_dash := true
var air_attack := true
var block_t := 0.0
var cur_atk := {}
var cur_atk_name := ""
var hit_set := {}
var combo_queued := ""
var in_taint := 0.0
var skill_cd := 0.0
var controls_locked := false
var _ghost_t := 0.0
var _step_t := 0.0
var _fall_peak := 0.0
var _hit_stun := 0.35
var _arm := [0.0, 0.0, 0.0]
var _block_recoil := 0.0   # sword-arm rot, back-arm rot, sword-arm offset along x (uv)
var input_override = null   # test harness: Dictionary of action -> bool


func _init() -> void:
	team = Combat.TEAM_PLAYER
	max_hp = 100.0
	max_poise = 999.0
	hurt_size = Vector2(44, 138)
	shadow_w = 58.0


func _make_visual() -> PoseSprite:
	return RigVisual.new()


const WINDUP_CLIP := {"slash1": "windup_slash", "slash2": "windup_over", "down": "windup_over", "slash3": "windup_thrust"}
var _last_clip_pos := 0.0


func _ready() -> void:
	super._ready()
	vis.set_pose("hero_01_ready", 0.0)
	vis.play_clip.call_deferred("idle", 0.0)
	vis.sway = 0.005
	Game.player = self


# ---------------------------------------------------------------- input
func _pressed(a: String) -> bool:
	if controls_locked:
		return false
	if input_override != null:
		return input_override.get(a + "_just", false)
	return Input.is_action_just_pressed(a)


func _held(a: String) -> bool:
	if controls_locked:
		return false
	if input_override != null:
		return input_override.get(a, false)
	return Input.is_action_pressed(a)


func _axis() -> float:
	return float(_held("move_right")) - float(_held("move_left"))


# ---------------------------------------------------------------- main loop
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	state_t += delta
	invuln = maxf(0.0, invuln - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	skill_cd = maxf(0.0, skill_cd - delta)
	jump_buf = maxf(0.0, jump_buf - delta)
	atk_buf = maxf(0.0, atk_buf - delta)
	in_taint = maxf(0.0, in_taint - delta)
	if dead:
		velocity.x = move_toward(velocity.x, 0, 1200 * delta)
		apply_gravity(delta)
		move_and_slide()
		return
	_gain_qi(1.2 * delta)
	if _pressed("jump"):
		jump_buf = BUFFER
	if _pressed("attack"):
		atk_buf = BUFFER
		atk_buf_down = _held("move_down")
	if is_on_floor():
		coyote = COYOTE
		air_dash = true
		air_attack = true
	else:
		coyote = maxf(0.0, coyote - delta)

	match state:
		"idle", "run":
			_st_ground(delta)
		"air":
			_st_air(delta)
		"attack":
			_st_attack(delta)
		"dash":
			_st_dash(delta)
		"dash_attack":
			_st_dash_attack(delta)
		"jump_attack":
			_st_jump_attack(delta)
		"block":
			_st_block(delta)
		"hit":
			_st_hit(delta)
		"land":
			_st_land(delta)
		"talisman", "gourd", "beads_a", "beads_b":
			_st_skill(delta)
	apply_gravity(delta)
	if knock_v != 0.0:
		velocity.x += knock_v
		knock_v = 0.0
	var was_air := not is_on_floor()
	var vy := velocity.y
	move_and_slide()
	if was_air and is_on_floor():
		_on_landed(vy)
	_animate(delta)
	if input_override != null:
		# test harness one-shot presses are consumed by exactly one physics step
		for k in input_override.keys():
			if String(k).ends_with("_just"):
				input_override.erase(k)


func _speed_mul() -> float:
	return 0.7 if in_taint > 0.0 else 1.0


# Shared: what a free (actionable) character can start from the ground.
func _try_actions() -> bool:
	if _pressed("talisman") and qi >= TALISMAN_COST and skill_cd <= 0.0:
		_start_skill("talisman")
		return true
	if _pressed("gourd") and gourd > 0 and skill_cd <= 0.0:
		_start_skill("gourd")
		return true
	if _pressed("beads") and qi >= BEADS_COST and skill_cd <= 0.0:
		_start_skill("beads_a")
		return true
	if _pressed("dash") and dash_cd <= 0.0:
		_start_dash()
		return true
	if atk_buf > 0.0:
		atk_buf = 0.0
		if not is_on_floor():
			if air_attack:
				_start_jump_attack()
				return true
			return false
		_start_attack("down" if atk_buf_down else "slash1")
		return true
	if _held("block") and is_on_floor():
		set_state("block")
		block_t = 0.0
		Sfx.play("guard_up", -8.0)
		return true
	return false


func _st_ground(delta: float) -> void:
	var ax := _axis()
	velocity.x = move_toward(velocity.x, ax * RUN_SPEED * _speed_mul(), 2600.0 * delta)
	if ax != 0.0:
		facing = int(signf(ax))
	if jump_buf > 0.0 and coyote > 0.0:
		_jump()
		return
	if not is_on_floor() and coyote <= 0.0:
		set_state("air")
		return
	if _try_actions():
		return
	var want := "run" if absf(ax) > 0.0 else "idle"
	if state != want:
		set_state(want)


func _jump() -> void:
	velocity.y = JUMP_V
	jump_buf = 0.0
	coyote = 0.0
	set_state("air")
	_fall_peak = global_position.y
	Sfx.play("jump", -6.0)
	Fx.dust(global_position, 6)


func _st_air(delta: float) -> void:
	var ax := _axis()
	velocity.x = move_toward(velocity.x, ax * RUN_SPEED * _speed_mul(), 1800.0 * delta)
	if ax != 0.0:
		facing = int(signf(ax))
	if jump_buf > 0.0 and coyote > 0.0:
		_jump()
		return
	# variable jump height
	if velocity.y < -200.0 and not _held("jump"):
		velocity.y = move_toward(velocity.y, -200.0, 5200.0 * delta)
	_fall_peak = minf(_fall_peak, global_position.y)
	_try_actions()


func _on_landed(vy: float) -> void:
	Fx.dust(global_position, 5 if vy < 700 else 10)
	Sfx.play("land", -10.0 if vy < 700 else -4.0)
	if state == "air":
		if vy > 820.0:
			set_state("land")
			vis.squash = Vector2(1.12, 0.86)
		else:
			set_state("idle")
			vis.squash = Vector2(1.06, 0.94)
	elif state == "jump_attack":
		set_state("land")
		Fx.shake(3.0, 0.1)


func _st_land(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 2400.0 * delta)
	if state_t > 0.14:
		set_state("idle")
	elif state_t > 0.06:
		_try_actions()


# ---------------------------------------------------------------- melee
func _start_attack(name_: String) -> void:
	_arm = [0.0, 0.0, 0.0]
	cur_atk_name = name_
	cur_atk = ATK[name_]
	hit_set = {}
	combo_queued = ""
	set_state("attack")
	var ax := _axis()
	if ax != 0.0:
		facing = int(signf(ax))
	vis.play_clip(WINDUP_CLIP.get(name_, "windup_slash"), 0.04, true)
	Sfx.play("swing_pre", -12.0)


func _st_attack(delta: float) -> void:
	var a := cur_atk
	var t := state_t
	var st: float = a.startup
	var ac: float = a.active
	var total: float = st + ac + a.recover
	if t < st + ac:
		var k := t / (st + ac)
		velocity.x = facing * a.lunge * (1.0 - k) * _speed_mul()
	else:
		velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
	if t >= st and vis.pose != a.pose:
		vis.set_pose(a.pose, 0.03)
		var f: Array = a.fx
		Fx.slash(global_position + Vector2(a.fx_off.x * facing, a.fx_off.y), facing, f[0], f[1], f[2], f[3], 0.3,
			Fx.C_CINNABAR, Color(1, 0.97, 0.9), f[4])
		Sfx.play("swing", -4.0)
		vis.squash = Vector2(1.06, 0.95)
		_smear(2, 0.3)
	var ac_curve: Array = a.get("arm", [0.0, 0.0, 0.0, 0.0])
	if t >= st:
		# active pose: wind-up angle -> strike angle (fast ease-out), then settle in recovery
		var k := clampf((t - st) / maxf(ac * 1.3, 0.01), 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3.0)
		var settle := clampf((t - st - ac) / maxf(a.recover, 0.01), 0.0, 1.0)
		_arm[0] = lerpf(lerpf(ac_curve[0], ac_curve[1], e), ac_curve[1] * 0.6, settle)
		_arm[2] = lerpf(lerpf(ac_curve[2], ac_curve[3], e), 0.0, settle)
	if t >= st and t < st + ac:
		var hits := strike(a.rect, a.dmg, a.poise, a.knock, hit_set, {"tag": cur_atk_name, "low": a.get("low", false)})
		if hits.size() > 0:
			_on_melee_connect(hits)
	# combo input window opens during active frames
	if t >= st * 0.5 and atk_buf > 0.0 and a.next != "":
		combo_queued = a.next
		atk_buf = 0.0
	var can_cancel := t >= st + ac + 0.06
	if can_cancel and combo_queued != "":
		_start_attack(combo_queued)
		return
	if can_cancel and _pressed("dash") and dash_cd <= 0.0:
		_start_dash()
		return
	if can_cancel and _held("block") and t >= st + ac + 0.1:
		set_state("block")
		block_t = 0.0
		return
	if t >= st + ac + a.recover * 0.5 and not vis.rig_on:
		vis.play_clip("recover", 0.06, true)
	if t >= total:
		set_state("idle")


func _on_melee_connect(hits: Array) -> void:
	_gain_qi(5.0 * hits.size())
	Game.hitstop(0.055 if cur_atk_name != "slash3" else 0.08)
	Fx.shake(2.5 if cur_atk_name == "slash1" else 4.5, 0.12)


# ---------------------------------------------------------------- dash
func _start_dash() -> void:
	set_state("dash")
	var ax := _axis()
	if ax != 0.0:
		facing = int(signf(ax))
	dash_cd = 0.42
	invuln = 0.24
	if not is_on_floor():
		air_dash = false
	velocity.y = minf(velocity.y, 0.0) if not is_on_floor() else velocity.y
	vis.set_pose("hero_06_dash", 0.03)
	Sfx.play("dash", -6.0)
	Fx.dust(global_position + Vector2(-facing * 20, 0), 8, Vector2(-facing, -0.4))


func _st_dash(delta: float) -> void:
	var k := state_t / 0.22
	velocity.x = facing * lerpf(DASH_SPEED, RUN_SPEED * 0.6, k * k) * _speed_mul()
	if not is_on_floor():
		velocity.y = minf(velocity.y, 60.0)   # brief hang in the air
	_ghost_t -= delta
	if _ghost_t <= 0.0:
		_ghost_t = 0.035
		_spawn_ghost()
	if atk_buf > 0.0 and is_on_floor():
		atk_buf = 0.0
		_start_dash_attack()
		return
	if state_t >= 0.22:
		set_state("idle" if is_on_floor() else "air")
		# allow a dash-slash right as the dash ends
		if atk_buf > 0.0 and is_on_floor():
			atk_buf = 0.0
			_start_dash_attack()


func _start_dash_attack() -> void:
	set_state("dash_attack")
	hit_set = {}
	invuln = maxf(invuln, 0.16)
	vis.set_pose("hero_06_dash", 0.02)
	Sfx.play("swing", -3.0, 0.05, 0.9)
	Fx.slash(global_position + Vector2(30 * facing, -50), facing, -70.0, 70.0, 110.0, 26.0, 0.3,
		Fx.C_CINNABAR, Color(1, 0.97, 0.9), 0.25)


func _st_dash_attack(delta: float) -> void:
	velocity.x = facing * lerpf(620.0, 0.0, clampf(state_t / 0.34, 0, 1)) * _speed_mul()
	_ghost_t -= delta
	if _ghost_t <= 0.0 and state_t < 0.2:
		_ghost_t = 0.04
		_spawn_ghost()
	if state_t >= 0.03 and state_t < 0.22:
		var hits := strike(Rect2(-20, -95, 140, 95), 14.0, 16.0, 220.0, hit_set, {"tag": "dash_attack", "low": true})
		if hits.size() > 0:
			_gain_qi(5.0 * hits.size())
			Game.hitstop(0.06)
			Fx.shake(3.5, 0.12)
	if state_t >= 0.42:
		set_state("idle")


# ---------------------------------------------------------------- air attack
func _start_jump_attack() -> void:
	_arm = [-0.6, 0.0, 0.0]
	set_state("jump_attack")
	air_attack = false
	hit_set = {}
	vis.set_pose("hero_07_jump", 0.03)
	_smear(1, 0.3)
	Sfx.play("swing", -4.0, 0.06, 1.08)
	Fx.slash(global_position + Vector2(26 * facing, -70), facing, -80.0, 95.0, 88.0, 34.0, 0.3)


func _st_jump_attack(delta: float) -> void:
	var ax := _axis()
	velocity.x = move_toward(velocity.x, ax * RUN_SPEED * 0.8, 1200.0 * delta)
	_arm[0] = lerpf(-0.6, 0.75, 1.0 - pow(1.0 - clampf(state_t / 0.2, 0.0, 1.0), 3.0))
	if state_t >= 0.04 and state_t < 0.24:
		var hits := strike(Rect2(-10, -125, 128, 165), 13.0, 12.0, 160.0, hit_set, {"tag": "jump_attack", "low": true})
		if hits.size() > 0:
			_gain_qi(5.0 * hits.size())
			Game.hitstop(0.05)
			velocity.y = minf(velocity.y, -180.0)   # small pogo on hit
	if state_t >= 0.36:
		set_state("air")


# ---------------------------------------------------------------- guard
func _st_block(delta: float) -> void:
	block_t += delta
	velocity.x = move_toward(velocity.x, 0.0, 2400.0 * delta)
	vis.play_clip("block", 0.05)
	var ax := _axis()
	if ax != 0.0 and block_t < 0.05:
		facing = int(signf(ax))
	if not _held("block"):
		set_state("idle")
		return
	if _pressed("dash") and dash_cd <= 0.0:
		_start_dash()
	elif atk_buf > 0.0 and block_t > 0.12:
		atk_buf = 0.0
		_start_attack("slash3")   # guard-counter: thrust out of block


# ---------------------------------------------------------------- skills
func _start_skill(s: String) -> void:
	set_state(s)
	hit_set = {}
	velocity.x = 0.0
	match s:
		"talisman":
			qi -= TALISMAN_COST
			skill_cd = 0.3
			vis.set_pose("hero_08_talisman", 0.04)
			Sfx.play("talisman_draw", -6.0)
		"gourd":
			gourd -= 1
			gourd_changed.emit(gourd)
			skill_cd = 0.5
			vis.set_pose("hero_09_gourd", 0.05)
			Sfx.play("gourd_uncork", -4.0)
		"beads_a":
			qi -= BEADS_COST
			skill_cd = 0.8
			vis.set_pose("hero_10a_beads", 0.05)
			Sfx.play("beads_charge", -3.0)
			var r := Fx.ring(global_position + Vector2(0, -70), 90.0, 40.0, Fx.C_GOLD, 0.45, 6.0, 0.5)
			r.glyphs = 9
	qi_changed.emit(qi, MAX_QI)


func _st_skill(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 2400.0 * delta)
	match state:
		"talisman":
			if state_t >= 0.1 and hit_set.is_empty():
				hit_set["fired"] = true
				var p := preload("res://scripts/fx/talisman_projectile.gd").new()
				p.global_position = global_position + Vector2(46 * facing, -96)
				p.dir = facing
				p.owner_actor = self
				Fx.layer().add_child(p)
				Sfx.play("talisman_fire", -3.0)
			if state_t >= 0.32:
				set_state("idle" if is_on_floor() else "air")
		"gourd":
			if state_t >= 0.22 and hit_set.is_empty():
				hit_set["done"] = true
				hp = minf(max_hp, hp + 35.0)
				hp_changed.emit(hp, max_hp)
				Fx.float_text(global_position + Vector2(0, -170), "+35", Color(0.95, 0.85, 0.5))
				Fx.ring(global_position + Vector2(30 * facing, -80), 20.0, 170.0, Color(0.95, 0.75, 0.35, 0.9), 0.5, 14.0, 0.6)
				Fx.particles(global_position + Vector2(40 * facing, -90), 26, Color(0.9, 0.7, 0.3, 0.8), 380.0, 50.0, Vector2(facing, 0), 0.0, 0.5, 6.0)
				Sfx.play("gourd_gust", -2.0)
				var gust := {}
				var hits := Combat.strike({"owner": self, "team": team, "rect": Rect2(global_position.x - 170, global_position.y - 170, 340, 175),
					"damage": 4.0, "poise": 30.0, "knock": 520.0, "dir": facing, "kind": "aoe", "centre": global_position,
					"unblockable": false, "tag": "gourd"}, gust)
				if hits.size() > 0:
					Fx.shake(3.0, 0.15)
			if state_t >= 0.58:
				set_state("idle")
		"beads_a":
			if state_t >= 0.42:
				set_state("beads_b")
				vis.set_pose("hero_10b_beads", 0.03)
				Sfx.play("beads_burst", 0.0)
				var r := Fx.ring(global_position + Vector2(0, -40), 30.0, 230.0, Fx.C_GOLD, 0.6, 16.0, 0.45)
				r.glyphs = 18
				Fx.ring(global_position + Vector2(0, -40), 20.0, 190.0, Color(1, 0.95, 0.8, 0.8), 0.35, 6.0, 0.45)
				Fx.shake(6.0, 0.25)
				Fx.punch(0.04, 0.3)
				Game.hitstop(0.08)
				var hs := {}
				Combat.strike({"owner": self, "team": team, "rect": Rect2(global_position.x - 210, global_position.y - 210, 420, 230),
					"damage": 28.0, "poise": 60.0, "knock": 420.0, "dir": facing, "kind": "aoe", "centre": global_position,
					"unblockable": false, "tag": "beads"}, hs)
				get_tree().call_group("taint_puddle", "purify_near", global_position, 240.0)
		"beads_b":
			if state_t >= 0.4:
				set_state("idle")


# ---------------------------------------------------------------- damage
func is_hittable() -> bool:
	return not dead and invuln <= 0.0


var last_hit_source := ""


func _source(atk: Dictionary) -> String:
	var o = atk.get("owner")
	var who: String = o.enemy_name if is_instance_valid(o) and "enemy_name" in o else "hazard"
	var tag: String = atk.get("tag", "")
	if tag == "" and is_instance_valid(o) and "state" in o:
		tag = o.state
	return "%s:%s" % [who, tag]


func receive_hit(atk: Dictionary) -> Dictionary:
	last_hit_source = _source(atk)
	if atk.kind == "hazard":
		_take(atk.damage, true)
		return {}
	var from_x: float = global_position.x - atk.dir * 10.0
	if atk.kind == "projectile":
		from_x = atk.get("from_x", from_x)
	elif atk.has("centre"):
		from_x = atk.centre.x
	elif is_instance_valid(atk.get("owner")):
		from_x = atk.owner.global_position.x
	var from_front := (from_x - global_position.x) * facing >= 0.0
	if state == "block" and from_front and not atk.get("unblockable", false):
		if block_t <= PARRY_WINDOW:
			_parry(atk)
			return {"parried": true, "blocked": true}
		var heavy: bool = atk.get("heavy", false)
		var dmg: float = atk.damage * (0.45 if heavy else 0.15)
		_take(dmg, false)
		knock_v = -facing * (420.0 if heavy else 200.0)
		Sfx.play("block", -2.0)
		_block_recoil = -0.35 if heavy else -0.2
		Fx.spark(global_position + Vector2(30 * facing, -90), Fx.C_GOLD, 8)
		_gain_qi(2.0)
		if heavy:
			set_state("hit")
			_hit_stun = 0.45
			vis.play_clip("hit", 0.03, true)
		return {"blocked": true}
	if state in ["beads_a", "beads_b"]:
		# prayer-bead array grants super armour: take reduced damage, no stun
		_take(atk.damage * 0.5, true)
		return {}
	_take(atk.damage, true)
	if dead:
		return {}
	set_state("hit")
	_hit_stun = 0.32 if atk.damage < 20 else 0.48
	vis.play_clip("hit", 0.03, true)
	var dir := 1 if global_position.x >= from_x else -1
	facing = -dir
	knock_v = dir * atk.knock * 1.2
	velocity.x = 0.0
	if atk.damage >= 20:
		velocity.y = -260.0
	invuln = 0.75
	Game.hitstop(0.08)
	Fx.shake(6.0, 0.22)
	Fx.hit_ink(global_position + Vector2(0, -80), dir, Fx.C_CINNABAR)
	Sfx.play("player_hurt", -2.0)
	return {}


func _take(dmg: float, flash_: bool) -> void:
	Game.tel_damage(last_hit_source, minf(dmg, hp))
	if Game.level and Game.level.has_method("active_encounter_id"):
		var eid: String = Game.level.active_encounter_id()
		if eid != "":
			Game.tel_enc(eid, "damage", minf(dmg, hp))
	hp = maxf(0.0, hp - dmg)
	hp_changed.emit(hp, max_hp)
	if flash_:
		vis.flash = 0.45
	if hp <= 0.0 and not dead:
		_die()


func _parry(atk: Dictionary) -> void:
	Game.parries += 1
	_gain_qi(15.0)
	Sfx.play("parry", 0.0, 0.03)
	Fx.spark(global_position + Vector2(36 * facing, -96), Color(1, 0.95, 0.7), 22)
	Fx.ring(global_position + Vector2(36 * facing, -96), 6.0, 70.0, Color(1, 0.9, 0.6), 0.25, 5.0, 1.0)
	Fx.float_text(global_position + Vector2(0, -175), "弹反", Color(1, 0.88, 0.5), 30)
	Game.hitstop(0.16, 0.02)
	Fx.shake(4.0, 0.15)
	Fx.punch(0.05, 0.25)
	var o = atk.get("owner")
	if is_instance_valid(o) and o.has_method("on_parried"):
		o.on_parried()
	set_state("block")
	block_t = PARRY_WINDOW + 0.01


func _st_hit(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
	if state_t >= _hit_stun:
		set_state("idle" if is_on_floor() else "air")


func _die() -> void:
	Game.telemetry.deaths.append(last_hit_source)
	dead = true
	set_state("dead")
	vis.play_clip("dead", 0.08, true)
	Sfx.play("player_die", 0.0)
	Fx.shake(8.0, 0.3)
	Game.hitstop(0.2, 0.1)
	died.emit()


func respawn_at(pos: Vector2) -> void:
	dead = false
	global_position = pos
	velocity = Vector2.ZERO
	hp = max_hp
	qi = maxf(qi, 40.0)
	gourd = GOURD_MAX
	invuln = 1.0
	vis.alpha = 1.0
	vis.dissolve = 0.0
	set_state("idle")
	vis.play_clip("idle", 0.0, true)
	hp_changed.emit(hp, max_hp)
	qi_changed.emit(qi, MAX_QI)
	gourd_changed.emit(gourd)


func rest() -> void:
	hp = max_hp
	gourd = GOURD_MAX
	hp_changed.emit(hp, max_hp)
	gourd_changed.emit(gourd)


func _gain_qi(v: float) -> void:
	var old := qi
	qi = clampf(qi + v, 0.0, MAX_QI)
	if int(old) != int(qi):
		qi_changed.emit(qi, MAX_QI)


func on_kill(_enemy) -> void:
	_gain_qi(8.0)


# ---------------------------------------------------------------- visuals
## Motion smear: fading copies of the previous and current pose trailing the swing.
func _smear(n: int, alpha: float) -> void:
	for i in n:
		var src: Sprite2D = vis.prev if (i == 0 and vis.prev.visible) else vis.cur
		var g := Sprite2D.new()
		g.texture = src.texture
		g.centered = false
		g.global_transform = src.global_transform
		g.position += Vector2(-facing * 14.0 * (i + 1), 0)
		g.modulate = Color(1.0, 0.85, 0.7, alpha * (1.0 - i * 0.35))
		g.z_index = 4
		Fx.layer().add_child(g)
		var tw := g.create_tween()
		tw.tween_property(g, "modulate:a", 0.0, 0.14)
		tw.tween_callback(g.queue_free)


func _spawn_ghost() -> void:
	var g := Sprite2D.new()
	g.texture = vis.cur.texture
	g.centered = false
	g.global_transform = vis.cur.global_transform
	g.modulate = Color(0.95, 0.75, 0.35, 0.45)
	g.z_index = 4
	Fx.layer().add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.22)
	tw.tween_callback(g.queue_free)


func _animate(delta: float) -> void:
	vis.facing = facing
	vis.squash = vis.squash.lerp(Vector2.ONE, minf(1.0, delta * 12.0))
	var target_lean := 0.0
	vis.stride = 0.0
	vis.legs = 0.0
	vis.leg_lift = 0.0
	vis.tuck = 0.0
	vis.torso_twist = 0.0
	vis.ribbon = clampf(absf(velocity.x) / 260.0, 0.0, 1.5) * 0.005
	vis.bob = 0.0
	vis.breathe = 0.0
	vis.tint = Color(0.82, 1.0, 0.7) if in_taint > 0.0 else Color.WHITE
	vis.alpha = 0.7 if (invuln > 0.0 and state != "dash" and state != "dash_attack" and int(invuln * 20) % 2 == 0) else 1.0
	var cut: CutoutRig = vis.cut
	cut.speed_scale = 1.0
	match state:
		"idle":
			vis.play_clip("idle", 0.18)
		"run":
			var spd := absf(velocity.x)
			if spd < 170.0:
				vis.play_clip("walk", 0.15)
				cut.speed_scale = clampf(spd / 140.0, 0.4, 1.3)
			else:
				vis.play_clip("run", 0.12)
				cut.speed_scale = clampf(spd / 260.0, 0.6, 1.3)
			# footfalls at the two contact keys of the cycle
			var pos := cut.clip_progress()
			for contact in [0.1, 0.6]:
				if _last_clip_pos < contact and pos >= contact:
					Sfx.play("step", -18.0, 0.15)
					Fx.dust(global_position + Vector2(-10 * facing, 0), 2, Vector2(-facing, -0.5))
			_last_clip_pos = pos
		"air":
			vis.play_clip("jump" if velocity.y < 0.0 else "fall", 0.14)
			target_lean = clampf(velocity.y / 120.0, -4.0, 6.0)
		"land":
			vis.play_clip("land", 0.04, state_t < 0.02)
		"dead":
			vis.play_clip("dead", 0.08)
		"dash":
			vis.set_pose("hero_06_dash", 0.03)
		"attack":
			target_lean = cur_atk.get("lean", 0.0) if state_t >= cur_atk.startup else -2.0
		"hit":
			target_lean = -6.0
	# arms: attacks drive _arm; locomotion swings arms against the legs
	var ar0 := 0.0
	var ar1 := 0.0
	var aoff := 0.0
	match state:
		"attack", "jump_attack":
			ar0 = _arm[0]
			aoff = _arm[2]
		"talisman":
			# wind back, then snap the throwing arm forward at release (0.1 s)
			ar0 = lerpf(-0.7, 0.15, 1.0 - pow(1.0 - clampf((state_t - 0.04) / 0.1, 0.0, 1.0), 3.0))
		"gourd":
			ar0 = lerpf(0.35, -0.15, clampf((state_t - 0.12) / 0.14, 0.0, 1.0))
		"block":
			ar0 = _block_recoil
			_block_recoil = lerpf(_block_recoil, 0.0, minf(1.0, delta * 10.0))
		"run":
			ar0 = 0.2 * sin(_step_t)
			ar1 = -0.16 * sin(_step_t)
		"idle":
			var tt := Time.get_ticks_msec() / 1000.0
			ar0 = 0.03 * sin(tt * 2.2)
			ar1 = -0.025 * sin(tt * 2.2 + 0.7)
		"air":
			ar0 = -0.18
			ar1 = 0.12
	vis.arm_rot = [ar0, ar1]
	vis.arm_off = [Vector2(aoff, 0.0), Vector2.ZERO]
	vis.lean = lerpf(vis.lean, target_lean, minf(1.0, delta * 14.0))
	vis.sway = 0.012 if state in ["run", "dash", "dash_attack", "air", "jump_attack"] else 0.005
