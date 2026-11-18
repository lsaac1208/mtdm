extends Enemy
## 02 匍匐尸祟·伏爬者 Crawler — 54 px tall, flat hurtbox 92x46 (spec §2.1).
## A standing horizontal slash (55–145 px above ground) passes over it; the
## down slash, dash slash, jump attack and Taoist skills reach it.
## Crawl 215 px/s, pounce 440 px/s at the legs, then scuttle back (回撤).

var cd := 0.0
var landed := false


func _init() -> void:
	enemy_name = "伏爬者"
	max_hp = 26.0
	max_poise = 6.0
	hurt_size = Vector2(92, 46)
	idle_pose = "crawler_idle"
	stagger_pose = "crawler_hit"
	death_pose = "crawler_hit"
	stagger_time = 0.55
	topple_on_death = false
	shadow_w = 96.0


func _ready() -> void:
	super._ready()
	facing = -1
	if state != "spawn":
		set_state("lurk")


func _on_spawned() -> void:
	set_state("alert")
	vis.set_pose("crawler_alert", 0.06)


func _ai(delta: float) -> void:
	cd = maxf(0.0, cd - delta)
	if update_stagger(delta):
		return
	var p := player()
	var dx := dx_to_player()
	match state:
		"lurk":
			velocity.x = 0.0
			vis.set_pose("crawler_idle", 0.1)
			vis.tint = Color(0.75, 0.75, 0.72)
			still_anim()
			if p and (absf(dx) < 380.0 or aggro):
				vis.tint = Color.WHITE
				set_state("alert")
				face_toward(p.global_position.x)
				vis.set_pose("crawler_alert", 0.05)
				vis.squash = Vector2(0.9, 1.15)
				Sfx.play("hiss", -4.0)
		"alert":
			velocity.x = 0.0
			if state_t > 0.35:
				aggro = true
				set_state("chase")
		"chase":
			if not p:
				velocity.x = 0.0
				return
			face_toward(p.global_position.x)
			vis.set_pose("crawler_crawl", 0.06)
			if absf(dx) > 210.0 or cd > 0.0:
				var sp := 215.0 if absf(dx) > 120.0 else 0.0
				velocity.x = facing * sp
				walk_anim(delta, sp / 215.0, 16.0, 0.05)
			else:
				velocity.x = 0.0
				set_state("prep")
				vis.set_pose("crawler_idle", 0.04)
				vis.squash = Vector2(1.12, 0.85)
				telegraph.flare(Vector2(56, -34), 0.26, Color(1, 0.45, 0.2))
				telegraph.danger(Rect2(10, -60, 230, 60), 0.26)
		"prep":
			velocity.x = -facing * 30.0
			still_anim()
			if state_t >= 0.26:
				set_state("pounce")
				attack_hits = {}
				landed = false
				vis.set_pose("crawler_pounce", 0.03)
				velocity = Vector2(facing * 440.0, -330.0)
				Sfx.play("pounce", -3.0)
		"pounce":
			melee(Rect2(0, -64, 96, 64), 10.0, 200.0, {"low": true})
			if state_t > 0.12 and is_on_floor():
				set_state("retreat")
				vis.set_pose("crawler_retreat", 0.06)
				Fx.dust(global_position, 6)
		"retreat":
			velocity.x = -facing * 240.0 * (1.0 - state_t / 0.6)
			walk_anim(delta, 1.0, 18.0, 0.05)
			if state_t >= 0.6:
				cd = 0.7
				set_state("chase")


func stagger(dur: float, dir: int, knock: float) -> void:
	super.stagger(dur, dir, knock)
	# flipped onto its back (仰翻)
	velocity.y = -180.0
	vis.squash = Vector2(1.1, 0.8)
