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
var stagger_clip := "hit"
var death_clip := ""
var stagger_time := 0.45
var interrupt_poise := 1.0       # single-hit poise needed to cancel a wind-up
var armored_states: Array = []   # states that ignore stagger unless poise breaks
var uninterruptible_states: Array = []  # states that never stagger
var topple_on_death := true
var rig_type := ""
var hit_material := "flesh"     # flesh / paper / taint / armor (hit VFX)
var walk_speed := 100.0


func _make_visual() -> PoseSprite:
	var clips := EnemyClips.for_type(rig_type)
	if clips.is_empty():
		return PoseSprite.new()
	var rv := RigVisual.new()
	rv.rig_dir = "res://assets/rig/" + rig_type
	rv.clip_set = clips
	rv.pose_map = EnemyClips.pose_map(rig_type)
	rv.walk_speed = walk_speed
	return rv


## Play a rig clip when this enemy has a rig (no-op for painted-only enemies).
func anim(clip: String, blend := 0.1, restart := false) -> void:
	if vis is RigVisual:
		vis.play_clip(clip, blend, restart)


## Play a FrameAnim clip when available, otherwise fall back cleanly to the
## painted pose (or the cutout rig clip if no painted fallback pose is given).
func play_pose_or_clip(clip: String, fallback_pose: String, blend := 0.06, restart := true) -> void:
	if vis is RigVisual:
		var rv := vis as RigVisual
		if rv.has_frame_clip(clip):
			rv.play_clip(clip, blend, restart)
			return
	if fallback_pose != "":
		vis.set_pose(fallback_pose, blend)
	elif vis is RigVisual:
		(vis as RigVisual).play_clip(clip, blend, restart)


var attack_hits := {}
var burn := 0.0
var spawn_rise := 0.0
var aggro := false
var leash_left := -1e9
var leash_right := 1e9
var _hurt_cd := 0.0
var _bob_t := 0.0
var _wall_t := 0.0
var _dissolve_t := 0.0
var telegraph: Node2D
var _mini_bar: MiniBar = null


func _ready() -> void:
	team = Combat.TEAM_ENEMY
	super._ready()
	if idle_pose != "":
		vis.set_pose(idle_pose, 0.0)
	telegraph = preload("res://scripts/fx/telegraph.gd").new()
	add_child(telegraph)
	if rig_type != "elite":
		_mini_bar = MiniBar.new()
		_mini_bar.owner_enemy = self
		_mini_bar.bar_w = clampf(40.0 + max_hp * 0.22, 44.0, 60.0)
		_mini_bar.position = Vector2(0.0, -hurt_size.y - 14.0)
		_mini_bar.z_index = 18
		add_child(_mini_bar)
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
	if vis is RigVisual:
		vis.locomotion_speed = absf(velocity.x)
	_ai(delta)
	_separate(delta)
	apply_gravity(delta)
	if knock_v != 0.0:
		velocity.x += knock_v
		knock_v = 0.0
	var want_vx := velocity.x
	move_and_slide()
	# blocked by a ledge while trying to move: hop onto it (prevents soft-locks)
	if is_on_floor() and is_on_wall() and absf(want_vx) > 20.0 and state in ["chase", "lunge", "retreat", "wander"]:
		_wall_t += get_physics_process_delta_time()
		if _wall_t > 0.15:
			_wall_t = 0.0
			velocity.y = -680.0
			velocity.x = want_vx
			vis.squash = Vector2(0.9, 1.1)
			Fx.dust(global_position, 5)
	else:
		_wall_t = 0.0
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
		if o.team != team:
			continue
		var d: float = global_position.x - o.global_position.x
		var min_d: float = (hurt_size.x + o.hurt_size.x) * 0.42
		if absf(d) < min_d and absf(global_position.y - o.global_position.y) < 80:
			# exact ties resolve by instance id so the pair splits instead of
			# both stepping the same way
			var side := signf(d) if absf(d) > 0.5 else (1.0 if get_instance_id() > o.get_instance_id() else -1.0)
			var want := (min_d - absf(d)) * side * minf(1.0, delta * 6.0)
			var moved := _safe_nudge_x(self, want, leash_left, leash_right)
			# pinned against a wall / ledge / leash: shove the neighbour instead,
			# otherwise a pack piles into one unreadable blob at an obstacle
			var rem := want - moved
			if absf(rem) > 0.05 and o is Enemy:
				_safe_nudge_x(o, -rem, o.leash_left, o.leash_right)
	_keep_personal_space(delta)


## Queueing: true when a living ally already stands between this enemy and
## the hero within `spacing` px (default: shoulder to shoulder). Chasers hold
## their slot instead of walking into that ally, so a pack forms a readable
## line and takes turns rather than collapsing into one stacked silhouette.
func ally_ahead(spacing := -1.0, behind := false) -> bool:
	var p := player()
	if p == null:
		return false
	var my_d := absf(global_position.x - p.global_position.x)
	for o in Combat.actors:
		if o == self or not (o is Enemy) or o.dead or not is_instance_valid(o) or o.team != team:
			continue
		if absf(o.global_position.y - global_position.y) > 80.0:
			continue
		var rel: float = o.global_position.x - global_position.x
		var dir := -float(facing) if behind else float(facing)
		if signf(rel) != dir and absf(rel) > 0.5:
			continue
		var gap: float = spacing if spacing > 0.0 else (hurt_size.x + o.hurt_size.x) * 0.55
		var o_d := absf(o.global_position.x - p.global_position.x)
		if absf(rel) < gap and ((not behind and o_d < my_d - 0.5) or (behind and o_d > my_d + 0.5)):
			return true
	return false


func _safe_nudge_x(body: CharacterBody2D, dx: float, min_x := -1e9, max_x := 1e9) -> float:
	if absf(dx) < 0.001:
		return 0.0
	var target_x := clampf(body.global_position.x + dx, min_x, max_x)
	var want := target_x - body.global_position.x
	if absf(want) < 0.001:
		return 0.0
	var col := KinematicCollision2D.new()
	var blocked := body.test_move(body.global_transform.translated(Vector2(0.0, -2.0)), Vector2(want, 0.0), col)
	var actual := want
	if blocked and absf(col.get_normal().x) > 0.4:
		var travel := col.get_travel().x
		actual = travel if signf(travel) == signf(want) else 0.0
	body.global_position.x += actual
	return actual


## Bodies of the hero and an upright enemy should not sink into each other:
## two full painted figures on top of one another hide both the telegraph and
## the strike. In open ground only the enemy yields (neutral states); if the
## enemy is pinned against a wall, platform, barrier or leash, the grounded
## hero absorbs the un-yielded remainder. Never active during dash or while
## airborne, so attack windows, dash-through and jump-over keep their timing.
const _YIELD_STATES := ["chase", "alert", "idle", "wander", "detect", "recover", "stagger", "retreat"]


func _keep_personal_space(delta: float) -> void:
	var p = Game.player
	if p == null or not is_instance_valid(p) or p.dead or hurt_size.y < 100.0:
		return
	if not (state in _YIELD_STATES) or p.state in ["dash", "dash_attack"]:
		return
	if absf(global_position.y - p.global_position.y) > 24.0:
		return
	var d: float = global_position.x - p.global_position.x
	var min_d: float = (hurt_size.x + p.hurt_size.x) * 0.42
	if absf(d) < min_d:
		var side := 1.0 if d > 0.5 else (-1.0 if d < -0.5 else 0.0)
		if side == 0.0:
			var wall_r := global_position.x + 4.0 > leash_right or test_move(global_transform.translated(Vector2(0.0, -2.0)), Vector2(4.0, 0.0))
			var wall_l := global_position.x - 4.0 < leash_left or test_move(global_transform.translated(Vector2(0.0, -2.0)), Vector2(-4.0, 0.0))
			if wall_r and not wall_l:
				side = 1.0
			elif wall_l and not wall_r:
				side = -1.0
			else:
				side = float(p.facing) if p.facing != 0 else 1.0
		var overlap := min_d - absf(d)
		var want := overlap * side * minf(1.0, delta * 30.0)
		var moved := _safe_nudge_x(self, want, leash_left, leash_right)
		var rem := want - moved
		if absf(rem) > 0.05 and p.is_on_floor() and p.state != "hit":
			var push_p := minf(overlap - absf(moved), absf(rem) * 1.85) * (-side)
			_safe_nudge_x(p, push_p)


# ---------------------------------------------------------------- damage
func receive_hit(atk: Dictionary) -> Dictionary:
	if dead:
		return {}
	hp -= atk.damage
	vis.flash = 0.55
	var dir: int = atk.dir
	if atk.kind == "aoe" and atk.has("centre"):
		dir = 1 if global_position.x >= atk.centre.x else -1
	var tag: String = String(atk.get("tag", "slash1"))
	var heavy: bool = atk.damage >= 16.0 or tag in ["slash3", "down", "beads"]
	var hit_pos := global_position + Vector2(-dir * hurt_size.x * 0.22, -hurt_size.y * 0.56)
	var impact_col := Fx.C_GOLD if tag in ["talisman", "beads"] else Fx.C_CINNABAR
	Fx.material_hit(hit_pos, dir, hit_material, heavy)
	if atk.kind != "hazard":
		Fx.hit_impact(hit_pos, dir, tag, heavy, impact_col, Fx.C_GOLD)
	Sfx.play(_hit_sound(atk), -2.0)
	vis.hit_shake(dir, 9.5 if heavy else 6.2, 0.16 if heavy else 0.12)
	vis.squash = Vector2(0.84, 1.14) if heavy else Vector2(0.90, 1.09)
	if atk.kind != "hazard":
		Fx.splat(global_position + Vector2(dir * randf_range(10, 40), 0), 10.0 + atk.damage * 0.6)
	if atk.damage >= 16.0:
		Fx.punch(0.025, 0.18)
	var armored_hit: bool = hp > 0.0 and (uninterruptible_states.has(state) or (armored_states.has(state) and poise - float(atk.poise) > 0.0))
	if atk.kind != "hazard" and atk.damage >= 1.0:
		var num_style := "normal"
		if hp <= 0.0 or tag in ["slash3", "beads"]:
			num_style = "finisher"
		elif tag == "talisman":
			num_style = "talisman"
		elif armored_hit:
			num_style = "armor"
		elif atk.damage >= 14.0:
			num_style = "heavy"
		Fx.damage_number(global_position + Vector2(0.0, -hurt_size.y - 12.0), atk.damage, dir, num_style)
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
	var tag: String = String(atk.get("tag", ""))
	if atk.kind == "aoe" or float(atk.damage) >= 16.0 or tag in ["slash3", "down", "beads"]:
		return "hit_heavy"
	return "hit_flesh"


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
	if stagger_clip != "":
		play_pose_or_clip(stagger_clip, stagger_pose, 0.03, true)
	elif stagger_pose != "":
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
	if death_clip != "":
		play_pose_or_clip(death_clip, death_pose, 0.05, true)
	elif death_pose != "":
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


## Swing the weapon arm from r0 to r1 over `dur` seconds of the current state (ease-out).
func swing_arm(r0: float, r1: float, dur: float) -> void:
	var k := clampf(state_t / maxf(dur, 0.01), 0.0, 1.0)
	vis.arm_rot = [lerpf(r0, r1, 1.0 - pow(1.0 - k, 3.0)), 0.0]


## Melee helper used by subclasses during active frames.
func melee(r: Rect2, dmg: float, knock: float, extra := {}) -> Array:
	return strike(r, dmg, 0.0, knock, attack_hits, extra)


func walk_anim(delta: float, speed_ratio: float, rate := 7.0, amp := 0.04) -> void:
	if vis is RigVisual and (vis as RigVisual).frame_on:
		vis.bob = 0.0
		return
	_bob_t += delta * rate * speed_ratio
	vis.phase = _bob_t
	vis.stride = amp * 0.3 * speed_ratio
	vis.legs = 0.3 * speed_ratio * clampf(amp / 0.04, 0.5, 1.5)
	vis.leg_lift = 0.5 * speed_ratio
	vis.torso_twist = -0.04 * speed_ratio
	vis.arm_rot = [0.16 * speed_ratio * sin(_bob_t), -0.12 * speed_ratio * sin(_bob_t)]
	var L := hurt_size.y * vis.hip_frac
	vis.bob = -L * (1.0 - cos(vis.legs * sin(_bob_t))) + absf(cos(_bob_t)) * 1.5 * speed_ratio


func still_anim() -> void:
	vis.torso_twist = 0.0
	vis.arm_rot = [0.0, 0.0]
	vis.stride = 0.0
	vis.legs = 0.0
	vis.leg_lift = 0.0
	vis.bob = 0.0


## Diegetic world-space mini HP / poise bar for non-boss enemies.
class MiniBar extends Node2D:
	var owner_enemy: Enemy = null
	var bar_w: float = 48.0
	var bar_h: float = 5.0
	var _bar_lag: float = 1.0
	var _prev_ratio: float = 1.0
	var _lag_hold: float = 0.0
	var _alpha: float = 0.0
	var _pulse_t: float = 0.0

	func _ready() -> void:
		visible = false

	func _process(delta: float) -> void:
		if owner_enemy == null or not is_instance_valid(owner_enemy):
			return
		var dt: float = Game.unscaled_delta(delta)
		var max_h: float = maxf(owner_enemy.max_hp, 1.0)
		var ratio: float = clampf(owner_enemy.hp / max_h, 0.0, 1.0)
		if ratio < _prev_ratio - 0.001:
			_bar_lag = maxf(_bar_lag, _prev_ratio)
			_lag_hold = 0.14
		_prev_ratio = ratio
		if _lag_hold > 0.0:
			_lag_hold = maxf(0.0, _lag_hold - dt)
		else:
			_bar_lag = move_toward(_bar_lag, ratio, dt * 1.35)
		if owner_enemy.dead:
			_alpha = move_toward(_alpha, 0.0, dt * 4.2)
		elif owner_enemy.hp < owner_enemy.max_hp - 0.01 or owner_enemy.burn > 0.0:
			_alpha = move_toward(_alpha, 1.0, dt * 8.5)
		else:
			_alpha = move_toward(_alpha, 0.0, dt * 4.0)
		_pulse_t += dt
		visible = _alpha > 0.01
		if visible:
			queue_redraw()

	func _draw() -> void:
		if _alpha <= 0.01 or owner_enemy == null:
			return
		var a: float = _alpha
		var w: float = bar_w
		var h: float = bar_h
		var x0: float = -w * 0.5
		var y0: float = -h * 0.5
		var ratio: float = clampf(owner_enemy.hp / maxf(owner_enemy.max_hp, 1.0), 0.0, 1.0)
		var burning: bool = owner_enemy.burn > 0.0 and not owner_enemy.dead
		var burn_pulse: float = 0.5 + 0.5 * sin(_pulse_t * 14.0)

		# Soft ink shadow + warm ink-black backing
		draw_rect(Rect2(x0 - 2.0, y0 - 1.5, w + 4.0, h + 3.5), Color(0.04, 0.03, 0.025, 0.45 * a), true)
		draw_rect(Rect2(x0, y0, w, h), Color(0.09, 0.075, 0.065, 0.90 * a), true)

		# Smooth ivory damage-lag trail
		var lag_w: float = clampf(_bar_lag, 0.0, 1.0) * w
		if lag_w > 0.5:
			draw_rect(Rect2(x0, y0, lag_w, h), Color(0.95, 0.90, 0.78, 0.88 * a), true)

		# Crimson HP fill (shifts toward glowing cinnabar when burning)
		var fill_w: float = ratio * w
		if fill_w > 0.5:
			var hp_col := Color(0.76, 0.14, 0.10, 0.96 * a)
			if burning:
				hp_col = hp_col.lerp(Color(0.98, 0.40, 0.11, 0.98 * a), 0.45 + 0.45 * burn_pulse)
			draw_rect(Rect2(x0, y0, fill_w, h), hp_col, true)
			draw_rect(Rect2(x0, y0, fill_w, 1.2), Color(1.0, 0.78, 0.58, (0.28 + (0.20 if burning else 0.0)) * a), true)

		# Faint aged-brass 1 px border (warmed cinnabar while burning)
		var border_col := Color(0.95, 0.48, 0.18, 0.88 * a) if burning else Color(0.68, 0.56, 0.36, 0.78 * a)
		draw_rect(Rect2(x0 - 0.5, y0 - 0.5, w + 1.0, h + 1.0), border_col, false, 1.0)

		# Subtle burn flame icon on right edge during Talisman DoT
		if burning:
			var fx: float = x0 + w + 5.5
			var fy: float = 1.0
			var fh: float = 5.5 + 1.8 * burn_pulse
			var fw: float = 2.6 + 0.5 * burn_pulse
			draw_colored_polygon(PackedVector2Array([
				Vector2(fx, fy - fh),
				Vector2(fx + fw, fy - 0.5),
				Vector2(fx, fy + 2.2),
				Vector2(fx - fw, fy - 0.5),
			]), Color(0.94, 0.32, 0.10, 0.92 * a))
			draw_colored_polygon(PackedVector2Array([
				Vector2(fx, fy - fh * 0.62),
				Vector2(fx + fw * 0.5, fy),
				Vector2(fx, fy + 1.3),
				Vector2(fx - fw * 0.5, fy),
			]), Color(1.0, 0.88, 0.44, 0.96 * a))

		# Subtle golden poise bar underneath for armored/multi-poise enemies
		if owner_enemy.max_poise > 10.0:
			var py: float = y0 + h + 2.5
			var pr: float = clampf(owner_enemy.poise / maxf(owner_enemy.max_poise, 1.0), 0.0, 1.0)
			if owner_enemy.state == "stagger":
				pr = 0.0
			draw_rect(Rect2(x0, py, w, 2.0), Color(0.08, 0.065, 0.055, 0.80 * a), true)
			if pr > 0.01:
				draw_rect(Rect2(x0, py, w * pr, 2.0), Color(0.92, 0.74, 0.30, 0.92 * a), true)
