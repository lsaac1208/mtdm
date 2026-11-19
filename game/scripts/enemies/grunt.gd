extends Enemy
## 01 普通尸祟 Common Undead Grunt — 132 px, hurtbox 46x124, walk 95,
## pounce 280, 0.4 s lean-forward claw wind-up, low poise (every hit staggers).

var home_x := 0.0
var wander_dir := 1
var cd := 0.0


func _init() -> void:
	rig_type = "grunt"
	walk_speed = 95.0
	enemy_name = "普通尸祟"
	max_hp = 34.0
	max_poise = 6.0
	hurt_size = Vector2(46, 124)
	idle_pose = "grunt_idle"
	stagger_pose = "grunt_alert"
	death_pose = "grunt_alert"
	stagger_time = 0.5
	shadow_w = 54.0


func _ready() -> void:
	super._ready()
	home_x = global_position.x
	facing = -1
	set_state("wander" if not aggro else "chase")


func _on_spawned() -> void:
	set_state("alert")
	vis.set_pose("grunt_alert", 0.1)


func _ai(delta: float) -> void:
	cd = maxf(0.0, cd - delta)
	if update_stagger(delta):
		return
	var p := player()
	var dx := dx_to_player()
	match state:
		"wander":
			vis.set_pose("grunt_idle", 0.1)
			velocity.x = wander_dir * 38.0
			facing = wander_dir
			walk_anim(delta, 0.5, 6.0)
			if absf(global_position.x - home_x) > 70.0:
				wander_dir = -int(signf(global_position.x - home_x))
			if p and (absf(dx) < 430.0 or aggro):
				set_state("alert")
				face_toward(p.global_position.x)
				vis.set_pose("grunt_alert", 0.06)
				vis.squash = Vector2(0.94, 1.08)
				Sfx.play("growl", -6.0, 0.15)
		"alert":
			velocity.x = 0.0
			still_anim()
			if p:
				face_toward(p.global_position.x)
			if state_t > 0.45:
				aggro = true
				set_state("chase")
		"chase":
			if not p:
				velocity.x = 0.0
				vis.set_pose("grunt_idle", 0.1)
				still_anim()
				return
			face_toward(p.global_position.x)
			vis.set_pose("grunt_walk", 0.1)
			if absf(dx) > 125.0:
				velocity.x = facing * 95.0
				walk_anim(delta, 1.0, 7.0)
			else:
				velocity.x = 0.0
				still_anim()
				if cd <= 0.0:
					_windup()
		"windup":
			velocity.x = move_toward(velocity.x, -facing * 20.0, 400 * delta)
			still_anim()
			vis.lean = lerpf(vis.lean, -6.0, delta * 8.0)
			if state_t >= 0.4:
				set_state("attack")
				attack_hits = {}
				vis.set_pose("grunt_attack", 0.03)
				vis.lean = 6.0
				velocity.x = facing * 300.0
				Sfx.play("claw", -4.0)
				Fx.slash(global_position + Vector2(48 * facing, -84), facing, -80.0, 50.0, 46.0, 14.0, 0.18,
					Color(0.45, 0.42, 0.36), Color(0.9, 0.88, 0.8), 1.0)
		"attack":
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if state_t < 0.2:
				melee(Rect2(8, -122, 82, 104), 12.0, 220.0)
			if state_t >= 0.3:
				set_state("recover")
				vis.set_pose("grunt_idle", 0.12)
				vis.lean = 0.0
		"recover":
			velocity.x = 0.0
			if state_t >= 0.6:
				cd = 0.5
				set_state("chase")


func _windup() -> void:
	set_state("windup")
	vis.set_pose("grunt_windup", 0.06)
	telegraph.flare(Vector2(52, -96), 0.4)
	Sfx.play("growl", -3.0, 0.1, 1.2)
