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
signal combo_changed(count: int)
signal died

const RUN_SPEED := 260.0
const DASH_SPEED := 540.0
const JUMP_V := -760.0
const MAX_QI := 100.0
const PARRY_WINDOW := 0.17
const COYOTE := 0.1
const BUFFER := 0.20
const TALISMAN_COST := 20.0
const BEADS_COST := 50.0
const GOURD_MAX := 3
const COMBO_WINDOW := 2.6

# Attack table. rect = Rect2(forward x, y above feet (negative), w, h).
const ATK := {
	"slash1": {"pre": "hero_02_draw", "pose": "hero_03_hslash", "startup": 0.07, "active": 0.09,
		"recover": 0.22, "rect": Rect2(0, -145, 118, 90), "dmg": 10.0, "poise": 8.0, "knock": 170.0,
		"lunge": 170.0, "next": "slash2", "fx": [-70.0, 55.0, 88.0, 34.0, 0.6], "fx_off": Vector2(10, -96)},
	"slash2": {"pre": "hero_overhead_load", "pose": "hero_04_downslash", "startup": 0.12, "active": 0.09,
		"recover": 0.26, "rect": Rect2(4, -160, 104, 160), "dmg": 14.0, "poise": 16.0, "knock": 120.0,
		"lunge": 120.0, "next": "slash3", "fx": [-120.0, 80.0, 86.0, 38.0, 1.0], "fx_off": Vector2(24, -80), "low": true},
	"slash3": {"pre": "hero_thrust_load", "pose": "hero_05_thrust", "startup": 0.11, "active": 0.1,
		"recover": 0.32, "rect": Rect2(10, -132, 160, 62), "dmg": 17.0, "poise": 20.0, "knock": 300.0,
		"lunge": 360.0, "next": "", "fx": [-80.0, 80.0, 120.0, 22.0, 0.14], "fx_off": Vector2(60, -100)},
	"down": {"pre": "hero_overhead_load", "pose": "hero_04_downslash", "startup": 0.14, "active": 0.1,
		"recover": 0.28, "rect": Rect2(4, -160, 106, 160), "dmg": 16.0, "poise": 20.0, "knock": 140.0,
		"lunge": 90.0, "next": "slash3", "fx": [-120.0, 85.0, 88.0, 40.0, 1.0], "fx_off": Vector2(24, -80), "low": true},
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
var _swing_started := false
var _floor_probe := RayCast2D.new()
var hit_set := {}
var combo_queued := ""
var in_taint := 0.0
var skill_cd := 0.0
var controls_locked := false
var _ghost_t := 0.0
var _step_t := 0.0
var _fall_peak := 0.0
var _prev_ax := 0.0
var _skid_cd := 0.0
var _talisman_projs: Array = []
var _hit_stun := 0.35
var _jump_arm := 0.0
var _block_recoil := 0.0   # sword-arm rot, back-arm rot, sword-arm offset along x (uv)
var combo_hits := 0
var combo_timer := 0.0
var input_override = null   # test harness: Dictionary of action -> bool
## Press buffer for dash and skills: an early press (during an attack's active
## frames, landing, hit-stun tail…) is honoured as soon as the hero can act.
const ACT_BUFFER := 0.18
var _act_buf := {"dash": 0.0, "talisman": 0.0, "gourd": 0.0, "beads": 0.0}


func _init() -> void:
	team = Combat.TEAM_PLAYER
	max_hp = 100.0
	max_poise = 999.0
	hurt_size = Vector2(44, 138)
	shadow_w = 58.0


func _make_visual() -> PoseSprite:
	return preload("res://scripts/actors/hero_visual.gd").new()


var _last_clip_pos := 0.0
## Seconds the hero keeps the profile sword guard instead of the relaxed
## three-quarter idle. The relaxed idle sheet is drawn facing the viewer, so
## dropping into it between strikes made the body swing round for one beat.
var guard_t := 0.0
var _guard_relax_t := 0.0
var _taint_fx_t := 0.0
const GUARD_HOLD := 2.6
const GUARD_RELAX_DUR := 0.34
const GUARD_RANGE := 430.0


func _ready() -> void:
	super._ready()
	_floor_probe.position = Vector2.UP * 2.0
	_floor_probe.target_position = Vector2.DOWN * 330.0
	_floor_probe.collision_mask = 1
	add_child(_floor_probe)
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


## True while a press of `a` is buffered (see ACT_BUFFER). Consumed by the
## matching _start_* call.
func _wants(a: String) -> bool:
	return _act_buf.get(a, 0.0) > 0.0


func _can_dash() -> bool:
	return dash_cd <= 0.0 and (air_dash or is_on_floor())


func _consume(a: String) -> void:
	_act_buf[a] = 0.0


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
	_skid_cd = maxf(0.0, _skid_cd - delta)
	if not _talisman_projs.is_empty():
		_update_talisman_destructibles()
	if combo_timer > 0.0:
		combo_timer = maxf(0.0, combo_timer - delta)
		if combo_timer <= 0.0 and combo_hits > 0:
			combo_hits = 0
			combo_changed.emit(0)
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
	for a in _act_buf:
		_act_buf[a] = ACT_BUFFER if _pressed(a) else maxf(0.0, _act_buf[a] - delta)
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
	if _wants("talisman") and qi >= TALISMAN_COST and skill_cd <= 0.0:
		_start_skill("talisman")
		return true
	if _wants("gourd") and gourd > 0 and skill_cd <= 0.0:
		_start_skill("gourd")
		return true
	if _wants("beads") and qi >= BEADS_COST and skill_cd <= 0.0:
		_start_skill("beads_a")
		return true
	if _wants("dash") and _can_dash():
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
	if ax != 0.0 and _prev_ax == 0.0 and absf(velocity.x) < 40.0:
		Fx.dust(global_position + Vector2(-signf(ax) * 12.0, -2.0), 4, Vector2(-signf(ax) * 1.1, -0.45))
	elif ax != 0.0 and absf(velocity.x) > 150.0 and signf(ax) != signf(velocity.x) and _skid_cd <= 0.0:
		_skid_cd = 0.18
		var old_dir: float = signf(velocity.x)
		Fx.dust(global_position + Vector2(old_dir * 10.0, -2.0), 5, Vector2(old_dir * 1.2, -0.35))
		Sfx.play("step", -14.0, 0.12, 0.85)
		vis.squash = Vector2(1.06, 0.95)
	_prev_ax = ax
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
	_prev_ax = 0.0
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
	var impact_k: float = clampf((vy - 220.0) / 700.0, 0.0, 1.0)
	var side_n: int = int(roundf(lerpf(2.0, 7.0, impact_k)))
	Fx.dust(global_position + Vector2(-10.0, -2.0), side_n, Vector2(-0.9, -0.35))
	Fx.dust(global_position + Vector2(10.0, -2.0), side_n, Vector2(0.9, -0.35))
	if vy > 820.0:
		Fx.ring(global_position + Vector2(0.0, -2.0), 10.0, 56.0, Color(0.55, 0.48, 0.38, 0.48), 0.24, 5.0, 0.20)
	Sfx.play("land", -10.0 if vy < 700 else -4.0)
	if state == "air":
		if vy > 820.0:
			set_state("land")
			vis.squash = Vector2(1.12, 0.86)
			Fx.shake(2.0, 0.08)
		else:
			set_state("idle")
			vis.squash = Vector2(1.06, 0.94)
	elif state == "jump_attack":
		set_state("land")
		Fx.shake(3.0, 0.1)


func _st_land(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 2400.0 * delta)
	if state_t > 0.12:
		set_state("idle")
	elif state_t > 0.04:
		if jump_buf > 0.0:
			_jump()
			return
		_try_actions()


func _set_combat_frame(clip: String, idx: int, fallback_pose: String) -> void:
	vis.facing = facing
	if not vis.play_frame(clip, idx):
		vis.set_pose(fallback_pose, 0.0)


# ---------------------------------------------------------------- melee
func _start_attack(name_: String) -> void:
	cur_atk_name = name_
	_swing_started = false
	cur_atk = ATK[name_]
	hit_set = {}
	combo_queued = ""
	if name_ == "slash3":
		_ghost_t = 0.0
	set_state("attack")
	var ax := _axis()
	if ax != 0.0:
		facing = int(signf(ax))
	var clip := "slash2" if name_ == "down" else name_
	_set_combat_frame(clip, 0, cur_atk.pre)
	Sfx.play("swing_pre", -12.0)
	match name_:
		"slash1":
			Fx.blade_glint(global_position + Vector2(-12 * facing, -92), facing, Fx.C_GOLD, 16.0)
		"slash2", "down":
			Fx.blade_glint(global_position + Vector2(6 * facing, -148), facing, Color(1.0, 0.82, 0.42), 23.0)
		"slash3":
			Fx.blade_glint(global_position + Vector2(-18 * facing, -98), facing, Color(1.0, 0.62, 0.28), 26.0)


func _st_attack(delta: float) -> void:
	var a := cur_atk
	var t := state_t
	var st: float = a.startup
	var ac: float = a.active
	var total: float = st + ac + a.recover
	var clip := "slash2" if cur_atk_name == "down" else cur_atk_name
	var pass_t := st * (0.65 if clip == "slash2" else 0.50)
	var hold_after := 0.06 if clip == "slash1" else (0.08 if clip == "slash2" else 0.11)
	if t < st + ac:
		var k := t / (st + ac)
		velocity.x = facing * a.lunge * (1.0 - k) * _speed_mul()
	else:
		velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
	if cur_atk_name == "slash3" and t >= st * 0.5 and t < st + ac + 0.04:
		_ghost_t -= delta
		if _ghost_t <= 0.0:
			_ghost_t = 0.042
			_spawn_ghost(Color(0.98, 0.52, 0.24, 0.44), 0.20)
	if t < pass_t:
		_set_combat_frame(clip, 0, a.pre)
	elif t < st:
		_set_combat_frame(clip, 1, "hero_slash_pass" if clip == "slash1" else a.pre)
	if t >= st and not _swing_started:
		_swing_started = true
		_set_combat_frame(clip, 2, a.pose)
		var f: Array = a.fx
		var fx_pos := global_position + Vector2(a.fx_off.x * facing, a.fx_off.y)
		match cur_atk_name:
			"slash1":
				Fx.slash(fx_pos, facing, f[0], f[1], f[2] + 8.0, f[3] + 4.0, 0.24,
					Color(0.84, 0.16, 0.09), Color(1.0, 0.98, 0.92), f[4],
					"arc", Fx.C_GOLD, -0.14)
				Sfx.play("swing", -4.0, 0.04, 1.04)
				vis.squash = Vector2(1.07, 0.95)
			"slash2", "down":
				Fx.slash(fx_pos, facing, f[0], f[1], f[2] + 10.0, f[3] + 6.0, 0.28,
					Color(0.88, 0.18, 0.08), Color(1.0, 0.98, 0.93), f[4],
					"cleave", Color(1.0, 0.80, 0.34), 0.04)
				Fx.ground_slam(global_position + Vector2(68 * facing, 0.0), facing, 0.78 if cur_atk_name == "slash2" else 0.95)
				_smear(1, 0.28)
				Sfx.play("swing_heavy", -2.5, 0.04, 1.0)
				vis.squash = Vector2(1.10, 0.92)
			"slash3":
				Fx.slash(global_position + Vector2(12 * facing, -98), facing, f[0], f[1], f[2], 32.0, 0.28,
					Color(0.92, 0.20, 0.08), Color(1.0, 0.99, 0.94), 0.16,
					"thrust", Color(1.0, 0.82, 0.38), 0.0, 196.0)
				_smear(2, 0.34)
				Sfx.play("swing_thrust", -1.5, 0.03, 1.0)
				vis.squash = Vector2(1.14, 0.90)
			_:
				Fx.slash(fx_pos, facing, f[0], f[1], f[2], f[3], 0.26,
					Fx.C_CINNABAR, Color(1, 0.97, 0.9), f[4])
				Sfx.play("swing", -4.0)
				vis.squash = Vector2(1.06, 0.95)
	if t >= st and t < st + ac:
		_hit_destructibles(local_rect(a.rect), facing)
		var hits := strike(a.rect, a.dmg, a.poise, a.knock, hit_set, {"tag": cur_atk_name, "low": a.get("low", false)})
		if hits.size() > 0:
			_on_melee_connect(hits)
	# combo input window opens early so rapid taps always chain seamlessly
	if t >= 0.02 and atk_buf > 0.0 and a.next != "":
		combo_queued = a.next
		atk_buf = 0.0
	var can_cancel := t >= st + ac + 0.04
	if can_cancel and combo_queued != "":
		_start_attack(combo_queued)
		return
	if can_cancel and _wants("dash") and _can_dash():
		_start_dash()
		return
	if can_cancel and jump_buf > 0.0 and not hit_set.is_empty() and is_on_floor():
		_jump()
		return
	if can_cancel and skill_cd <= 0.0:
		if _wants("talisman") and qi >= TALISMAN_COST:
			_start_skill("talisman")
			return
		if _wants("beads") and qi >= BEADS_COST:
			_start_skill("beads_a")
			return
		if _wants("gourd") and gourd > 0:
			_start_skill("gourd")
			return
	if can_cancel and _held("block") and is_on_floor() and t >= st + ac + 0.08:
		set_state("block")
		block_t = 0.0
		return
	if t >= st:
		if t < st + ac + hold_after:
			_set_combat_frame(clip, 2, a.pose)
		else:
			_set_combat_frame(clip, 3, "hero_strike_settle")
	if t >= total:
		set_state("idle" if is_on_floor() else "air")


func _on_melee_connect(hits: Array) -> void:
	if cur_atk_name in ["slash3", "down"]:
		Game.rumble(0.2, 0.35, 0.08)   # heavy blows land with weight
	_gain_qi(5.0 * hits.size())
	register_hit(hits.size())
	var heavy := cur_atk_name in ["slash3", "down"]
	var hs := 0.042 if cur_atk_name == "slash1" else (0.075 if cur_atk_name == "slash3" else 0.056)
	Game.hitstop(hs)
	Fx.shake(2.6 if cur_atk_name == "slash1" else (5.2 if cur_atk_name == "slash3" else 3.8), 0.12)
	Fx.kick(Vector2(facing * (6.0 if cur_atk_name == "slash3" else (4.2 if heavy else 2.8)), 1.6 if cur_atk_name in ["slash2", "down"] else 0.0), 0.10)
	if heavy:
		Fx.punch(0.024 if cur_atk_name == "slash3" else 0.016, 0.16)


# ---------------------------------------------------------------- dash
func _start_dash() -> void:
	_consume("dash")
	set_state("dash")
	var ax := _axis()
	if ax != 0.0:
		facing = int(signf(ax))
	dash_cd = 0.42
	invuln = 0.24
	if not is_on_floor():
		air_dash = false
	velocity.y = minf(velocity.y, 0.0) if not is_on_floor() else velocity.y
	_set_combat_frame("dash", 0, "hero_06_dash")
	_ghost_t = 0.035
	_spawn_ghost(Color(0.95, 0.75, 0.36, 0.46), 0.22)
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
		_spawn_ghost(Color(0.95, 0.75, 0.36, 0.46), 0.22)
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
	_set_combat_frame("dash_attack", 0, "hero_06_dash")
	_ghost_t = 0.04
	_spawn_ghost(Color(1.0, 0.64, 0.28, 0.48), 0.22)
	Fx.blade_glint(global_position + Vector2(8 * facing, -64), facing, Fx.C_GOLD, 22.0)
	Sfx.play("swing_thrust", -2.5, 0.05, 1.08)
	Fx.slash(global_position + Vector2(24 * facing, -54), facing, -72.0, 72.0, 114.0, 30.0, 0.28,
		Color(0.88, 0.18, 0.08), Color(1.0, 0.98, 0.93), 0.26,
		"dash", Color(1.0, 0.80, 0.34), -0.05, 172.0)


func _st_dash_attack(delta: float) -> void:
	velocity.x = facing * lerpf(620.0, 0.0, clampf(state_t / 0.34, 0, 1)) * _speed_mul()
	if state_t < 0.03:
		_set_combat_frame("dash_attack", 0, "hero_06_dash")
	elif state_t < 0.24:
		_set_combat_frame("dash_attack", 1, "hero_06_dash")
	else:
		_set_combat_frame("dash_attack", 2, "hero_strike_settle")
	_ghost_t -= delta
	if _ghost_t <= 0.0 and state_t < 0.2:
		_ghost_t = 0.04
		_spawn_ghost(Color(1.0, 0.64, 0.28, 0.48), 0.22)
	if state_t >= 0.03 and state_t < 0.22:
		_hit_destructibles(local_rect(Rect2(-20, -95, 140, 95)), facing)
		var hits := strike(Rect2(-20, -95, 140, 95), 14.0, 16.0, 220.0, hit_set, {"tag": "dash_attack", "low": true})
		if hits.size() > 0:
			_gain_qi(5.0 * hits.size())
			register_hit(hits.size())
			Game.hitstop(0.055)
			Fx.shake(3.5, 0.12)
			Fx.kick(Vector2(facing * 5.2, 0.0), 0.10)
	if state_t >= 0.26 and atk_buf > 0.0:
		atk_buf = 0.0
		_start_attack("slash2")
		return
	if state_t >= 0.42:
		set_state("idle" if is_on_floor() else "air")


# ---------------------------------------------------------------- air attack
func _start_jump_attack() -> void:
	_jump_arm = -0.6
	set_state("jump_attack")
	air_attack = false
	hit_set = {}
	_set_combat_frame("jump_attack", 0, "hero_07_jump")
	_smear(1, 0.3)
	Sfx.play("swing", -4.0, 0.06, 1.08)
	Fx.slash(global_position + Vector2(26 * facing, -70), facing, -85.0, 98.0, 92.0, 36.0, 0.26,
		Color(0.86, 0.17, 0.09), Color(1.0, 0.98, 0.93), 1.0,
		"cleave", Fx.C_GOLD, 0.10)


func _st_jump_attack(delta: float) -> void:
	var ax := _axis()
	velocity.x = move_toward(velocity.x, ax * RUN_SPEED * 0.8, 1200.0 * delta)
	_jump_arm = lerpf(-0.6, 0.75, 1.0 - pow(1.0 - clampf(state_t / 0.2, 0.0, 1.0), 3.0))
	if state_t >= 0.04 and state_t < 0.24:
		_hit_destructibles(local_rect(Rect2(-10, -125, 128, 165)), facing)
		var hits := strike(Rect2(-10, -125, 128, 165), 13.0, 12.0, 160.0, hit_set, {"tag": "jump_attack", "low": true})
		if hits.size() > 0:
			_gain_qi(5.0 * hits.size())
			register_hit(hits.size())
			Game.hitstop(0.046)
			Fx.kick(Vector2(facing * 3.5, -2.5), 0.10)
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
	if not is_on_floor():
		set_state("air")
		return
	if not _held("block"):
		set_state("idle")
		return
	if _wants("dash") and _can_dash():
		_start_dash()
	elif atk_buf > 0.0 and block_t > 0.12:
		atk_buf = 0.0
		_start_attack("slash3")   # guard-counter: thrust out of block


# ---------------------------------------------------------------- skills
func _start_skill(s: String) -> void:
	_consume("beads" if s == "beads_a" else s)
	set_state(s)
	hit_set = {}
	velocity.x = 0.0
	match s:
		"talisman":
			qi -= TALISMAN_COST
			skill_cd = 0.3
			_set_combat_frame("talisman", 0, "hero_08_talisman")
			Sfx.play("talisman_draw", -6.0)
		"gourd":
			gourd -= 1
			gourd_changed.emit(gourd)
			skill_cd = 0.5
			_set_combat_frame("gourd", 0, "hero_09_gourd")
			Sfx.play("gourd_uncork", -4.0)
		"beads_a":
			qi -= BEADS_COST
			skill_cd = 0.8
			_set_combat_frame("beads_a", 0, "hero_10a_beads")
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
				_set_combat_frame("talisman", 1, "hero_08_talisman")
				var p := preload("res://scripts/fx/talisman_projectile.gd").new()
				p.global_position = global_position + Vector2(46 * facing, -96)
				p.dir = facing
				p.owner_actor = self
				Fx.layer().add_child(p)
				_talisman_projs.append(p)
				Fx.blade_glint(p.global_position, facing, Fx.C_GOLD, 20.0)
				Sfx.play("talisman_fire", -3.0)
			if state_t >= 0.32:
				set_state("idle" if is_on_floor() else "air")
		"gourd":
			if state_t >= 0.22 and hit_set.is_empty():
				hit_set["done"] = true
				_set_combat_frame("gourd", 1, "hero_09_gourd")
				hp = minf(max_hp, hp + 35.0)
				hp_changed.emit(hp, max_hp)
				Fx.float_text(global_position + Vector2(0, -170), "+35", Color(0.95, 0.85, 0.5))
				Fx.ring(global_position + Vector2(30 * facing, -80), 20.0, 170.0, Color(0.95, 0.75, 0.35, 0.9), 0.5, 14.0, 0.6)
				Fx.particles(global_position + Vector2(40 * facing, -90), 26, Color(0.9, 0.7, 0.3, 0.8), 380.0, 50.0, Vector2(facing, 0), 0.0, 0.5, 6.0)
				Fx.heal_spiral(self, 0.72)
				Fx.screen_pulse(Color(0.98, 0.80, 0.34, 0.26), 0.48)
				Sfx.play("gourd_gust", -2.0)
				var gust_rect := Rect2(global_position.x - 170, global_position.y - 170, 340, 175)
				_hit_destructibles(gust_rect, 0)
				var gust := {}
				var hits := Combat.strike({"owner": self, "team": team, "rect": gust_rect,
					"damage": 4.0, "poise": 30.0, "knock": 520.0, "dir": facing, "kind": "aoe", "centre": global_position,
					"unblockable": false, "tag": "gourd"}, gust)
				if hits.size() > 0:
					register_hit(hits.size())
					Fx.shake(3.0, 0.15)
			if state_t >= 0.58:
				set_state("idle" if is_on_floor() else "air")
		"beads_a":
			if state_t >= 0.42:
				set_state("beads_b")
				_set_combat_frame("beads_b", 0, "hero_10b_beads")
				Sfx.play("beads_burst", 0.0)
				var r := Fx.ring(global_position + Vector2(0, -40), 30.0, 230.0, Fx.C_GOLD, 0.6, 16.0, 0.45)
				r.glyphs = 18
				Fx.ring(global_position + Vector2(0, -40), 20.0, 190.0, Color(1, 0.95, 0.8, 0.8), 0.35, 6.0, 0.45)
				Fx.ground_slam(global_position, facing, 1.35)
				Fx.shake(6.0, 0.25)
				Fx.kick(Vector2(0.0, 6.0), 0.14)
				Fx.punch(0.04, 0.3)
				Game.hitstop(0.08)
				var beads_rect := Rect2(global_position.x - 210, global_position.y - 210, 420, 230)
				_hit_destructibles(beads_rect, 0)
				var hs := {}
				var b_hits := Combat.strike({"owner": self, "team": team, "rect": beads_rect,
					"damage": 28.0, "poise": 60.0, "knock": 420.0, "dir": facing, "kind": "aoe", "centre": global_position,
					"unblockable": false, "tag": "beads"}, hs)
				if b_hits.size() > 0:
					register_hit(b_hits.size())
				get_tree().call_group("taint_puddle", "purify_near", global_position, 240.0)
		"beads_b":
			if state_t >= 0.4:
				set_state("idle" if is_on_floor() else "air")


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
		if dead:
			return {"blocked": true}
		knock_v = -facing * (420.0 if heavy else 200.0)
		Sfx.play("block", -2.0)
		_block_recoil = -0.35 if heavy else -0.2
		Fx.spark(global_position + Vector2(30 * facing, -90), Fx.C_GOLD, 8)
		_gain_qi(2.0)
		if heavy:
			set_state("hit")
			_hit_stun = 0.45
			invuln = maxf(invuln, 0.45)
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
	vis.hit_shake(dir, 8.0, 0.16)
	Fx.shake(6.0, 0.22)
	Fx.kick(Vector2(dir * 7.0, 2.0), 0.12)
	Fx.hit_ink(global_position + Vector2(0, -80), dir, Fx.C_CINNABAR)
	Fx.hit_impact(global_position + Vector2(0, -84), dir, "slash1", atk.damage >= 20, Fx.C_CINNABAR, Color(1.0, 0.72, 0.4))
	Sfx.play("player_hurt", -2.0)
	Game.rumble(0.45, 0.7 if atk.damage >= 20 else 0.4, 0.22 if atk.damage >= 20 else 0.14)
	return {}


func _take(dmg: float, flash_: bool) -> void:
	dmg *= Game.DIFF_DAMAGE[Game.difficulty]
	Game.tel_damage(last_hit_source, minf(dmg, hp))
	if Game.level and Game.level.has_method("active_encounter_id"):
		var eid: String = Game.level.active_encounter_id()
		if eid != "":
			Game.tel_enc(eid, "damage", minf(dmg, hp))
	hp = maxf(0.0, hp - dmg)
	hp_changed.emit(hp, max_hp)
	if flash_:
		vis.flash = 0.45
		if dmg > 0.0:
			var sev: float = clampf(dmg / 26.0, 0.35, 1.0)
			Fx.screen_pulse(Color(0.68, 0.09, 0.06, 0.26 + 0.22 * sev), 0.26 + 0.16 * sev)
	if hp <= 0.0 and not dead:
		_die()


func _parry(atk: Dictionary) -> void:
	Game.rumble(0.8, 0.25, 0.12)   # crisp, high-frequency parry snap
	Game.parries += 1
	_gain_qi(15.0)
	Sfx.play("parry", 0.0, 0.03)
	var ppos := global_position + Vector2(36 * facing, -96)
	Fx.parry_burst(ppos, facing)
	Fx.float_text(global_position + Vector2(0, -175), Game.t("弹反", "PARRY"), Color(1, 0.88, 0.5), 30)
	Game.hitstop(0.16, 0.02)
	Fx.shake(5.0, 0.16)
	Fx.kick(Vector2(-facing * 6.5, -1.5), 0.11)
	Fx.punch(0.045, 0.22)
	Fx.screen_flash(Color(1.0, 0.90, 0.62, 0.22), 0.14)
	_block_recoil = -0.32
	vis.squash = Vector2(0.92, 1.07)
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
	Game.rumble(0.3, 1.0, 0.45)
	Game.telemetry.deaths.append(last_hit_source)
	dead = true
	combo_hits = 0
	combo_timer = 0.0
	combo_changed.emit(0)
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
	knock_v = 0.0
	_block_recoil = 0.0
	hp = max_hp
	qi = maxf(qi, 40.0)
	gourd = GOURD_MAX
	combo_hits = 0
	combo_timer = 0.0
	combo_changed.emit(0)
	_talisman_projs.clear()
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


func register_hit(count := 1) -> void:
	combo_hits += maxi(1, count)
	combo_timer = COMBO_WINDOW
	combo_changed.emit(combo_hits)


func on_kill(_enemy) -> void:
	_gain_qi(8.0)


func _hit_destructibles(rect: Rect2, dir: int, seen = null) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var tracked: Dictionary = seen if seen is Dictionary else hit_set
	for node in tree.get_nodes_in_group("destructible"):
		if not is_instance_valid(node) or tracked.has(node):
			continue
		if node.has_method("get_hit_rect") and node.has_method("take_sword_hit"):
			var r: Rect2 = node.get_hit_rect()
			if r.intersects(rect):
				tracked[node] = true
				var hit_dir: int = (1 if r.get_center().x >= global_position.x else -1) if dir == 0 else dir
				node.take_sword_hit(hit_dir)


func _update_talisman_destructibles() -> void:
	var alive: Array = []
	for proj in _talisman_projs:
		if not is_instance_valid(proj):
			continue
		var n := proj as Node2D
		if n == null or not n.is_physics_processing():
			continue
		var vel_v: Vector2 = n.get("vel") if n.get("vel") is Vector2 else Vector2.ZERO
		var d_val: int = int(n.get("dir"))
		var tdir: int = int(signf(vel_v.x)) if vel_v.x != 0.0 else d_val
		var p_seen = n.get("hit_set")
		_hit_destructibles(Rect2(n.global_position - Vector2(20.0, 14.0), Vector2(40.0, 28.0)), tdir, p_seen)
		alive.append(proj)
	_talisman_projs = alive


# ---------------------------------------------------------------- visuals
## Motion smear: fading copies of the previous and current pose trailing the swing.
func _smear(n: int, alpha: float) -> void:
	for i in n:
		var src: Sprite2D = vis.prev if (i == 0 and vis.prev.visible) else vis.active_sprite()
		if src == null or src.texture == null:
			continue
		var g := Sprite2D.new()
		g.texture = src.texture
		g.centered = false
		g.global_transform = src.global_transform
		g.position += Vector2(-facing * 14.0 * (i + 1), 0)
		g.modulate = Color(1.0, 0.85, 0.7, alpha * (1.0 - i * 0.35))
		g.z_index = 4
		Fx.layer().add_child(g)
		var tw := g.create_tween()
		tw.set_ignore_time_scale(true)
		tw.tween_property(g, "modulate:a", 0.0, 0.14)
		tw.tween_callback(g.queue_free)


func _spawn_ghost(tint := Color(0.95, 0.75, 0.36, 0.46), life := 0.22) -> void:
	Fx.afterimage(vis, global_position, tint, life)


func _enemy_near() -> bool:
	if Game.level == null or not is_instance_valid(Game.level):
		return false
	var actors := Game.level.get_node_or_null("Actors")
	if actors == null:
		return false
	for n in actors.get_children():
		if n is Enemy and n.aggro and n.state != "dead" \
				and absf(n.global_position.x - global_position.x) < GUARD_RANGE:
			return true
	return false


func _animate(delta: float) -> void:
	vis.facing = facing
	vis.on_ground = is_on_floor()
	vis.locomotion_speed = absf(velocity.x)
	if is_on_floor():
		vis.air_height = 0.0
	elif _floor_probe != null and _floor_probe.is_colliding():
		vis.air_height = maxf(0.0, to_local(_floor_probe.get_collision_point()).y)
	else:
		vis.air_height = maxf(0.0, Game.GROUND_Y - global_position.y)
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
	# Standing in taint: a light sickly cast plus vapour curling off the legs.
	# A full green multiply turned the painted costume into olive mud.
	vis.tint = Color(0.91, 0.98, 0.86) if in_taint > 0.0 else Color.WHITE
	if in_taint > 0.0:
		_taint_fx_t -= delta
		if _taint_fx_t <= 0.0:
			_taint_fx_t = 0.16
			Fx.particles(global_position + Vector2(randf_range(-22, 22), -6), 3,
				Color(0.55, 0.78, 0.22, 0.55), 70.0, 25.0, Vector2.UP, -40.0, 0.8, 9.0, 9)
	vis.alpha = 0.7 if (invuln > 0.0 and state != "dash" and state != "dash_attack" and int(invuln * 20) % 2 == 0) else 1.0
	vis.clip_speed_scale = 1.0
	var was_guard := guard_t > 0.0
	if state in ["attack", "dash_attack", "jump_attack", "block", "hit", "talisman", "gourd", "beads_a", "beads_b"] or _enemy_near():
		guard_t = GUARD_HOLD
		_guard_relax_t = 0.0
	else:
		guard_t = maxf(0.0, guard_t - delta)
		if was_guard and guard_t <= 0.0 and state == "idle":
			_guard_relax_t = GUARD_RELAX_DUR
		elif _guard_relax_t > 0.0:
			_guard_relax_t = maxf(0.0, _guard_relax_t - delta)
	if state != "idle":
		_guard_relax_t = 0.0
	match state:
		"idle":
			if guard_t > 0.0:
				if vis.has_frame_clip("guard_idle"):
					vis.play_clip("guard_idle", 0.08)
				else:
					vis.set_pose("hero_strike_settle", 0.0)
					vis.breathe = 0.010
			elif _guard_relax_t > 0.0 and vis.has_frame_clip("guard_to_idle"):
				vis.play_clip("guard_to_idle", 0.04)
			else:
				vis.play_clip("idle", 0.18)
		"run":
			var spd := absf(velocity.x)
			if spd < 170.0:
				vis.play_clip("walk", 0.15)
				vis.clip_speed_scale = clampf(spd / 140.0, 0.45, 1.35)
			else:
				vis.play_clip("run", 0.12)
				vis.clip_speed_scale = clampf(spd / 260.0, 0.65, 1.35)
			# footfalls at the two contact keys of the cycle
			var pos: float = vis.clip_progress()
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
			_set_combat_frame("dash", 0, "hero_06_dash")
		"attack":
			target_lean = 0.0 # The painted strikes already include their forward weight shift.
		"hit":
			target_lean = -6.0
	# The airborne strike and skill poses still articulate their painted arms.
	var ar0 := 0.0
	var ar1 := 0.0
	match state:
		"jump_attack":
			ar0 = _jump_arm
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
	vis.arm_off = [Vector2.ZERO, Vector2.ZERO]
	vis.lean = lerpf(vis.lean, target_lean, minf(1.0, delta * 14.0))
	vis.sway = 0.012 if state in ["run", "dash", "dash_attack", "air", "jump_attack"] else 0.005


func _draw() -> void:
	if vis == null or (dead and vis.dissolve > 0.6):
		return
	var floor_y := 0.0
	if not is_on_floor():
		if not _floor_probe.is_colliding():
			return
		floor_y = maxf(0.0, to_local(_floor_probe.get_collision_point()).y)
	var lift := clampf(floor_y / 200.0, 0.0, 1.0)
	var fade := 1.0 - vis.dissolve
	var lean_x := float(vis.current_light().get("shadow_lean", -0.35))
	var soil: Color = vis.current_light().get("soil", Color(0.20, 0.16, 0.13))
	var shadow_col := Color(soil.r * 0.16, soil.g * 0.14, soil.b * 0.15, 1.0)
	# Directional cast shadow skewed opposite the zone's key sun/moon angle
	var cast_shift := Vector2(lean_x * lerpf(28.0, 48.0, lift), floor_y + 1.0)
	draw_set_transform(cast_shift, 0.0, Vector2(1.25 + lift * 0.35, 0.15 + lift * 0.04))
	draw_circle(Vector2.ZERO, 44.0, Color(shadow_col.r, shadow_col.g, shadow_col.b, lerpf(0.22, 0.05, lift) * fade), true, -1.0, true)
	# Core grounded ambient occlusion pool under the figure's mass
	draw_set_transform(Vector2(lean_x * 6.0, floor_y - 0.5), 0.0, Vector2(1.0 + lift * 0.25, 0.14))
	draw_circle(Vector2.ZERO, 34.0, Color(shadow_col.r, shadow_col.g, shadow_col.b, lerpf(0.32, 0.07, lift) * fade), true, -1.0, true)
	if is_on_floor():
		var last_fx := 1e9
		for foot: Vector2 in vis.contacts:
			if absf(foot.x - last_fx) < 16.0:
				continue
			last_fx = foot.x
			var pressure := 1.0 - smoothstep(2.0, 18.0, absf(foot.y))
			draw_set_transform(Vector2(foot.x, -0.5), 0.0, Vector2(1.0, 0.22))
			draw_circle(Vector2.ZERO, 11.5, Color(0.05, 0.04, 0.035, 0.42 * pressure * fade), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
