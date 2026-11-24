extends Enemy
## 03 封印残尸·残法衣尸祟 Talisman-Bound Husk — 144 px, hurtbox 50x138,
## slow 65 px/s, medium-high poise (small super armour). Stands sealed and
## still until approached (or struck). Repeated close-range hits build its
## seal pressure; at 4 it triggers 符力溃散 — an unblockable 110 px backlash.
## Not a caster: the burst is a passive seal failure, not a spell (spec §4.1).

const SEAL_LIMIT := 4
var seal := 0
var seal_decay := 0.0
var cd := 0.0
var awake := false
var _seal_fx: SealCrackIndicator = null


func _init() -> void:
	hit_material = "paper"
	rig_type = "husk"
	walk_speed = 65.0
	enemy_name = "封印残尸"
	max_hp = 90.0
	max_poise = 60.0
	hurt_size = Vector2(50, 138)
	idle_pose = "husk_idle"
	stagger_pose = "husk_hit"
	death_pose = "husk_collapse"
	death_clip = "collapse"
	stagger_time = 0.6
	interrupt_poise = 30.0
	uninterruptible_states = ["burst_prep", "burst", "awaken"]
	topple_on_death = false
	shadow_w = 60.0


func _ready() -> void:
	super._ready()
	facing = -1
	_seal_fx = SealCrackIndicator.new()
	_seal_fx.position = Vector2(4.0 * facing, -96.0)
	_seal_fx.z_index = 14
	add_child(_seal_fx)
	if state != "spawn":
		set_state("sealed")
		vis.tint = Color(0.82, 0.8, 0.76)


func _on_spawned() -> void:
	_awaken()


func _awaken() -> void:
	if awake:
		return
	awake = true
	aggro = true
	set_state("awaken")
	vis.tint = Color.WHITE
	play_pose_or_clip("awaken", "husk_awaken", 0.08, true)
	Sfx.play("seal_crack", 0.0)
	Fx.particles(global_position + Vector2(0, -110), 18, Color(0.85, 0.72, 0.35), 200.0, 120.0, Vector2.UP, 250.0, 1.0, 6.0)
	Fx.ring(global_position + Vector2(0, -80), 10.0, 90.0, Color(0.6, 0.15, 0.1, 0.7), 0.5, 6.0, 0.8)


func on_hurt(atk: Dictionary) -> void:
	if not awake:
		_awaken()
	if atk.kind == "melee":
		seal += 1
		seal_decay = 2.4
		telegraph.flare(Vector2(6, -98), 0.35 + seal * 0.08, Color(0.95, 0.65, 0.2) if seal < SEAL_LIMIT - 1 else Color(1, 0.25, 0.1))
		if seal >= SEAL_LIMIT and state != "burst_prep" and state != "burst":
			_burst_prep()
		if _seal_fx != null:
			_seal_fx.sync(seal, SEAL_LIMIT, state == "burst_prep", state_t, dead, facing)


func _burst_prep() -> void:
	seal = 0
	set_state("burst_prep")
	velocity.x = 0.0
	play_pose_or_clip("awaken", "husk_awaken", 0.04, true)
	var prep_t := Game.tele(0.5)
	telegraph.flare(Vector2(4, -100), prep_t, Color(1, 0.2, 0.1))
	telegraph.danger(Rect2(-120, -40, 240, 40), prep_t, Color(0.85, 0.55, 0.1, 0.25))
	Sfx.play("seal_charge", 0.0)


func _ai(delta: float) -> void:
	cd = maxf(0.0, cd - delta)
	if seal_decay > 0.0:
		seal_decay -= delta
		if seal_decay <= 0.0 and seal > 0:
			seal -= 1
			seal_decay = 1.0 if seal > 0 else 0.0
	if _seal_fx != null:
		_seal_fx.sync(seal, SEAL_LIMIT, state == "burst_prep", state_t, dead, facing)
	if seal >= SEAL_LIMIT - 1 and not dead and state != "burst_prep" and state != "burst":
		if randf() < delta * 8.0:
			Fx.particles(global_position + Vector2(randf_range(-14.0, 14.0) + 4.0 * facing, -randf_range(78.0, 114.0)),
				1, Color(1.0, 0.52, 0.16, 0.92), 95.0, 140.0, Vector2.UP, -40.0, 0.32, 3.6, 14)
	if state == "burst_prep":
		velocity.x = 0.0
		vis.nudge.x = sin(state_t * 70.0) * 3.0
		vis.squash = Vector2(1.0 + state_t * 0.12, 1.0 + state_t * 0.06)
		if randf() < delta * 30.0:
			Fx.particles(global_position + Vector2(randf_range(-30, 30), -randf_range(40, 130)), 1,
				Color(0.95, 0.75, 0.3), 60.0, 180.0, Vector2.UP, 0.0, 0.4, 5.0)
		if state_t >= Game.tele(0.5):
			_burst()
		return
	if state == "burst":
		velocity.x = 0.0
		if state_t >= 0.85:
			set_state("chase")
		return
	if update_stagger(delta):
		return
	var p := player()
	var dx := dx_to_player()
	match state:
		"sealed":
			velocity.x = 0.0
			still_anim()
			vis.sway = 0.002
			if p and absf(dx) < 230.0:
				_awaken()
		"awaken":
			velocity.x = 0.0
			vis.nudge.x = sin(state_t * 55.0) * 2.5 * (1.0 - state_t)
			if state_t >= 0.9:
				vis.nudge.x = 0.0
				set_state("chase")
		"chase":
			vis.sway = 0.006
			if not p:
				velocity.x = 0.0
				return
			face_toward(p.global_position.x)
			vis.set_pose("husk_walk", 0.1)
			if absf(dx) > 112.0:
				velocity.x = facing * 65.0
				walk_anim(delta, 1.0, 4.5, 0.03)
			else:
				velocity.x = 0.0
				still_anim()
				if cd <= 0.0:
					set_state("windup")
					play_pose_or_clip("windup", "husk_side", 0.06, true)
					telegraph.flare(Vector2(40, -110), Game.tele(0.55))
					Sfx.play("husk_groan", -4.0)
		"windup":
			velocity.x = 0.0
			vis.lean = lerpf(vis.lean, -9.0, delta * 6.0)
			if state_t >= Game.tele(0.55):
				set_state("attack")
				attack_hits = {}
				play_pose_or_clip("attack", "husk_strike", 0.03, true)
				vis.lean = 6.0
				velocity.x = facing * 120.0
				Sfx.play("sleeve", -2.0)
				Fx.slash(global_position + Vector2(40 * facing, -95), facing, -60.0, 60.0, 70.0, 26.0, 0.25,
					Color(0.3, 0.26, 0.2), Color(0.7, 0.62, 0.45), 0.8)
		"attack":
			swing_arm(-0.6, 0.45, 0.16)
			velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
			if state_t < 0.16:
				melee(Rect2(8, -142, 122, 118), 18.0, 320.0)
			if state_t >= 0.3:
				set_state("recover")
				vis.set_pose("husk_idle", 0.12)
				vis.lean = 0.0
		"recover":
			velocity.x = 0.0
			vis.arm_rot = [0.0, 0.0]
			if state_t >= 0.75:
				cd = 0.9
				set_state("chase")


func _burst() -> void:
	set_state("burst")
	play_pose_or_clip("burst", "husk_burst", 0.02, true)
	vis.nudge.x = 0.0
	vis.squash = Vector2(1.15, 0.92)
	Sfx.play("seal_burst", 2.0)
	Fx.shake(7.0, 0.3)
	Game.hitstop(0.07)
	Fx.ring(global_position + Vector2(0, -60), 20.0, 130.0, Color(0.85, 0.6, 0.15, 0.95), 0.45, 18.0, 0.7)
	Fx.ring(global_position + Vector2(0, -60), 10.0, 115.0, Color(0.45, 0.06, 0.04, 0.9), 0.35, 10.0, 0.7)
	Fx.particles(global_position + Vector2(0, -90), 40, Color(0.9, 0.7, 0.3), 420.0, 180.0, Vector2.UP, 300.0, 0.8, 6.0)
	var hs := {}
	Combat.strike({"owner": self, "team": team, "rect": Rect2(global_position.x - 115, global_position.y - 165, 230, 170),
		"damage": 22.0, "poise": 0.0, "knock": 520.0, "dir": facing, "kind": "aoe", "centre": global_position,
		"unblockable": true, "tag": "seal_burst"}, hs)


func _die(dir := 0) -> void:
	super._die(dir)
	if _seal_fx != null:
		_seal_fx.sync(0, SEAL_LIMIT, false, 0.0, true, facing)
	Fx.particles(global_position + Vector2(0, -90), 30, Color(0.85, 0.72, 0.35), 240.0, 160.0, Vector2.UP, 300.0, 1.4, 7.0)


## Diegetic chest talisman seal-crack warning indicator for 符力溃散 buildup.
class SealCrackIndicator extends Node2D:
	var seal_lvl: int = 0
	var seal_max: int = 4
	var in_prep: bool = false
	var prep_t: float = 0.0
	var is_dead: bool = false
	var dir: int = -1
	var _t: float = 0.0
	var _alpha: float = 0.0

	func sync(s: int, s_max: int, prep: bool, pt: float, dead_flag: bool, facing_dir: int) -> void:
		seal_lvl = s
		seal_max = maxi(s_max, 2)
		in_prep = prep
		prep_t = pt
		is_dead = dead_flag
		dir = facing_dir

	func _ready() -> void:
		visible = false

	func _process(delta: float) -> void:
		var dt: float = Game.unscaled_delta(delta)
		_t += dt
		position = Vector2(4.0 * float(dir), -96.0)
		var active: bool = not is_dead and (seal_lvl > 0 or in_prep)
		_alpha = move_toward(_alpha, 1.0 if active else 0.0, dt * (9.0 if active else 5.0))
		visible = _alpha > 0.01
		if visible:
			queue_redraw()

	func _draw() -> void:
		if _alpha <= 0.01:
			return
		var a: float = _alpha
		var lvl: int = seal_max if in_prep else clampi(seal_lvl, 0, seal_max)
		var danger: bool = in_prep or lvl >= seal_max - 1
		var warn: bool = lvl >= 2 or in_prep
		var pulse_spd: float = 19.0 if in_prep else (13.0 if danger else (7.5 if warn else 4.5))
		var pulse: float = 0.5 + 0.5 * sin(_t * pulse_spd)
		var cinnabar := Color(0.86, 0.18, 0.09)
		var gold := Color(0.98, 0.78, 0.32)
		var ivory := Color(1.0, 0.95, 0.80)

		# Soft painterly ember aura on the chest talisman
		var glow_r: float = (11.0 + float(lvl) * 3.8 + (6.0 * clampf(prep_t / 0.5, 0.0, 1.0) if in_prep else 0.0)) * (0.92 + 0.14 * pulse)
		var glow_col := cinnabar.lerp(gold, 0.25 if danger else 0.65)
		draw_circle(Vector2.ZERO, glow_r * 1.45, Color(glow_col.r, glow_col.g, glow_col.b, (0.14 + 0.07 * float(lvl)) * a))
		draw_circle(Vector2.ZERO, glow_r * 0.65, Color(ivory.r, ivory.g, ivory.b, (0.24 + 0.10 * float(lvl)) * (0.7 + 0.3 * pulse) * a))

		# Small vertical talisman seal core with hairline fracture
		var core_h: float = 8.5 + float(lvl) * 1.1
		var core_w: float = 3.2
		draw_rect(Rect2(-core_w, -core_h, core_w * 2.0, core_h * 2.0), Color(0.10, 0.06, 0.04, 0.55 * a), true)
		draw_rect(Rect2(-core_w + 0.8, -core_h + 0.8, (core_w - 0.8) * 2.0, (core_h - 0.8) * 2.0),
			Color(gold.r, gold.g, gold.b, (0.45 + 0.14 * float(lvl)) * a), false, 1.2)

		# Cracking cinnabar-gold talisman fissures proportional to accumulated hits
		var crack_count: int = 2 if lvl == 1 else (4 if lvl == 2 else (6 if lvl == 3 else 8))
		var crack_reach: float = 11.0 + float(lvl) * 5.2 + (8.0 * clampf(prep_t / 0.5, 0.0, 1.0) if in_prep else 0.0)
		var jitter_step: int = int(floor(_t * (14.0 if danger else 8.0)))
		for i in crack_count:
			var base_ang: float = TAU * float(i) / float(crack_count) + 0.35 + (0.18 * sin(float(jitter_step + i * 7)) if warn else 0.0)
			var dir_v := Vector2(cos(base_ang), sin(base_ang))
			var perp_v := Vector2(-dir_v.y, dir_v.x)
			var p0 := dir_v * 3.5
			var mid_off: float = sin(float(i * 13 + jitter_step)) * (3.2 if danger else 2.0)
			var p1 := dir_v * (crack_reach * 0.54) + perp_v * mid_off
			var p2 := dir_v * crack_reach - perp_v * (mid_off * 0.65)
			var c_col := cinnabar.lerp(gold, 0.35 if danger else 0.72)
			draw_polyline(PackedVector2Array([p0, p1, p2]), Color(0.08, 0.04, 0.03, 0.58 * a), 3.0 if danger else 2.2, true)
			draw_polyline(PackedVector2Array([p0, p1, p2]), Color(c_col.r, c_col.g, c_col.b, (0.78 + 0.20 * pulse) * a), 1.8 if danger else 1.3, true)
			if warn:
				draw_line(p0, p1, Color(ivory.r, ivory.g, ivory.b, (0.65 + 0.30 * pulse) * a), 0.9, true)

		# Pulsing golden-red warning ring when seal buildup reaches 2+ hits (escalates sharply at 3 / burst_prep)
		if warn:
			var ring_r: float = (18.0 if lvl == 2 else (24.0 if not in_prep else lerpf(24.0, 38.0, clampf(prep_t / 0.5, 0.0, 1.0)))) * (0.94 + 0.10 * pulse)
			var segs: int = 24
			var r_col := gold.lerp(cinnabar, 0.42 if lvl == 2 else (0.76 if not in_prep else 0.92))
			var r_alpha: float = (0.52 if lvl == 2 else 0.88) * (0.72 + 0.28 * pulse) * a
			var pts := PackedVector2Array()
			for i in segs + 1:
				var ang: float = TAU * float(i) / float(segs)
				pts.append(Vector2(cos(ang) * ring_r, sin(ang) * ring_r))
			draw_polyline(pts, Color(0.08, 0.04, 0.03, r_alpha * 0.55), (3.8 if danger else 2.6), true)
			draw_polyline(pts, Color(r_col.r, r_col.g, r_col.b, r_alpha), (2.2 if danger else 1.5), true)
			if danger:
				# Orbiting talisman warning ticks
				var ticks: int = 6 if not in_prep else 8
				var rot_off: float = _t * (2.6 if not in_prep else 5.2)
				for i in ticks:
					var tang: float = rot_off + TAU * float(i) / float(ticks)
					var tv := Vector2(cos(tang), sin(tang))
					var sp_p := tv * (ring_r + 3.0)
					draw_line(tv * (ring_r - 2.5), sp_p + tv * 3.5, Color(ivory.r, ivory.g, ivory.b, 0.90 * a), 1.6, true)
					draw_circle(sp_p, 1.8, Color(gold.r, gold.g, gold.b, 0.92 * a))
