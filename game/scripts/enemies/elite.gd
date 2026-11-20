extends Enemy
## 05 尸将·前期精英 Undead Warrior Elite — 180 px, hurtbox 72x172, 85 px/s.
## Heavy super armour: normal hits never interrupt; they wear down a poise
## meter, and parries take big chunks. When it breaks the elite kneels for a
## long punish window. Two telegraphed heavies (spec: 0.65–0.85 s wind-ups):
##  竖劈 overhead chop  — 0.8 s, huge damage + low ground shock (jump it)
##  横扫 wide sweep     — 0.65 s, wide band 40–128 px high (jump/dash/parry)
## Each heavy is followed by a clear recovery window. Phase 2 (<= 50% HP):
## faster wind-ups, chop->sweep chains, and one grunt summon (encounter D).

signal summon_request(count)
signal phase_changed(phase)

var cd := 1.0
var phase := 1
var since_hit := 0.0
var chain := ""
# Replay can supply a fixed move order at the normal AI decision point.
var heavy_selector: Callable
var summoned := false
var _phase2_aura: Phase2Aura = null
var _phase2_embers: CPUParticles2D = null
var _phase2_smoke: CPUParticles2D = null
var _last_walk_p: float = 0.0


func _init() -> void:
	hit_material = "armor"
	rig_type = "elite"
	walk_speed = 85.0
	enemy_name = "尸将"
	max_hp = 460.0
	max_poise = 110.0
	hurt_size = Vector2(72, 172)
	idle_pose = "elite_main"
	stagger_pose = "elite_idle"
	death_pose = "elite_idle"
	stagger_clip = "kneel"
	death_clip = "dead"
	stagger_time = 1.8
	interrupt_poise = 9999.0
	armored_states = ["chase", "windup_chop", "chop", "recover_chop", "windup_sweep", "sweep", "recover_sweep", "roar", "idle", "lunge"]
	topple_on_death = false
	shadow_w = 92.0


func _ready() -> void:
	max_poise *= Game.DIFF_POISE[Game.difficulty]
	super._ready()
	facing = -1
	vis.extra_scale = 1.0
	_phase2_aura = Phase2Aura.new()
	_phase2_aura.z_index = 4
	add_child(_phase2_aura)
	if state != "spawn":
		set_state("idle")


func poise_breaks_on_any() -> bool:
	return false


func _hit_sound(_atk: Dictionary) -> String:
	return "hit_armor"


func on_hurt(atk: Dictionary) -> void:
	since_hit = 0.0
	if state == "stagger":
		# punish window: broken armour takes bonus damage
		hp -= atk.damage * 0.5
	if not aggro:
		aggro = true
		set_state("chase")


func on_parried() -> void:
	poise -= 45.0
	Fx.float_text(global_position + Vector2(0, -hurt_size.y - 30), "破绽", Color(1, 0.85, 0.5), 26)
	if poise <= 0.0:
		_break()
	else:
		set_state("recoil")
		telegraph.stop()
		play_pose_or_clip("recoil", "", 0.05, true)
		vis.lean = -10.0
		knock_v = -facing * 120.0


func receive_hit(atk: Dictionary) -> Dictionary:
	var res := super.receive_hit(atk)
	if res.has("staggered") and not dead:
		_break(false)
	return res


func _break(reset_state := true) -> void:
	poise = max_poise
	if reset_state:
		stagger(stagger_time, -facing, 60.0)
	stagger_time_left = stagger_time
	play_pose_or_clip("kneel", "", 0.06, true)
	vis.lean = 18.0
	vis.squash = Vector2(1.04, 0.86)
	Sfx.play("armor_break", 0.0)
	Fx.float_text(global_position + Vector2(0, -hurt_size.y - 40), "破甲", Color(1, 0.6, 0.4), 32)
	Fx.particles(global_position + Vector2(0, -120), 24, Color(0.4, 0.22, 0.16), 300.0, 120.0, Vector2.UP, 900.0, 0.8, 6.0)
	Fx.shake(6.0, 0.25)
	Game.hitstop(0.12)


func update_stagger(delta: float) -> bool:
	if state != "stagger":
		return false
	velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
	vis.lean = lerpf(vis.lean, 16.0, delta * 4.0)
	vis.squash = vis.squash.lerp(Vector2(1.03, 0.88), delta * 6.0)
	if state_t >= stagger_time_left:
		set_state("chase")
		vis.lean = 0.0
		cd = 0.4
	return true


func _ai(delta: float) -> void:
	cd = maxf(0.0, cd - delta)
	since_hit += delta
	if _phase2_aura != null:
		_phase2_aura.dir = facing
	if since_hit > 2.5 and state != "stagger":
		poise = minf(max_poise, poise + 22.0 * delta)
	if phase == 1 and hp <= max_hp * 0.5 and state in ["chase", "idle", "recover_chop", "recover_sweep"]:
		_roar()
		return
	if update_stagger(delta):
		return
	var p := player()
	var dx := dx_to_player()
	var ad := absf(dx)
	var spd := 1.0 if phase == 1 else 0.85
	match state:
		"idle":
			velocity.x = 0.0
			still_anim()
			vis.breathe = 0.004
			if p and (ad < 520.0 or aggro):
				aggro = true
				face_toward(p.global_position.x)
				set_state("chase")
				Sfx.play("elite_roar", -6.0, 0.05, 1.15)
		"chase":
			if not p:
				velocity.x = 0.0
				still_anim()
				return
			face_toward(p.global_position.x)
			vis.set_pose("elite_main", 0.12)
			if ad > 150.0:
				velocity.x = facing * (85.0 if phase == 1 else 105.0)
				walk_anim(delta, 1.0, 4.0, 0.025)
				_check_stomp_dust()
				if ad < 330.0 and cd <= 0.0 and phase == 2 and randf() < delta * 1.2:
					_start("lunge")
			else:
				velocity.x = 0.0
				still_anim()
				if cd <= 0.0:
					_start(heavy_selector.call() if heavy_selector.is_valid() else ("windup_chop" if randf() < 0.55 else "windup_sweep"))
		"lunge":
			velocity.x = facing * 300.0 * (1.0 - state_t / 0.45)
			walk_anim(delta, 1.2, 6.0, 0.03)
			_check_stomp_dust()
			if state_t >= 0.45 or ad < 140.0:
				_start("windup_chop")
		"windup_chop":
			velocity.x = 0.0
			# raise the cleaver arm back over the wind-up
			vis.arm_rot = [lerpf(0.0, 0.5, clampf(state_t / 0.6, 0.0, 1.0)), -0.15]
			vis.lean = lerpf(vis.lean, -12.0, delta * 5.0)
			vis.squash = vis.squash.lerp(Vector2(0.95, 1.08), delta * 4.0)
			vis.nudge = Vector2(-10.0 * clampf(state_t / 0.5, 0.0, 1.0), 0.0)
			if phase == 2 and randf() < delta * 18.0:
				Fx.particles(global_position + Vector2(randf_range(-16.0, 26.0) * facing, -randf_range(165.0, 215.0)),
					2, Color(0.96, 0.30, 0.10, 0.92), 115.0, 120.0, Vector2.UP, -60.0, 0.36, 4.2, 12)
			if state_t >= 0.8 * spd:
				_chop()
		"chop":
			swing_arm(-0.7, 0.35, 0.1)
			velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)
			if state_t < 0.12:
				melee(Rect2(18, -196, 156, 196), 30.0, 380.0, {"heavy": true})
				if phase == 2 and randf() < delta * 55.0:
					var arc_k: float = clampf(state_t / 0.12, 0.0, 1.0)
					var bp := global_position + Vector2(lerpf(42.0, 136.0, arc_k) * facing, lerpf(-185.0, -24.0, arc_k))
					Fx.particles(bp, 3, Color(1.0, 0.42, 0.14, 0.95), 220.0, 75.0, Vector2(facing, 0.4).normalized(), 420.0, 0.38, 4.6, 13)
			if state_t >= 0.12:
				set_state("recover_chop")
				play_pose_or_clip("recover_chop", "", 0.1, true)
		"recover_chop":
			velocity.x = 0.0
			vis.arm_rot = [0.35, 0.0]
			vis.lean = lerpf(vis.lean, 16.0, delta * 3.0)
			if state_t >= (1.15 if chain == "" else 0.5):
				if chain == "sweep":
					chain = ""
					_start("windup_sweep")
				else:
					vis.lean = 0.0
					cd = 0.9 if phase == 1 else 0.55
					set_state("chase")
		"windup_sweep":
			velocity.x = -facing * 25.0
			vis.arm_rot = [lerpf(0.0, 0.7, clampf(state_t / 0.5, 0.0, 1.0)), 0.0]
			vis.lean = lerpf(vis.lean, -10.0, delta * 5.0)
			vis.rig.skew = lerpf(vis.rig.skew, -0.18, delta * 5.0)
			if phase == 2 and randf() < delta * 18.0:
				Fx.particles(global_position + Vector2(-facing * randf_range(24.0, 56.0), -randf_range(76.0, 118.0)),
					2, Color(0.96, 0.34, 0.12, 0.92), 110.0, 110.0, Vector2(-facing, -0.4).normalized(), -40.0, 0.36, 4.2, 12)
			if state_t >= 0.65:   # spec floor: sweep wind-up never below 0.65 s
				_sweep()
		"sweep":
			swing_arm(0.7, -0.9, 0.14)
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			vis.rig.skew = lerpf(vis.rig.skew, 0.12, delta * 20.0)
			if state_t < 0.12:
				melee(Rect2(-30, -92, 222, 62), 22.0, 420.0)
				if phase == 2 and randf() < delta * 55.0:
					var sw_k: float = clampf(state_t / 0.12, 0.0, 1.0)
					var sp := global_position + Vector2(lerpf(-20.0, 168.0, sw_k) * facing, -74.0 + randf_range(-16.0, 16.0))
					Fx.particles(sp, 3, Color(1.0, 0.44, 0.14, 0.95), 260.0, 55.0, Vector2(facing, -0.2).normalized(), 320.0, 0.36, 4.5, 13)
			if state_t >= 0.18:
				set_state("recover_sweep")
				play_pose_or_clip("recover_sweep", "", 0.08, true)
		"recover_sweep":
			velocity.x = 0.0
			vis.arm_rot = [lerpf(-0.9, 0.0, clampf(state_t / 0.6, 0.0, 1.0)), 0.0]
			vis.rig.skew = lerpf(vis.rig.skew, 0.0, delta * 4.0)
			vis.lean = lerpf(vis.lean, 6.0, delta * 3.0)
			if state_t >= 0.8:
				vis.rig.skew = 0.0
				vis.lean = 0.0
				cd = 1.0 if phase == 1 else 0.6
				set_state("chase")
		"recoil":
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			vis.lean = lerpf(vis.lean, 0.0, delta * 4.0)
			if state_t >= 0.6:
				set_state("chase")
				cd = 0.3
		"roar":
			velocity.x = 0.0
			vis.nudge.x = sin(state_t * 60.0) * 3.0
			if state_t >= 1.1:
				vis.nudge.x = 0.0
				set_state("chase")
				cd = 0.5


func _start(s: String) -> void:
	set_state(s)
	attack_hits = {}
	match s:
		"windup_chop":
			play_pose_or_clip("windup_chop", "", 0.08, true)
			telegraph.flare(Vector2(30, -215), 0.8 * (1.0 if phase == 1 else 0.85), Color(1, 0.3, 0.15))
			telegraph.danger(Rect2(-30, -28, 300, 28), 0.8 * (1.0 if phase == 1 else 0.85))
			Fx.dust(global_position + Vector2(facing * 12.0, -2.0), 6, Vector2(facing * 0.6, -0.35))
			if phase == 2:
				Fx.particles(global_position + Vector2(24.0 * facing, -188.0), 8, Color(0.95, 0.28, 0.10, 0.92), 170.0, 110.0, Vector2.UP, 120.0, 0.42, 4.8, 13)
			Sfx.play("elite_windup", -2.0)
			if phase == 2 and randf() < 0.6:
				chain = "sweep"
		"windup_sweep":
			play_pose_or_clip("windup_sweep", "", 0.08, true)
			telegraph.flare(Vector2(-40, -96), 0.65, Color(1, 0.55, 0.2))
			telegraph.danger(Rect2(-30, -92, 222, 62), 0.65, Color(0.8, 0.3, 0.05, 0.16))
			Fx.dust(global_position + Vector2(facing * 14.0, -2.0), 6, Vector2(facing * 0.8, -0.35))
			Sfx.play("elite_windup", -2.0, 0.05, 1.2)
		"lunge":
			vis.set_pose("elite_main", 0.06)
			Fx.dust(global_position + Vector2(-facing * 18.0, -2.0), 10, Vector2(-facing * 1.1, -0.4))
			Sfx.play("elite_step", 0.0)


func _chop() -> void:
	set_state("chop")
	play_pose_or_clip("chop", "elite_attack", 0.02, true)
	vis.lean = 16.0
	vis.squash = Vector2(1.08, 0.9)
	velocity.x = facing * 160.0
	Sfx.play("elite_chop", 2.0)
	Fx.dust(global_position + Vector2(-facing * 12.0, -2.0), 10, Vector2(-facing * 1.0, -0.4))
	var chop_rim := Color(0.76, 0.11, 0.06) if phase == 2 else Color(0.48, 0.12, 0.08)
	var chop_accent := Color(1.0, 0.46, 0.16) if phase == 2 else Color(0.92, 0.56, 0.24)
	Fx.slash(global_position + Vector2(70 * facing, -110), facing, -120.0, 85.0, 110.0, 40.0, 0.28,
		chop_rim, Color(0.98, 0.90, 0.76), 1.0,
		"cleave", chop_accent, 0.06)
	if phase == 2:
		Fx.particles(global_position + Vector2(96.0 * facing, -92.0), 16, Color(0.98, 0.34, 0.10, 0.95),
			320.0, 85.0, Vector2(facing, 0.35).normalized(), 520.0, 0.48, 5.0, 13)
	# ground shock (震地): low band around the impact point; jump over it
	var impact := global_position + Vector2(120 * facing, 0)
	Fx.ground_slam(impact, facing, 1.35)
	Fx.ring(impact + Vector2(0, -4), 10.0, 150.0, Color(0.55, 0.45, 0.32, 0.9), 0.5, 14.0, 0.18)
	Fx.dust(impact, 18)
	Fx.particles(impact, 16, Color(0.25, 0.2, 0.15), 380.0, 60.0, Vector2.UP, 1200.0, 0.6, 6.0)
	Fx.shake(9.0, 0.35)
	Fx.kick(Vector2(0.0, 9.0), 0.16)
	Fx.punch(0.035, 0.3)
	var hs := {}
	Combat.strike({"owner": self, "team": team, "rect": Rect2(impact.x - 150, impact.y - 34, 300, 36),
		"damage": 8.0, "poise": 0.0, "knock": 260.0, "dir": facing, "kind": "aoe", "centre": impact,
		"unblockable": true, "tag": "ground_shock"}, hs)


func _sweep() -> void:
	set_state("sweep")
	play_pose_or_clip("sweep", "", 0.02, true)
	vis.lean = 10.0
	velocity.x = facing * 140.0
	Sfx.play("elite_sweep", 1.0)
	Fx.dust(global_position + Vector2(-facing * 14.0, -2.0), 10, Vector2(-facing * 1.0, -0.35))
	var sw_rim := Color(0.78, 0.12, 0.06) if phase == 2 else Color(0.52, 0.13, 0.08)
	var sw_accent := Color(1.0, 0.48, 0.18) if phase == 2 else Color(0.94, 0.58, 0.26)
	Fx.slash(global_position + Vector2(40 * facing, -88), facing, 170.0, 5.0, 135.0, 52.0, 0.32,
		sw_rim, Color(0.98, 0.90, 0.76), 0.45,
		"cleave", sw_accent, -0.10)
	if phase == 2:
		Fx.particles(global_position + Vector2(88.0 * facing, -78.0), 18, Color(1.0, 0.38, 0.12, 0.95),
			360.0, 48.0, Vector2(facing, -0.15).normalized(), 340.0, 0.45, 4.8, 13)
	Fx.shake(5.0, 0.2)
	Fx.kick(Vector2(facing * 6.0, 0.0), 0.12)


func _roar() -> void:
	phase = 2
	set_state("roar")
	telegraph.stop()
	play_pose_or_clip("roar", "", 0.06, true)
	vis.rig.skew = 0.0
	Sfx.play("elite_roar", 2.0)
	var center := global_position + Vector2(0.0, -118.0)
	Fx.ring(center, 22.0, 290.0, Color(0.68, 0.10, 0.06, 0.88), 0.78, 16.0, 0.58)
	Fx.ring(center, 12.0, 210.0, Color(1.0, 0.72, 0.28, 0.86), 0.56, 8.0, 0.58)
	Fx.ring(global_position + Vector2(0.0, -4.0), 16.0, 220.0, Color(0.55, 0.12, 0.08, 0.76), 0.65, 10.0, 0.20)
	Fx.particles(center, 34, Color(0.86, 0.20, 0.10, 0.92), 340.0, 180.0, Vector2.UP, 260.0, 0.85, 6.0, 12)
	Fx.particles(global_position + Vector2(0.0, -60.0), 22, Color(1.0, 0.72, 0.26, 0.90), 260.0, 140.0, Vector2.UP, -140.0, 0.95, 4.5, 12)
	Fx.dust(global_position, 14)
	Fx.shake(9.0, 0.65)
	Fx.punch(0.055, 0.42)
	Fx.screen_pulse(Color(0.58, 0.08, 0.05, 0.22), 0.42)
	_activate_phase2_aura()
	phase_changed.emit(2)
	if not summoned:
		summoned = true
		summon_request.emit(2)


func _check_stomp_dust() -> void:
	if not is_on_floor() or not (vis is RigVisual):
		return
	var pos: float = (vis as RigVisual).clip_progress()
	for contact in [0.08, 0.58]:
		var c_f: float = float(contact)
		if _last_walk_p < c_f and pos >= c_f:
			Fx.dust(global_position + Vector2(-facing * 16.0, -2.0), 4 if phase == 1 else 6, Vector2(-facing * 0.9, -0.35))
	_last_walk_p = pos


func _activate_phase2_aura() -> void:
	if _phase2_aura != null:
		_phase2_aura.active = true
	if _phase2_embers != null:
		_phase2_embers.emitting = true
		if _phase2_smoke != null:
			_phase2_smoke.emitting = true
		return
	_phase2_smoke = CPUParticles2D.new()
	_phase2_smoke.position = Vector2(0.0, -82.0)
	_phase2_smoke.amount = 14
	_phase2_smoke.lifetime = 1.45
	_phase2_smoke.local_coords = false
	_phase2_smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_phase2_smoke.emission_rect_extents = Vector2(32.0, 48.0)
	_phase2_smoke.direction = Vector2.UP
	_phase2_smoke.spread = 38.0
	_phase2_smoke.initial_velocity_min = 20.0
	_phase2_smoke.initial_velocity_max = 52.0
	_phase2_smoke.gravity = Vector2(0.0, -35.0)
	_phase2_smoke.texture = Fx.dot_texture()
	_phase2_smoke.scale_amount_min = 0.75
	_phase2_smoke.scale_amount_max = 1.45
	var sg := Gradient.new()
	sg.set_color(0, Color(0.36, 0.05, 0.04, 0.0))
	sg.add_point(0.25, Color(0.42, 0.06, 0.04, 0.42))
	sg.set_color(sg.get_point_count() - 1, Color(0.09, 0.03, 0.03, 0.0))
	_phase2_smoke.color_ramp = sg
	_phase2_smoke.z_index = 4
	_phase2_smoke.emitting = true
	add_child(_phase2_smoke)

	_phase2_embers = CPUParticles2D.new()
	_phase2_embers.position = Vector2(0.0, -96.0)
	_phase2_embers.amount = 18
	_phase2_embers.lifetime = 1.15
	_phase2_embers.local_coords = false
	_phase2_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_phase2_embers.emission_rect_extents = Vector2(36.0, 62.0)
	_phase2_embers.direction = Vector2.UP
	_phase2_embers.spread = 30.0
	_phase2_embers.initial_velocity_min = 40.0
	_phase2_embers.initial_velocity_max = 98.0
	_phase2_embers.gravity = Vector2(0.0, -58.0)
	_phase2_embers.texture = Fx.dot_texture()
	_phase2_embers.scale_amount_min = 0.16
	_phase2_embers.scale_amount_max = 0.36
	var eg := Gradient.new()
	eg.set_color(0, Color(1.0, 0.78, 0.30, 0.95))
	eg.add_point(0.45, Color(0.88, 0.22, 0.08, 0.85))
	eg.set_color(eg.get_point_count() - 1, Color(0.28, 0.04, 0.03, 0.0))
	_phase2_embers.color_ramp = eg
	_phase2_embers.z_index = 6
	_phase2_embers.emitting = true
	add_child(_phase2_embers)


func _die(dir := 0) -> void:
	super._die(dir)
	if _phase2_aura != null:
		_phase2_aura.is_dead = true
	if _phase2_embers != null:
		_phase2_embers.emitting = false
	if _phase2_smoke != null:
		_phase2_smoke.emitting = false
	vis.lean = 22.0
	vis.squash = Vector2(1.05, 0.84)
	vis.rig.skew = 0.0
	Sfx.play("elite_die", 2.0)
	play_pose_or_clip("dead", "", 0.1, true)
	Fx.shake(10.0, 0.6)
	Fx.punch(0.08, 0.9)
	Game.hitstop(1.1, 0.25)   # slow-motion fall
	var c := global_position + Vector2(0, -100)
	Fx.ring(c, 20.0, 340.0, Color(0.06, 0.05, 0.04, 0.85), 0.9, 22.0, 0.55)
	Fx.ring(c, 10.0, 260.0, Color(0.7, 0.14, 0.08, 0.8), 0.7, 10.0, 0.55)
	Fx.material_hit(c, -facing, "armor", true)
	Fx.debris(c, 26, Fx._shard_tex if Fx._shard_tex else null, 520.0, 1300.0, 1.4, Vector2.UP, 160.0, 1.6)
	if Game.level and Game.level.hud and Game.level.hud.has_method("boss_defeated"):
		Game.level.hud.boss_defeated("尸将", "UNDEAD WARRIOR ELITE")
	Fx.particles(global_position + Vector2(0, -120), 50, Color(0.35, 0.2, 0.15), 380.0, 150.0, Vector2.UP, 900.0, 1.2, 7.0)
	_dissolve_t = -1.2   # linger longer before burning away


## Persistent Phase-2 crimson-gold ground shimmer & cracked-armor 煞气 aura.
class Phase2Aura extends Node2D:
	var active: bool = false
	var is_dead: bool = false
	var dir: int = -1
	var _alpha: float = 0.0
	var _t: float = 0.0

	func _ready() -> void:
		visible = false

	func _process(delta: float) -> void:
		var dt: float = Game.unscaled_delta(delta)
		_t += dt
		var want: float = 1.0 if (active and not is_dead) else 0.0
		_alpha = move_toward(_alpha, want, dt * (2.0 if want > 0.5 else 1.8))
		visible = _alpha > 0.01
		if visible:
			queue_redraw()

	func _draw() -> void:
		if _alpha <= 0.01:
			return
		var a: float = _alpha
		var pulse: float = 0.5 + 0.5 * sin(_t * 5.2)
		var fast_p: float = 0.5 + 0.5 * sin(_t * 11.4 + 0.8)

		# Warm crimson-gold ground heat-shimmer ring under boots
		var r_base: float = 52.0 + 6.0 * pulse
		var pts_outer := PackedVector2Array()
		var pts_inner := PackedVector2Array()
		for i in 37:
			var ang: float = TAU * float(i) / 36.0
			var wobble: float = 1.0 + 0.04 * sin(ang * 5.0 + _t * 6.0)
			pts_outer.append(Vector2(cos(ang) * r_base * wobble, -2.0 + sin(ang) * r_base * 0.21))
			pts_inner.append(Vector2(cos(ang) * (r_base * 0.72), -2.0 + sin(ang) * r_base * 0.15))
		draw_polyline(pts_outer, Color(0.16, 0.03, 0.03, 0.44 * a), 7.5, true)
		draw_polyline(pts_outer, Color(0.76, 0.13, 0.07, (0.52 + 0.22 * pulse) * a), 3.4, true)
		draw_polyline(pts_inner, Color(0.98, 0.66, 0.24, (0.36 + 0.20 * fast_p) * a), 1.8, true)

		# Subtle dark-crimson rim aura pulsing behind cracked armor
		var torso_c := Vector2(float(dir) * 4.0, -104.0)
		draw_circle(torso_c, 64.0 + 7.0 * pulse, Color(0.48, 0.06, 0.04, (0.12 + 0.05 * pulse) * a))
		draw_circle(torso_c, 38.0 + 4.0 * fast_p, Color(0.84, 0.18, 0.08, (0.10 + 0.05 * fast_p) * a))

		# Rising calligraphic heat-shimmer wisps curling off boots & shoulders
		for i in 4:
			var phase_k: float = fposmod(_t * 0.85 + float(i) * 0.25, 1.0)
			var side: float = -1.0 if i % 2 == 0 else 1.0
			var wx: float = side * lerpf(24.0, 44.0, float(i) * 0.25) + sin(phase_k * TAU + float(i)) * 6.0
			var wy0: float = lerpf(-10.0, -142.0, phase_k)
			var wy1: float = wy0 - lerpf(18.0, 32.0, sin(phase_k * PI))
			var wa: float = sin(phase_k * PI) * 0.46 * a
			var wcol := Color(0.88, 0.22, 0.09, wa) if i % 2 == 0 else Color(0.98, 0.68, 0.26, wa * 0.85)
			draw_line(Vector2(wx, wy0), Vector2(wx + sin(phase_k * 9.0) * 5.0, wy1), wcol, 2.0, true)
