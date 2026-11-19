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
		anim("recoil", 0.05, true)
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
	anim("kneel", 0.06, true)
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
			if state_t >= 0.45 or ad < 140.0:
				_start("windup_chop")
		"windup_chop":
			velocity.x = 0.0
			# raise the cleaver arm back over the wind-up
			vis.arm_rot = [lerpf(0.0, 0.5, clampf(state_t / 0.6, 0.0, 1.0)), -0.15]
			vis.lean = lerpf(vis.lean, -12.0, delta * 5.0)
			vis.squash = vis.squash.lerp(Vector2(0.95, 1.08), delta * 4.0)
			vis.nudge = Vector2(-10.0 * clampf(state_t / 0.5, 0.0, 1.0), 0.0)
			if state_t >= 0.8 * spd:
				_chop()
		"chop":
			swing_arm(-0.7, 0.35, 0.1)
			velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)
			if state_t < 0.12:
				melee(Rect2(18, -196, 156, 196), 30.0, 380.0, {"heavy": true})
			if state_t >= 0.12:
				set_state("recover_chop")
				anim("recover_chop", 0.1, true)
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
			if state_t >= 0.65:   # spec floor: sweep wind-up never below 0.65 s
				_sweep()
		"sweep":
			swing_arm(0.7, -0.9, 0.14)
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			vis.rig.skew = lerpf(vis.rig.skew, 0.12, delta * 20.0)
			if state_t < 0.12:
				melee(Rect2(-30, -92, 222, 62), 22.0, 420.0)
			if state_t >= 0.18:
				set_state("recover_sweep")
				anim("recover_sweep", 0.08, true)
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
			anim("windup_chop", 0.08, true)
			telegraph.flare(Vector2(30, -215), 0.8 * (1.0 if phase == 1 else 0.85), Color(1, 0.3, 0.15))
			telegraph.danger(Rect2(-30, -28, 300, 28), 0.8 * (1.0 if phase == 1 else 0.85))
			Sfx.play("elite_windup", -2.0)
			if phase == 2 and randf() < 0.6:
				chain = "sweep"
		"windup_sweep":
			anim("windup_sweep", 0.08, true)
			telegraph.flare(Vector2(-40, -96), 0.65, Color(1, 0.55, 0.2))
			telegraph.danger(Rect2(-30, -92, 222, 62), 0.65, Color(0.8, 0.3, 0.05, 0.16))
			Sfx.play("elite_windup", -2.0, 0.05, 1.2)
		"lunge":
			vis.set_pose("elite_main", 0.06)
			Sfx.play("elite_step", 0.0)


func _chop() -> void:
	set_state("chop")
	vis.set_pose("elite_attack", 0.02)
	vis.lean = 16.0
	vis.squash = Vector2(1.08, 0.9)
	velocity.x = facing * 160.0
	Sfx.play("elite_chop", 2.0)
	Fx.slash(global_position + Vector2(70 * facing, -110), facing, -120.0, 85.0, 110.0, 40.0, 0.28,
		Color(0.42, 0.12, 0.08), Color(0.95, 0.85, 0.7), 1.0)
	# ground shock (震地): low band around the impact point; jump over it
	var impact := global_position + Vector2(120 * facing, 0)
	Fx.ring(impact + Vector2(0, -4), 10.0, 150.0, Color(0.55, 0.45, 0.32, 0.9), 0.5, 14.0, 0.18)
	Fx.dust(impact, 18)
	Fx.particles(impact, 16, Color(0.25, 0.2, 0.15), 380.0, 60.0, Vector2.UP, 1200.0, 0.6, 6.0)
	Fx.shake(9.0, 0.35)
	Fx.punch(0.035, 0.3)
	var hs := {}
	Combat.strike({"owner": self, "team": team, "rect": Rect2(impact.x - 150, impact.y - 34, 300, 36),
		"damage": 8.0, "poise": 0.0, "knock": 260.0, "dir": facing, "kind": "aoe", "centre": impact,
		"unblockable": true, "tag": "ground_shock"}, hs)


func _sweep() -> void:
	set_state("sweep")
	anim("sweep", 0.02, true)
	vis.lean = 10.0
	velocity.x = facing * 140.0
	Sfx.play("elite_sweep", 1.0)
	Fx.slash(global_position + Vector2(40 * facing, -88), facing, 170.0, 5.0, 135.0, 52.0, 0.32,
		Color(0.48, 0.12, 0.08), Color(0.97, 0.88, 0.72), 0.45)
	Fx.shake(5.0, 0.2)


func _roar() -> void:
	phase = 2
	set_state("roar")
	telegraph.stop()
	anim("roar", 0.06, true)
	vis.rig.skew = 0.0
	Sfx.play("elite_roar", 2.0)
	Fx.ring(global_position + Vector2(0, -120), 20.0, 260.0, Color(0.5, 0.08, 0.05, 0.8), 0.8, 14.0, 0.6)
	Fx.shake(8.0, 0.6)
	phase_changed.emit(2)
	if not summoned:
		summoned = true
		summon_request.emit(2)


func _die(dir := 0) -> void:
	super._die(dir)
	vis.lean = 22.0
	vis.squash = Vector2(1.05, 0.84)
	vis.rig.skew = 0.0
	Sfx.play("elite_die", 2.0)
	anim("dead", 0.1, true)
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
