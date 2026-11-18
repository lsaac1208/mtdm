class_name Enemy
extends Actor
## Shared enemy behaviour: poise/stagger, telegraph helpers, death burn, burn
## damage-over-time from talismans, spawning, and soft crowd separation.
## FSM shape follows docs/05 §2.3-B: Idle/Sealed -> Alert -> Approach ->
## WindUp -> Attack -> Recovery, with HitReaction / Collapse branches.

signal died(enemy)

var enemy_name := "尸祟"
var stagger_pose := ""
var death_pose := ""
var idle_pose := ""
var stagger_time := 0.45
var interrupt_poise := 1.0       # single-hit poise needed to cancel a wind-up
var armored_states: Array = []   # states that ignore stagger unless poise breaks
var uninterruptible_states: Array = []  # states that never stagger
var topple_on_death := true
var attack_hits := {}
var burn := 0.0
var spawn_rise := 0.0
var aggro := false
var leash_left := -1e9
var leash_right := 1e9
var _hurt_cd := 0.0
var _bob_t := 0.0
var _dissolve_t := 0.0
var telegraph: Node2D


func _ready() -> void:
	team = Combat.TEAM_ENEMY
	super._ready()
	if idle_pose != "":
		vis.set_pose(idle_pose, 0.0)
	telegraph = preload("res://scripts/fx/telegraph.gd").new()
	add_child(telegraph)
	if spawn_rise > 0.0:
		vis.dissolve = 1.0
		set_state("spawn")


func player() -> Player:
	var p = Game.player
	if p and is_instance_valid(p) and not p.dead:
		return p
	return null


func dx_to_player() -> float:
	var p := player()
	return (p.global_position.x - global_position.x) if p else 1e9


func dist_to_player() -> float:
	return absf(dx_to_player())


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	state_t += delta
	_hurt_cd = maxf(0.0, _hurt_cd - delta)
	if burn > 0.0 and not dead:
		burn -= delta
		hp -= 3.0 * delta
		if randf() < delta * 14.0:
			Fx.particles(global_position + Vector2(randf_range(-16, 16), -randf_range(20, hurt_size.y)), 1,
				Color(1, 0.7, 0.25, 0.9), 70.0, 30.0, Vector2.UP, -120.0, 0.5, 4.0)
		if hp <= 0.0:
			_die()
	if dead:
		if topple_on_death and _dissolve_t < 0.6:
			# no painted collapse frame: topple backward and sink as the ink burns
			var k := clampf(_dissolve_t / 0.45, 0.0, 1.0)
			vis.lean = lerpf(vis.lean, -68.0, minf(1.0, delta * 9.0))
			vis.bob = -hurt_size.y * 0.1 * k
			vis.squash = Vector2(1.0 + 0.06 * k, 1.0 - 0.1 * k)
		_dissolve_t += delta
		vis.dissolve = clampf((_dissolve_t - 0.5) / 1.1, 0.0, 1.0)
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		apply_gravity(delta)
		move_and_slide()
		if _dissolve_t > 1.8:
			queue_free()
		return
	if state == "spawn":
		vis.dissolve = clampf(1.0 - state_t / spawn_rise, 0.0, 1.0)
		apply_gravity(delta)
		move_and_slide()
		if state_t >= spawn_rise:
			vis.dissolve = 0.0
			aggro = true
			_on_spawned()
		return
	_ai(delta)
	_separate(delta)
	apply_gravity(delta)
	if knock_v != 0.0:
		velocity.x += knock_v
		knock_v = 0.0
	move_and_slide()
	if global_position.x < leash_left:
		global_position.x = leash_left
	elif global_position.x > leash_right:
		global_position.x = leash_right
	vis.facing = facing
	vis.squash = vis.squash.lerp(Vector2.ONE, minf(1.0, delta * 10.0))


func _on_spawned() -> void:
	set_state("chase")


func _ai(_delta: float) -> void:
	pass


func _separate(delta: float) -> void:
	for o in Combat.actors:
		if o == self or o.dead or not is_instance_valid(o):
			continue
		var d: float = global_position.x - o.global_position.x
		var min_d: float = (hurt_size.x + o.hurt_size.x) * 0.38
		if absf(d) < min_d and absf(global_position.y - o.global_position.y) < 80:
			var push := (min_d - absf(d)) * (1.0 if d >= 0 else -1.0)
			if o.team == team:
				global_position.x += push * minf(1.0, delta * 6.0)


# ---------------------------------------------------------------- damage
func receive_hit(atk: Dictionary) -> Dictionary:
	if dead:
		return {}
	hp -= atk.damage
	vis.flash = 0.55
	var dir: int = atk.dir
	if atk.kind == "aoe" and atk.has("centre"):
		dir = 1 if global_position.x >= atk.centre.x else -1
	Fx.hit_ink(global_position + Vector2(0, -hurt_size.y * 0.55), dir)
	Fx.slash(global_position + Vector2(0, -hurt_size.y * 0.55), dir, -20.0, 20.0, 18.0, 10.0, 0.12,
		Color(0.9, 0.85, 0.75), Color(1, 1, 1), 1.0)
	Sfx.play(_hit_sound(atk), -2.0)
	vis.jitter = 0.15
	vis.squash = Vector2(0.9, 1.08)
	if atk.kind != "hazard":
		Fx.splat(global_position + Vector2(dir * randf_range(10, 40), 0), 10.0 + atk.damage * 0.6)
	if atk.damage >= 16.0:
		Fx.punch(0.025, 0.18)
	on_hurt(atk)
	if hp <= 0.0:
		_die(dir)
		return {"killed": true}
	if uninterruptible_states.has(state):
		vis.nudge.x = -4.0
		return {"armored": true}
	poise -= atk.poise
	var interrupt: bool = atk.poise >= interrupt_poise and state == "windup"
	if poise <= 0.0 or (interrupt and not armored_states.has(state)) or (not armored_states.has(state) and poise_breaks_on_any()):
		poise = max_poise
		stagger(stagger_time, dir, atk.knock)
		return {"staggered": true}
	# armoured: tiny flinch only
	vis.nudge.x = -6.0
	knock_v = dir * atk.knock * 0.15
	return {"armored": true}


func _hit_sound(atk: Dictionary) -> String:
	return "hit_flesh" if atk.kind != "aoe" else "hit_heavy"


## Low-poise units stagger on every hit (spec: 普攻即硬直).
func poise_breaks_on_any() -> bool:
	return max_poise <= 10.0


func on_hurt(_atk: Dictionary) -> void:
	pass


func stagger(dur: float, dir: int, knock: float) -> void:
	set_state("stagger")
	attack_hits = {}
	telegraph.stop()
	stagger_time_left = dur
	knock_v = dir * knock
	velocity.x = 0.0
	face_toward(global_position.x - dir * 10)
	if stagger_pose != "":
		vis.set_pose(stagger_pose, 0.03)
	vis.lean = -8.0
	aggro = true


var stagger_time_left := 0.0


func update_stagger(delta: float) -> bool:
	if state != "stagger":
		return false
	velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
	vis.lean = lerpf(vis.lean, 0.0, delta * 6.0)
	if state_t >= stagger_time_left:
		set_state("chase")
		vis.lean = 0.0
	return true


func on_parried() -> void:
	poise = max_poise
	stagger(0.9, -facing, 140.0)
	Fx.float_text(global_position + Vector2(0, -hurt_size.y - 30), "破绽", Color(1, 0.85, 0.5), 24)


func ignite(dur: float) -> void:
	burn = maxf(burn, dur)


func _die(dir := 0) -> void:
	if dead:
		return
	dead = true
	set_state("dead")
	telegraph.stop()
	still_anim()
	collision_layer = 0
	if death_pose != "":
		vis.set_pose(death_pose, 0.05)
	knock_v = dir * 160.0
	Game.kills += 1
	Sfx.play("enemy_die", -2.0)
	Fx.ash(global_position + Vector2(0, -hurt_size.y * 0.5), 26)
	Fx.splat(global_position, 34.0, Color(0.08, 0.05, 0.04, 0.85))
	Game.hitstop(0.06)
	var p := player()
	if p:
		p.on_kill(self)
	died.emit(self)


## Melee helper used by subclasses during active frames.
func melee(r: Rect2, dmg: float, knock: float, extra := {}) -> Array:
	return strike(r, dmg, 0.0, knock, attack_hits, extra)


func walk_anim(delta: float, speed_ratio: float, rate := 7.0, amp := 0.04) -> void:
	_bob_t += delta * rate * speed_ratio
	vis.phase = _bob_t
	vis.stride = amp * 0.3 * speed_ratio
	vis.legs = 0.3 * speed_ratio * clampf(amp / 0.04, 0.5, 1.5)
	vis.leg_lift = 0.5 * speed_ratio
	var L := hurt_size.y * vis.hip_frac
	vis.bob = -L * (1.0 - cos(vis.legs * sin(_bob_t))) + absf(cos(_bob_t)) * 1.5 * speed_ratio


func still_anim() -> void:
	vis.stride = 0.0
	vis.legs = 0.0
	vis.leg_lift = 0.0
	vis.bob = 0.0
