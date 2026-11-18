extends Node
## Engine-level gameplay tests. Run:
##   godot --headless --path game -- --test=all --nohitstop --mute
## Each test drives the real player through `input_override` (no direct
## state poking for the behaviour under test) inside the real level scene.

var results := []
var only := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	only = Game.args.get("test", "all")
	_run.call_deferred()


func _log(name_: String, ok: bool, detail := "") -> void:
	results.append([name_, ok])
	print("TEST %-28s %s  %s" % [name_, "PASS" if ok else "FAIL", detail])


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, true).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _fresh_level(startx := 600.0) -> Player:
	Game.args["startx"] = str(startx)
	Game.new_run()
	await _frames(3)
	while Game.level == null or not is_instance_valid(Game.level) or Game.level.player == null:
		await _frames(1)
	await _frames(5)
	var p: Player = Game.level.player
	p.input_override = {}
	return p


func press(p: Player, action: String, also := {}) -> void:
	var d := {}
	d.merge(also)
	d[action] = true
	d[action + "_just"] = true
	p.input_override = d
	await _frames(2)
	p.input_override = {}


func hold(p: Player, d: Dictionary) -> void:
	p.input_override = d


func spawn(type: String, x: float, frozen := false) -> Enemy:
	var en: Enemy = Encounter.TYPES[type].new()
	en.position = Vector2(x, Game.GROUND_Y - 2)
	en.aggro = true
	Game.level.get_node("Actors").add_child(en)
	await _frames(2)
	if frozen:
		en.set_physics_process(false)
	return en


func _run() -> void:
	if only == "showcase":
		await _showcase()
		get_tree().quit()
		return
	if only == "slashcap":
		shot_dir = Game.args.get("shots", "user://shots")
		var p := await _fresh_level(700.0)
		await _wait(0.8)
		p.facing = 1
		await press(p, "attack")
		for i in 6:
			print("SLASHDBG state=", p.state, " t=", p.state_t, " pose=", p.vis.pose, " fx=", Game.level.get_node("Fx").get_child_count())
			await _shot("s%d" % i)
			await _frames(2)
		get_tree().quit()
		return
	if only == "ending_shot":
		shot_dir = Game.args.get("shots", "user://shots")
		Game.run_time = 512.0
		Game.kills = 27
		Game.deaths = 2
		Game.parries = 6
		Game.finish_demo()
		await _wait(4.5)
		await _shot("ending")
		get_tree().quit()
		return
	if only == "runcap":
		shot_dir = Game.args.get("shots", "user://shots")
		var p := await _fresh_level(500.0)
		await _wait(0.6)
		var g := await spawn("grunt", 1150.0)
		hold(p, {"move_right": true})
		await _wait(0.5)
		for i in 8:
			await _shot("run%d" % i)
			await _frames(3)
		hold(p, {})
		get_tree().quit()
		return
	if only == "elitecap":
		shot_dir = Game.args.get("shots", "user://shots")
		var p := await _fresh_level(1500.0)
		p.max_hp = 9999.0
		p.hp = 9999.0
		await _wait(0.5)
		var e := await spawn("elite", 1720.0)
		var k := 0
		var t := 0.0
		while k < 16 and t < 12.0:
			await _frames(5)
			t += 5.0 / 60.0
			if e.state != "chase" and e.state != "idle":
				await _shot("e_%s" % e.state)
				k += 1
		get_tree().quit()
		return
	if only == "pausecap":
		shot_dir = Game.args.get("shots", "user://shots")
		var p := await _fresh_level(700.0)
		await _wait(1.0)
		for n in Game.level.get_children():
			if n.has_method("_open"):
				n._open()
		await get_tree().create_timer(0.5, true, false, true).timeout
		await _shot("pause")
		get_tree().paused = false
		get_tree().quit()
		return
	if only == "walkcap":
		shot_dir = Game.args.get("shots", "user://shots")
		var p := await _fresh_level(700.0)
		p.max_hp = 9999.0
		p.hp = 9999.0
		await _wait(0.5)
		for ty in ["grunt", "crawler", "husk", "spitter", "elite"]:
			var e := await spawn(ty, p.global_position.x + 620.0)
			if ty == "husk":
				e._awaken()
			var tt := 0.0
			while e.state != "chase" and tt < 4.0:
				await _frames(1)
				tt += 1.0 / 60.0
			for i in 6:
				await _frames(4)
				var sx: float = e.global_position.x - Game.level.cam.global_position.x + 640.0
				print("WALKPOS %s %d %.0f %.0f %s" % [ty, i, sx, e.global_position.y - Game.level.cam.global_position.y + 360.0, e.state])
				await _shot("w_%s_%d" % [ty, i])
			e.queue_free()
			await _frames(2)
		get_tree().quit()
		return
	if only == "jumpcap":
		shot_dir = Game.args.get("shots", "user://shots")
		var p := await _fresh_level(600.0)
		await _wait(0.6)
		await press(p, "jump", {"jump": true, "move_right": true})
		hold(p, {"jump": true, "move_right": true})
		for i in 6:
			await _frames(5)
			await _shot("j%d" % i)
		get_tree().quit()
		return
	if only == "debug":
		var p := await _fresh_level(600.0)
		await _wait(0.3)
		print("DBG state=", p.state, " floor=", p.is_on_floor(), " pos=", p.global_position, " coyote=", p.coyote)
		await press(p, "jump", {"jump": true})
		for i in 6:
			print("DBG f", i, " state=", p.state, " vy=", p.velocity.y, " jb=", p.jump_buf, " y=", p.global_position.y, " ov=", p.input_override)
			await _frames(1)
		await _wait(1.0)
		await press(p, "dash")
		for i in 6:
			print("DBG d", i, " state=", p.state, " vx=", p.velocity.x, " x=", p.global_position.x)
			await _frames(1)
		get_tree().quit()
		return
	var tests := ["movement", "crawler_bands", "grunt_hit_and_stagger", "parry", "husk_backlash", "spitter_puddle",
		"elite_telegraph", "death_respawn", "encounter_lock", "full_route", "flow", "bot"]
	for t in tests:
		if only != t and not (only == "all" and t != "bot"):
			continue
		await call("t_" + t)
	var fails := results.filter(func(r): return not r[1]).size()
	print("TESTS DONE pass=%d fail=%d" % [results.size() - fails, fails])
	get_tree().quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ tests
func t_movement() -> void:
	var p := await _fresh_level(600.0)
	var x0 := p.global_position.x
	hold(p, {"move_right": true})
	await _wait(1.0)
	hold(p, {})
	var moved := p.global_position.x - x0
	_log("move_right_1s", moved > 200 and moved < 300, "moved=%.0f px (spec 260 px/s)" % moved)
	await _wait(0.3)
	var y0 := p.global_position.y
	await press(p, "jump", {"jump": true})
	hold(p, {"jump": true})
	var apex := y0
	for i in 40:
		await _frames(1)
		apex = minf(apex, p.global_position.y)
	hold(p, {})
	await _wait(0.8)
	_log("jump_and_land", y0 - apex > 100 and p.is_on_floor(), "apex=%.0f px" % (y0 - apex))
	var xd := p.global_position.x
	await press(p, "dash", {"move_left": true})
	await _wait(0.4)
	_log("dash", xd - p.global_position.x > 90, "dash dist=%.0f (left)" % (xd - p.global_position.x))


func t_crawler_bands() -> void:
	var p := await _fresh_level(600.0)
	p.facing = 1
	var c := await spawn("crawler", p.global_position.x + 70, true)
	var hp0 := c.hp
	await press(p, "attack")         # combo-1 horizontal slash (55–145 px band)
	await _wait(0.6)
	_log("hslash_whiffs_crawler", is_equal_approx(c.hp, hp0), "crawler hp %.0f -> %.0f" % [hp0, c.hp])
	var g := await spawn("grunt", p.global_position.x + 70, true)
	var ghp := g.hp
	await press(p, "attack")
	await _wait(0.6)
	_log("hslash_hits_grunt", g.hp < ghp, "grunt hp %.0f -> %.0f" % [ghp, g.hp])
	g.queue_free()
	await _frames(2)
	await press(p, "attack", {"move_down": true})   # S+J down slash (0–160 px)
	await _wait(0.7)
	_log("downslash_hits_crawler", c.hp < hp0, "crawler hp %.0f -> %.0f" % [hp0, c.hp])
	c.hp = c.max_hp
	p.global_position.x -= 160
	await _wait(0.5)
	await press(p, "dash")
	await _frames(4)
	await press(p, "attack")
	await _wait(0.6)
	_log("dash_slash_hits_crawler", c.hp < c.max_hp or c.dead, "crawler hp -> %.0f" % c.hp)


func t_grunt_hit_and_stagger() -> void:
	var p := await _fresh_level(600.0)
	p.facing = 1
	var g := await spawn("grunt", p.global_position.x + 90)
	await _wait(0.1)
	await press(p, "attack")
	await _frames(12)
	_log("grunt_staggers_on_light_hit", g.state == "stagger", "state=%s" % g.state)
	# full combo kills a grunt (10 + 14 + 17 = 41 > 34)
	await _wait(0.5)
	for i in 3:
		await press(p, "attack")
		await _frames(14)
	await _wait(0.8)
	_log("combo_kills_grunt", g == null or not is_instance_valid(g) or g.dead, "")


func t_parry() -> void:
	var p := await _fresh_level(600.0)
	p.facing = 1
	var g := await spawn("grunt", p.global_position.x + 110)
	var parried_before := Game.parries
	var hp0 := p.hp
	# wait for the claw wind-up, then raise the guard just before the strike
	var waited := 0.0
	while g.state != "windup" and waited < 6.0:
		await _frames(1)
		waited += 1.0 / 60.0
	while g.state == "windup" and g.state_t < 0.33:
		await _frames(1)
	hold(p, {"block": true})
	await _wait(0.5)
	hold(p, {})
	_log("parry_on_timed_guard", Game.parries > parried_before and p.hp >= hp0, "parries=%d hp=%.0f" % [Game.parries, p.hp])
	_log("parry_staggers_enemy", g.state == "stagger" or g.state == "chase" or g.dead, "grunt state=%s" % g.state)


func t_husk_backlash() -> void:
	var p := await _fresh_level(600.0)
	p.facing = 1
	var h := await spawn("husk", p.global_position.x + 95)
	h._awaken()
	await _wait(1.0)
	var burst_seen := false
	var hp_before := p.hp
	for i in 6:
		await press(p, "attack")
		for k in 14:
			await _frames(1)
			if h.state == "burst_prep" or h.state == "burst":
				burst_seen = true
		if burst_seen:
			break
	_log("husk_seal_burst_triggers", burst_seen, "after melee chain, state=%s" % h.state)
	await _wait(0.9)
	_log("husk_burst_punishes_greed", p.hp < hp_before, "player hp %.0f -> %.0f" % [hp_before, p.hp])
	# ranged talisman does not build seal pressure
	await _wait(1.5)
	h.seal = 0
	p.qi = 100.0
	p.global_position.x = h.global_position.x - 330
	p.facing = 1
	await _frames(3)
	await press(p, "talisman")
	await _wait(0.8)
	_log("talisman_no_seal_pressure", h.seal == 0, "seal=%d" % h.seal)


func t_spitter_puddle() -> void:
	var p := await _fresh_level(600.0)
	p.facing = 1
	var s := await spawn("spitter", p.global_position.x + 360)
	var saw_proj := false
	var saw_puddle := false
	var t := 0.0
	while t < 6.0 and not saw_puddle:
		await _frames(1)
		t += 1.0 / 60.0
		for n in Game.level.get_node("Fx").get_children():
			if n.get_script() == preload("res://scripts/fx/taint_projectile.gd"):
				saw_proj = true
		saw_puddle = get_tree().get_nodes_in_group("taint_puddle").filter(func(n): return not n.permanent).size() > 0
	_log("spitter_fires_parabolic_glob", saw_proj, "t=%.1fs" % t)
	_log("glob_leaves_taint_puddle", saw_puddle, "")
	# windup interrupted by talisman (poise 20 >= 12)
	await _wait(2.5)
	p.qi = 100.0
	var waited := 0.0
	while s.state != "windup" and waited < 6.0:
		await _frames(1)
		waited += 1.0 / 60.0
	p.facing = 1 if s.global_position.x > p.global_position.x else -1
	await press(p, "talisman")
	await _wait(0.7)
	_log("talisman_interrupts_spitter", s.state == "stagger" or s.state == "chase" or s.dead, "state=%s" % s.state)


func t_elite_telegraph() -> void:
	var p := await _fresh_level(600.0)
	p.facing = 1
	p.max_hp = 9999.0
	p.hp = 9999.0
	var e := await spawn("elite", p.global_position.x + 130)
	var wind_start := -1.0
	var strike_at := -1.0
	var kind := ""
	var t := 0.0
	while t < 8.0 and strike_at < 0.0:
		await _frames(1)
		t += 1.0 / 60.0
		if wind_start < 0.0 and e.state.begins_with("windup"):
			wind_start = t
			kind = e.state
		if wind_start >= 0.0 and (e.state == "chop" or e.state == "sweep"):
			strike_at = t
	var lead := strike_at - wind_start
	_log("elite_windup_readable", lead >= 0.6 and lead <= 0.9, "%s lead=%.2fs (spec 0.65–0.85)" % [kind, lead])
	# light attacks do not interrupt its approach (super armour)
	await _wait(1.5)
	var st_before: String = e.state
	await press(p, "attack")
	await _frames(10)
	_log("elite_armor_ignores_light_hit", e.state != "stagger", "state %s -> %s" % [st_before, e.state])


func t_death_respawn() -> void:
	var p := await _fresh_level(600.0)
	var deaths := Game.deaths
	var hs := {}
	p.hp = 5.0
	Combat.strike({"owner": null, "team": Combat.TEAM_ENEMY, "rect": p.get_hurtbox(), "damage": 50.0, "poise": 0.0,
		"knock": 100.0, "dir": 1, "kind": "melee", "unblockable": true, "tag": "test"}, hs)
	await _frames(2)
	_log("player_dies", p.dead, "")
	await _wait(3.5)
	var cpx: float = LevelData.CHECKPOINTS[Game.checkpoint_id].x
	_log("respawn_at_checkpoint", not p.dead and p.hp == p.max_hp and absf(p.global_position.x - cpx) < 120 and Game.deaths == deaths + 1,
		"x=%.0f cp=%.0f hp=%.0f" % [p.global_position.x, cpx, p.hp])


func _kill_all() -> void:
	for e in Combat.enemies_alive():
		if e.state == "spawn":
			continue
		var hs := {}
		Combat.strike({"owner": Game.player, "team": Combat.TEAM_PLAYER, "rect": e.get_hurtbox(), "damage": 9999.0,
			"poise": 999.0, "knock": 0.0, "dir": 1, "kind": "aoe", "centre": e.global_position, "unblockable": false, "tag": "test"}, hs)


func t_encounter_lock() -> void:
	var p := await _fresh_level(1300.0)
	hold(p, {"move_right": true})
	await _wait(0.9)
	hold(p, {})
	var enc: Encounter = Game.level.encounters[0]
	_log("encounter_locks_on_trigger", enc.state == "active" and enc.barriers.size() == 2, "state=%s" % enc.state)
	p.global_position.x = 1000.0
	await _frames(3)
	var blocked := p.global_position.x
	hold(p, {"move_left": true})
	await _wait(0.6)
	hold(p, {})
	await _wait(0.2)
	await _wait(1.6)
	for i in 4:
		_kill_all()
		await _wait(1.0)
	_log("encounter_clears", enc.state == "cleared" and Game.cleared.has("e1_village"), "state=%s alive=%d" % [enc.state, enc.alive.size()])


func t_full_route() -> void:
	# Teleport through every encounter, clearing each, then walk into the gate.
	var p := await _fresh_level(600.0)
	p.max_hp = 99999.0
	p.hp = 99999.0
	for enc in Game.level.encounters:
		var d: Dictionary = enc.data
		var tx: float = d.trigger + 20.0 if d.trigger > 0.0 else d.enemies[0][1] - 250.0
		p.global_position = Vector2(tx, Game.GROUND_Y - 4)
		await _wait(0.4)
		var guard := 0
		while enc.state != "cleared" and guard < 30:
			_kill_all()
			await _wait(0.6)
			guard += 1
		_log("route_" + d.id, enc.state == "cleared", "")
	# rest at the final campfire then walk into the light
	p.global_position = Vector2(LevelData.END_X - 200, Game.GROUND_Y - 4)
	hold(p, {"move_right": true})
	var t := 0.0
	while t < 8.0 and Game.running:
		await _frames(1)
		t += 1.0 / 60.0
		if not is_instance_valid(p):
			break
	if is_instance_valid(p):
		hold(p, {})
	await _wait(0.5)
	var scene := get_tree().current_scene
	_log("demo_completes", scene != null and scene.scene_file_path == Game.END_SCENE, "scene=%s" % (scene.scene_file_path if scene else "?"))


# ------------------------------------------------------------------ captures
var shot_dir := ""
var shot_i := 0


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%02d_%s.png" % [shot_dir, shot_i, tag]
	img.save_png(path)
	print("SHOT ", path)
	shot_i += 1


func _showcase() -> void:
	shot_dir = Game.args.get("shots", "user://shots")
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var p := await _fresh_level(700.0)
	p.max_hp = 9999.0
	p.hp = 9999.0
	p.qi = 100.0
	await _wait(1.0)
	var g := await spawn("grunt", p.global_position.x + 170)
	await _wait(0.9)
	p.facing = 1
	await press(p, "attack")
	await _wait(0.12)
	await _shot("slash1")
	await press(p, "attack")
	await _wait(0.2)
	await _shot("downslash")
	await press(p, "attack")
	await _wait(0.2)
	await _shot("thrust")
	if is_instance_valid(g):
		g.queue_free()
	var c := await spawn("crawler", p.global_position.x + 330)
	var t := 0.0
	while is_instance_valid(c) and c.state != "pounce" and t < 5.0:
		await _frames(1)
		t += 1.0 / 60.0
	await _wait(0.08)
	await _shot("crawler_pounce")
	await _wait(1.0)
	if is_instance_valid(c):
		c.queue_free()
	p.global_position.x = 1150
	var s := await spawn("spitter", 1530)
	t = 0.0
	while s.state != "windup" and t < 6.0:
		await _frames(1)
		t += 1.0 / 60.0
	await _wait(0.6)
	await _shot("spitter_windup")
	await _wait(0.55)
	await _shot("spitter_glob")
	await _wait(0.9)
	await _shot("taint_puddle")
	p.facing = 1
	await press(p, "talisman")
	await _wait(0.25)
	await _shot("talisman")
	await _wait(1.0)
	s.queue_free()
	var h := await spawn("husk", p.global_position.x + 100)
	h._awaken()
	await _wait(1.1)
	h._burst_prep()
	await _wait(0.53)
	await _shot("husk_burst")
	await _wait(1.0)
	h.queue_free()
	p.qi = 100.0
	var g1 := await spawn("grunt", p.global_position.x - 120)
	var g2 := await spawn("grunt", p.global_position.x + 130)
	await _wait(0.3)
	await press(p, "beads")
	await _wait(0.5)
	await _shot("beads_burst")
	await _wait(1.0)
	p.global_position.x = 2000
	var e := await spawn("elite", 2230)
	t = 0.0
	while not e.state.begins_with("windup") and t < 8.0:
		await _frames(1)
		t += 1.0 / 60.0
	await _wait(0.45)
	await _shot("elite_" + e.state)
	while not (e.state == "chop" or e.state == "sweep" or e.state.begins_with("recover")) and t < 12.0:
		await _frames(1)
		t += 1.0 / 60.0
	await _wait(0.05)
	await _shot("elite_strike")
	p.global_position.x = 2080
	p.facing = 1
	hold(p, {"block": true})
	await _wait(0.4)
	await _shot("block")
	hold(p, {})
	await press(p, "jump", {"jump": true})
	hold(p, {"jump": true})
	await _wait(0.25)
	await press(p, "attack")
	await _wait(0.1)
	await _shot("jump_attack")
	hold(p, {})
	await _wait(0.6)
	await press(p, "dash")
	await _frames(3)
	await press(p, "attack")
	await _wait(0.1)
	await _shot("dash_attack")
	await _wait(0.8)
	await press(p, "gourd")
	await _wait(0.3)
	await _shot("gourd")


# ------------------------------------------------------------------ bot
## A scripted player that clears the whole demo using only inputs. It is not
## optimal; it exists to prove the route is completable with real combat and
## to surface soft-locks. Usage: --test=bot (add --fixed-fps 60 to speed up).
var _bot_cd := 0.0
var _bot_hits := 0
var _bot_retreat := 0.0
var _bot_stuck := 0.0
var _bot_lastx := 0.0


func t_bot() -> void:
	Game.args.erase("startx")
	Game.new_run()
	await _frames(3)
	while Game.level == null or not is_instance_valid(Game.level) or Game.level.player == null:
		await _frames(1)
	var p: Player = Game.level.player
	var t := 0.0
	var limit := float(Game.args.get("bot_limit", "900"))
	var last_report := 0.0
	while t < limit:
		await _frames(1)
		t += 1.0 / 60.0
		var scene := get_tree().current_scene
		if scene and scene.scene_file_path == Game.END_SCENE:
			break
		if Game.level == null or not is_instance_valid(Game.level):
			continue
		p = Game.level.player
		if p == null or not is_instance_valid(p):
			continue
		_bot_step(p, 1.0 / 60.0)
		if Game.args.has("shots") and fmod(t, float(Game.args.get("shot_every", "5"))) < 1.0 / 60.0:
			shot_dir = Game.args.shots
			DirAccess.make_dir_recursive_absolute(shot_dir)
			await _shot("bot_%04d" % int(t))
		if t - last_report > 20.0:
			last_report = t
			print("BOT t=%.0fs x=%.0f hp=%.0f deaths=%d kills=%d cleared=%s" % [t, p.global_position.x, p.hp, Game.deaths, Game.kills, Game.cleared.keys()])
	var scene2 := get_tree().current_scene
	var done := scene2 != null and scene2.scene_file_path == Game.END_SCENE
	_log("bot_completes_demo", done, "sim_time=%.0fs deaths=%d kills=%d parries=%d run_time=%s" % [t, Game.deaths, Game.kills, Game.parries, Game.format_time(Game.run_time)])


func _bot_press(d: Dictionary, action: String) -> void:
	d[action] = true
	d[action + "_just"] = true


func _bot_step(p: Player, dt: float) -> void:
	_bot_cd = maxf(0.0, _bot_cd - dt)
	_bot_retreat = maxf(0.0, _bot_retreat - dt)
	var d := {}
	if p.dead:
		p.input_override = d
		return
	var near: Enemy = null
	var nd := 1e9
	for e in Combat.enemies_alive():
		if e.state == "spawn":
			continue
		var dd: float = absf(e.global_position.x - p.global_position.x)
		if dd < nd:
			nd = dd
			near = e
	# generic obstacle handling: if pushing but not moving, hop
	if absf(p.global_position.x - _bot_lastx) < 0.5 and p.is_on_floor() and p.state in ["run", "idle"]:
		_bot_stuck += dt
	else:
		_bot_stuck = 0.0
	_bot_lastx = p.global_position.x
	if near == null or nd > 520.0:
		d["move_right"] = true
		if _bot_stuck > 0.15 and _bot_cd <= 0.0:
			_bot_press(d, "jump")
			d["jump"] = true
			_bot_cd = 0.3
		for pd in get_tree().get_nodes_in_group("taint_puddle"):
			var ahead: float = pd.global_position.x - p.global_position.x
			if ahead > 30 and ahead < 60 + pd.radius and p.is_on_floor() and _bot_cd <= 0.0:
				_bot_press(d, "jump")
				d["jump"] = true
				_bot_cd = 0.3
		if not p.is_on_floor():
			d["jump"] = true
		if p.hp < p.max_hp * 0.5 and p.gourd > 0 and _bot_cd <= 0.0:
			_bot_press(d, "gourd")
			_bot_cd = 0.8
		p.input_override = d
		return
	if _bot_stuck > 0.25 and _bot_cd <= 0.0:
		_bot_press(d, "jump")
		d["jump"] = true
		_bot_cd = 0.3
	var dx: float = near.global_position.x - p.global_position.x
	var dir := "move_right" if dx > 0 else "move_left"
	var away := "move_left" if dx > 0 else "move_right"
	var ad := absf(dx)
	var es: String = near.state
	var est: float = near.state_t
	# emergency heal when not under immediate threat
	if p.hp < p.max_hp * 0.4 and p.gourd > 0 and _bot_cd <= 0.0 and not es.begins_with("windup"):
		_bot_press(d, "gourd")
		_bot_cd = 0.8
		p.input_override = d
		return
	if p.in_taint > 0.0 and p.is_on_floor() and _bot_cd <= 0.0:
		d[dir] = true
		_bot_press(d, "jump")
		d["jump"] = true
		_bot_cd = 0.4
		p.input_override = d
		return
	if not p.is_on_floor():
		d["jump"] = true
	var crowd := 0
	for e in Combat.enemies_alive():
		if absf(e.global_position.x - p.global_position.x) < 200:
			crowd += 1
	if crowd >= 2 and p.qi >= p.BEADS_COST and _bot_cd <= 0.0:
		_bot_press(d, "beads")
		_bot_cd = 1.0
		p.input_override = d
		return
	# enemy standing on a ledge above us: jump up toward it
	if near.global_position.y < p.global_position.y - 30.0 and ad < 260.0:
		d[dir] = true
		if p.is_on_floor() and _bot_cd <= 0.0:
			_bot_press(d, "jump")
			d["jump"] = true
			_bot_cd = 0.35
		elif not p.is_on_floor() and _bot_cd <= 0.1 and ad < 130.0:
			_bot_press(d, "attack")
			_bot_cd = 0.3
		p.input_override = d
		return
	var kind := near.enemy_name
	match kind:
		"伏爬者":
			if (es == "prep" or es == "pounce") and ad < 260 and p.is_on_floor():
				_bot_press(d, "jump")
				d["jump"] = true
				d[away] = true
			elif ad < 125:
				if _bot_cd <= 0.0:
					d[dir] = true
					d["move_down"] = true
					_bot_press(d, "attack")
					_bot_cd = 0.45
			else:
				d[dir] = true
		"瘴吐者":
			if ad > 260 and p.qi >= p.TALISMAN_COST and _bot_cd <= 0.0:
				d[dir] = true
				_bot_press(d, "talisman")
				_bot_cd = 0.5
			elif ad > 150 and _bot_cd <= 0.0 and p.dash_cd <= 0.0:
				d[dir] = true
				_bot_press(d, "dash")
				_bot_cd = 0.1
			elif ad <= 150 and _bot_cd <= 0.0:
				d[dir] = true
				_bot_press(d, "attack")
				_bot_cd = 0.16
			else:
				d[dir] = true
		"封印残尸":
			if es == "burst_prep" or es == "burst" or _bot_retreat > 0.0:
				d[away] = true
				if es == "burst_prep" and p.dash_cd <= 0.0 and ad < 160:
					_bot_press(d, "dash")
			elif es == "windup" and ad < 150:
				d["block"] = true
			elif ad < 115 and _bot_cd <= 0.0:
				d[dir] = true
				_bot_press(d, "attack")
				_bot_cd = 0.3
				_bot_hits += 1
				if _bot_hits >= 3:
					_bot_hits = 0
					_bot_retreat = 1.2
			elif ad > 330 and p.qi >= p.TALISMAN_COST and _bot_cd <= 0.0:
				_bot_press(d, "talisman")
				d[dir] = true
				_bot_cd = 0.6
			elif ad >= 115:
				d[dir] = true
		"尸将":
			if es == "windup_chop" and ad < 260:
				if est > 0.45 and p.dash_cd <= 0.0:
					d[away] = true
					_bot_press(d, "dash")
				else:
					d[away] = true
			elif es == "windup_sweep" and ad < 280:
				if est > 0.42 and p.is_on_floor():
					_bot_press(d, "jump")
					d["jump"] = true
				d[away] = true
			elif es in ["recover_chop", "recover_sweep", "stagger", "recoil"]:
				if ad > 120:
					d[dir] = true
				elif _bot_cd <= 0.0:
					d[dir] = true
					_bot_press(d, "attack")
					_bot_cd = 0.14
			elif es == "chase" or es == "lunge":
				if ad < 190:
					d[away] = true
				elif p.qi >= p.TALISMAN_COST and _bot_cd <= 0.0:
					d[dir] = true
					_bot_press(d, "talisman")
					_bot_cd = 0.6
			else:
				if ad < 220:
					d[away] = true
		_:
			# grunts: guard their claw, punish recovery
			if es == "windup" and ad < 170:
				if est > 0.24:
					d["block"] = true
			elif es == "attack" and ad < 170:
				d["block"] = true
			elif ad > 115:
				d[dir] = true
			elif _bot_cd <= 0.0:
				d[dir] = true
				_bot_press(d, "attack")
				_bot_cd = 0.15
	p.input_override = d



func t_flow() -> void:
	# pause-menu restart reloads the level at the current campfire with cleared encounters kept
	var p := await _fresh_level(1300.0)
	Game.cleared["e1_village"] = true
	Game.checkpoint_id = 1
	Game.args.erase("startx")
	get_tree().reload_current_scene()
	await _frames(5)
	while Game.level == null or not is_instance_valid(Game.level) or Game.level.player == null or Game.level.player == p:
		await _frames(1)
	p = Game.level.player
	var cp1: float = LevelData.CHECKPOINTS[1].x
	_log("restart_keeps_progress", Game.cleared.has("e1_village") and absf(p.global_position.x - cp1) < 150,
		"x=%.0f cp1=%.0f" % [p.global_position.x, cp1])
	# ending -> title -> new run resets the run state
	Game.finish_demo()
	await _wait(1.0)
	Game.to_title()
	await _wait(1.0)
	var title_ok := get_tree().current_scene != null and get_tree().current_scene.scene_file_path == Game.TITLE_SCENE
	Game.args.erase("startx")
	Game.new_run()
	await _frames(5)
	while Game.level == null or not is_instance_valid(Game.level) or Game.level.player == null:
		await _frames(1)
	p = Game.level.player
	_log("new_run_resets_state", title_ok and Game.cleared.is_empty() and Game.checkpoint_id == 0 and Game.deaths == 0
		and absf(p.global_position.x - LevelData.CHECKPOINTS[0].x) < 150 and Combat.enemies_alive().size() > 0,
		"cleared=%d cp=%d x=%.0f alive=%d actors=%d" % [Game.cleared.size(), Game.checkpoint_id, p.global_position.x, Combat.enemies_alive().size(), Combat.actors.size()])
	# no leaked actors from previous scenes
	var stale := Combat.actors.filter(func(a): return not is_instance_valid(a) or not a.is_inside_tree())
	_log("no_stale_actors", stale.is_empty(), "stale=%d" % stale.size())
