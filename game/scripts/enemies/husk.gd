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


func _init() -> void:
	rig_type = "husk"
	walk_speed = 65.0
	enemy_name = "封印残尸"
	max_hp = 90.0
	max_poise = 60.0
	hurt_size = Vector2(50, 138)
	idle_pose = "husk_idle"
	stagger_pose = "husk_hit"
	death_pose = "husk_collapse"
	stagger_time = 0.6
	interrupt_poise = 30.0
	uninterruptible_states = ["burst_prep", "burst", "awaken"]
	topple_on_death = false
	shadow_w = 60.0


func _ready() -> void:
	super._ready()
	facing = -1
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
	vis.set_pose("husk_awaken", 0.08)
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


func _burst_prep() -> void:
	seal = 0
	set_state("burst_prep")
	velocity.x = 0.0
	vis.set_pose("husk_awaken", 0.04)
	telegraph.flare(Vector2(4, -100), 0.5, Color(1, 0.2, 0.1))
	telegraph.danger(Rect2(-120, -40, 240, 40), 0.5, Color(0.85, 0.55, 0.1, 0.25))
	Sfx.play("seal_charge", 0.0)


func _ai(delta: float) -> void:
	cd = maxf(0.0, cd - delta)
	if seal_decay > 0.0:
		seal_decay -= delta
		if seal_decay <= 0.0 and seal > 0:
			seal -= 1
			seal_decay = 1.0 if seal > 0 else 0.0
	if state == "burst_prep":
		velocity.x = 0.0
		vis.nudge.x = sin(state_t * 70.0) * 3.0
		vis.squash = Vector2(1.0 + state_t * 0.12, 1.0 + state_t * 0.06)
		if randf() < delta * 30.0:
			Fx.particles(global_position + Vector2(randf_range(-30, 30), -randf_range(40, 130)), 1,
				Color(0.95, 0.75, 0.3), 60.0, 180.0, Vector2.UP, 0.0, 0.4, 5.0)
		if state_t >= 0.5:
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
					vis.set_pose("husk_side", 0.06)
					telegraph.flare(Vector2(40, -110), 0.55)
					Sfx.play("husk_groan", -4.0)
		"windup":
			velocity.x = 0.0
			vis.lean = lerpf(vis.lean, -9.0, delta * 6.0)
			if state_t >= 0.55:
				set_state("attack")
				attack_hits = {}
				vis.set_pose("husk_strike", 0.03)
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
	vis.set_pose("husk_burst", 0.02)
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
	Fx.particles(global_position + Vector2(0, -90), 30, Color(0.85, 0.72, 0.35), 240.0, 160.0, Vector2.UP, 300.0, 1.4, 7.0)
