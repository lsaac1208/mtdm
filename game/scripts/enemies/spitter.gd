extends Enemy
## 04 喷秽尸祟·瘴吐者 Taint Spitter — 138 px, hurtbox 52x130, slow 75 px/s.
## Keeps range (220–520 px), swells its throat sac for a long, glowing
## wind-up, then lobs a parabolic taint glob that leaves a 65 px-radius
## puddle for 4.5 s. Wind-up is cancelled by heavy hits / talismans
## (single-hit poise >= 12); light slashes do not interrupt. Weak up close.

const TaintProjectile := preload("res://scripts/fx/taint_projectile.gd")
var cd := 0.8
var glow: Node2D
var glow_amt := 0.0


func _init() -> void:
	hit_material = "taint"
	rig_type = "spitter"
	walk_speed = 75.0
	enemy_name = "瘴吐者"
	max_hp = 40.0
	max_poise = 12.0
	hurt_size = Vector2(52, 130)
	idle_pose = "spitter_idle"
	stagger_pose = "spitter_hit"
	death_pose = "spitter_collapse"
	stagger_time = 0.55
	interrupt_poise = 12.0
	topple_on_death = false
	shadow_w = 58.0


func _ready() -> void:
	super._ready()
	facing = -1
	glow = preload("res://scripts/fx/sac_glow.gd").new()
	glow.position = Vector2(20, -98)
	vis.rig.add_child(glow)
	if state != "spawn":
		set_state("idle")


func _on_spawned() -> void:
	set_state("detect")
	vis.set_pose("spitter_detect", 0.08)


func _ai(delta: float) -> void:
	cd = maxf(0.0, cd - delta)
	glow.amount = glow_amt
	if update_stagger(delta):
		glow_amt = move_toward(glow_amt, 0.0, delta * 4.0)
		return
	var p := player()
	var dx := dx_to_player()
	var ad := absf(dx)
	match state:
		"idle":
			velocity.x = 0.0
			still_anim()
			glow_amt = 0.25 + 0.1 * sin(state_t * 2.0)
			if p and (ad < 650.0 or aggro):
				set_state("detect")
				face_toward(p.global_position.x)
				vis.set_pose("spitter_detect", 0.06)
				Sfx.play("gurgle", -6.0)
		"detect":
			velocity.x = 0.0
			glow_amt = 0.45
			if state_t > 0.45:
				aggro = true
				set_state("chase")
		"chase":
			glow_amt = move_toward(glow_amt, 0.35, delta)
			if not p:
				velocity.x = 0.0
				return
			face_toward(p.global_position.x)
			if ad < 140.0:
				if cd <= 0.0:
					set_state("swipe_wind")
					vis.set_pose("spitter_detect", 0.05)
					telegraph.flare(Vector2(40, -80), 0.45, Color(0.9, 0.8, 0.3))
				else:
					# shuffle away from the player
					vis.set_pose("spitter_side", 0.1)
					velocity.x = -facing * 60.0
					walk_anim(delta, 0.7, 4.0)
			elif ad > 520.0:
				vis.set_pose("spitter_side", 0.1)
				velocity.x = facing * 75.0
				walk_anim(delta, 1.0, 4.5)
			else:
				velocity.x = 0.0
				vis.set_pose("spitter_idle", 0.1)
				still_anim()
				if cd <= 0.0:
					set_state("windup")
					vis.set_pose("spitter_windup", 0.08)
					telegraph.flare(Vector2(20, -112), 0.9, Color(0.7, 1.0, 0.3))
					Sfx.play("sac_swell", -2.0)
		"windup":
			velocity.x = 0.0
			glow_amt = 0.4 + state_t / 0.9 * 1.0
			vis.squash = Vector2(1.0 + state_t * 0.05, 1.0 + state_t * 0.08)
			vis.lean = lerpf(vis.lean, -10.0, delta * 4.0)
			if p:
				face_toward(p.global_position.x)
			if state_t >= 0.9:
				_spit()
		"spit":
			glow_amt = move_toward(glow_amt, 0.0, delta * 5.0)
			if state_t >= 0.3:
				set_state("recover")
				vis.set_pose("spitter_recover", 0.1)
		"recover":
			velocity.x = 0.0
			glow_amt = 0.05
			vis.lean = lerpf(vis.lean, 8.0, delta * 5.0)
			if state_t >= 1.2:
				vis.lean = 0.0
				cd = 1.0
				set_state("chase")
		"swipe_wind":
			velocity.x = 0.0
			if state_t >= 0.45:
				set_state("swipe")
				attack_hits = {}
				vis.set_pose("spitter_swipe", 0.03)
				Sfx.play("claw", -8.0, 0.1, 0.8)
		"swipe":
			if state_t < 0.15:
				melee(Rect2(5, -112, 84, 84), 6.0, 160.0)
			if state_t >= 0.5:
				cd = 1.2
				set_state("chase")


func _spit() -> void:
	set_state("spit")
	vis.set_pose("spitter_spit", 0.03)
	vis.lean = 10.0
	vis.squash = Vector2(0.95, 1.0)
	Sfx.play("spit", 0.0)
	var p := player()
	var mouth := global_position + Vector2(52 * facing, -104)
	var target := p.global_position if p else mouth + Vector2(300 * facing, 104)
	var proj := TaintProjectile.new()
	proj.global_position = mouth
	var dxp := target.x - mouth.x
	var t := clampf(absf(dxp) / 430.0, 0.55, 1.25)
	var g := proj.GRAV
	proj.vel = Vector2(dxp / t, ((target.y - mouth.y) - 0.5 * g * t * t) / t)
	proj.owner_actor = self
	Fx.layer().add_child(proj)
	Fx.particles(mouth, 14, Color(0.6, 0.75, 0.2, 0.9), 200.0, 30.0, Vector2(facing, -0.2), 400.0, 0.4, 5.0)


func stagger(dur: float, dir: int, knock: float) -> void:
	super.stagger(dur, dir, knock)
	Fx.particles(global_position + Vector2(20 * facing, -98), 8, Color(0.6, 0.78, 0.22), 160.0, 90.0, Vector2.UP, 600.0, 0.5, 5.0)


func _die(dir := 0) -> void:
	super._die(dir)
	glow_amt = 0.0
	glow.amount = 0.0
	Sfx.play("splat", 0.0)
	Fx.particles(global_position + Vector2(20 * facing, -98), 30, Color(0.6, 0.78, 0.22), 260.0, 120.0, Vector2.UP, 700.0, 0.8, 6.0)
