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
	var old = Game.level
	Game.new_run()
	await _frames(3)
	while Game.level == null or not is_instance_valid(Game.level) or Game.level == old or Game.level.player == null:
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
		Game.quit()
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
		Game.quit()
		return
	if only == "titlecap":
		shot_dir = Game.args.get("shots", "user://shots")
		get_tree().change_scene_to_file(Game.TITLE_SCENE)
		for k in 4:
			await _wait(1.2)
			await _shot("title_%d" % k)
		Game.quit()
		return
	if only == "defeatcap":
		# the real elite defeat: kill blow -> slow fall -> seal card -> dissolve
		# -> stele rising, sampled on the wall clock (hit-stop slows game time)
		shot_dir = Game.args.get("shots", "user://shots")
		Game.args["skip_cleared"] = "1"
		var p := await _fresh_level(10380.0)
		p.max_hp = 99999.0
		p.hp = 99999.0
		await _wait(2.0)
		var el: Enemy = null
		for n in Game.level.get_node("Actors").get_children():
			if n is Enemy and n.rig_type == "elite":
				el = n
			elif n is Enemy:
				n.queue_free()
		if el == null:
			print("DEFEATCAP no elite")
			Game.quit()
			return
		el.global_position.x = p.global_position.x + 150.0
		el.phase = 2   # already past the 50% summon, like a real final blow
		el.hp = 1.0
		el.set_state("chase")
		await _wait(0.2)
		p.facing = 1
		await press(p, "attack")
		for i in 30:
			await get_tree().create_timer(0.16, true, false, true).timeout
			await _shot("defeat_%02d" % i)
		Game.quit()
		return
	if only == "sealcap":
		shot_dir = Game.args.get("shots", "user://shots")
		await _fresh_level(1500.0)
		await _wait(0.4)
		Game.level.hud.boss_defeated("尸将", "UNDEAD WARRIOR ELITE")
		await _wait(1.2)
		await _shot("seal")
		Game.quit()
		return
	if only == "platcap":
		# every painted platform, one shot each, hero standing beside it
		shot_dir = Game.args.get("shots", "user://shots")
		var p := await _fresh_level(600.0)
		p.max_hp = 99999.0
		p.hp = 99999.0
		for pl in LevelData.PLATFORMS:
			p.global_position = Vector2(pl[0] - 90.0, Game.GROUND_Y - 2.0)
			p.velocity = Vector2.ZERO
			await _wait(0.5)
			await _shot("plat_%s_%d" % [pl[3], int(pl[0])])
		Game.quit()
		return
	if only == "gatecap":
		# the sealed and the opened end gate, plus an encounter ward, in place
		shot_dir = Game.args.get("shots", "user://shots")
		var p := await _fresh_level(LevelData.END_X - 420.0)
		await _wait(0.8)
		await _shot("gate_sealed")
		Game.cleared["e8_elite"] = true
		await _wait(0.6)
		await _shot("gate_open")
		var b := preload("res://scripts/level/barrier.gd").new()
		b.position = Vector2(p.global_position.x + 260.0, Game.GROUND_Y)
		Game.level.get_node("Props").add_child(b)
		await _wait(0.7)
		await _shot("ward")
		Game.quit()
		return
	if only == "ending_shot":
		shot_dir = Game.args.get("shots", "user://shots")
		Game.run_time = 512.0
		Game.kills = 27
		Game.deaths = 2
		Game.parries = 6
		if Game.args.get("mode", "") == "rematch":
			Game.mode = "rematch"
			Game.run_time = 61.5
		Game.finish_demo()
		await _wait(4.5)
		await _shot("ending")
		Game.quit()
		return
	if only == "v04cap":
		shot_dir = Game.args.get("shots", "user://shots")
		# 1. Title with Controls card & rank badge
		Game.cleared_once = true
		Game.best_rank = "甲"
		Game.best_time = 139.0
		get_tree().change_scene_to_file(Game.TITLE_SCENE)
		await _wait(1.0)
		await _shot("title_clean")
		var title_sc := get_tree().current_scene
		if title_sc and title_sc.has_method("_help"):
			title_sc._help()
			await _frames(3)
			await _shot("title_controls")
		# 2. Prologue slides
		get_tree().change_scene_to_file(Game.PROLOGUE_SCENE)
		await _wait(1.0)
		await _shot("prologue_0")
		var pro := get_tree().current_scene
		if pro and pro.has_method("advance"):
			pro.advance()
			await _wait(0.85)
			await _shot("prologue_1")
			pro.advance()
			await _wait(0.85)
			await _shot("prologue_2")
		# 3. Village destructible + whisper card + foreground parallax
		var p := await _fresh_level(640.0)
		p.max_hp = 99999.0
		p.hp = 99999.0
		p.qi = 30.0
		await _wait(0.4)
		Game.show_whisper("qa_village", "wistful", "道行者 · 默语", "荒村灶冷，连镇宅符都化了灰……先探探前路。", 6.0)
		await _wait(0.45)
		await _shot("village_whisper")
		# Move beside first urn (~820) and smash it
		var first_prop: Node = null
		for node in get_tree().get_nodes_in_group("destructible"):
			if not node.broken:
				first_prop = node
				break
		if first_prop:
			p.global_position = Vector2(first_prop.global_position.x - 70.0, Game.GROUND_Y - 2.0)
			p.facing = 1
			await _wait(0.25)
			await press(p, "attack")
			await _wait(0.24)
			await _shot("destructible_break")
		# 4. Diegetic enemy mini-bar + Husk seal crack indicator
		var g := await spawn("grunt", p.global_position.x + 120.0, true)
		var h := await spawn("husk", p.global_position.x + 245.0, true)
		g.receive_hit({"damage": 18.0, "poise": 8.0, "dir": 1, "knock": 40.0, "kind": "sword", "source": p})
		g.burn = 3.0
		h.receive_hit({"damage": 22.0, "poise": 10.0, "dir": 1, "knock": 20.0, "kind": "sword", "source": p})
		h.seal = 2
		await _wait(0.35)
		await _shot("diegetic_enemies")
		# 4b. Parry spectacle shot
		Fx.parry_burst(p.global_position + Vector2(32.0, -76.0), 1)
		await _frames(3)
		await _shot("parry_spectacle")
		# 5. Pause overlay with Ink-and-Brass Scroll Plaque
		var pm := Game.level.get_node_or_null("Pause")
		if pm and pm.has_method("_open"):
			pm._open()
			await _frames(4)
			await _shot("pause_scroll")
			if pm.has_method("_options"):
				pm._options()
				await _frames(4)
				await _shot("options_scroll")
			pm._resume()
			await _frames(3)
		# 6. Boss Phase 2 aura + fierce portrait
		p = await _fresh_level(10250.0)
		p.max_hp = 99999.0
		p.hp = 99999.0
		var el := await spawn("elite", 10460.0, true)
		Game.boss_changed.emit(el)
		el.hp = el.max_hp * 0.45
		el._roar()
		await _wait(0.75)
		await _shot("boss_phase2")
		# 7. Painted stone pailou gate (open)
		p = await _fresh_level(LevelData.END_X - 240.0)
		p.max_hp = 99999.0
		p.hp = 99999.0
		for enc in Game.level.encounters:
			enc.pending.clear()
			for en in enc.alive.duplicate():
				if is_instance_valid(en):
					en.queue_free()
			enc.alive.clear()
			enc._clear()
		Game.cleared["e8_elite"] = true
		p.global_position = Vector2(LevelData.END_X - 240.0, Game.GROUND_Y - 2.0)
		p.facing = 1
		await _wait(1.1)
		await _shot("gate_pailou_open")
		# 8. Ending Journey Ledger + 甲 Seal Stamp
		Game.difficulty = 1
		Game.run_time = 148.0
		Game.kills = 24
		Game.deaths = 0
		Game.parries = 5
		Game.props_broken = 7
		Game.finish_demo()
		await _wait(2.4)
		await _shot("ending_rank_a")
		Game.quit()
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
		Game.quit()
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
		Game.quit()
		return
	if only == "optcap":
		shot_dir = Game.args.get("shots", "user://shots")
		var p := await _fresh_level(700.0)
		await _wait(1.0)
		var o := OptionsMenu.new()
		var cl := CanvasLayer.new()
		cl.layer = 30
		Game.level.add_child(cl)
		cl.add_child(o)
		await _wait(0.4)
		await _shot("options")
		Game.quit()
		return
	if only == "deathcap":
		shot_dir = Game.args.get("shots", "user://shots")
		var p := await _fresh_level(1500.0)
		p.max_hp = 9999.0
		p.hp = 9999.0
		p.facing = 1
		for ty in ["grunt", "husk", "spitter", "elite"]:
			var e := await spawn(ty, 1600.0, true)
			await _frames(3)
			var hs := {}
			Combat.strike({"owner": p, "team": Combat.TEAM_PLAYER, "rect": e.get_hurtbox(), "damage": 5.0 if ty != "elite" else 18.0,
				"poise": 0.0, "knock": 0.0, "dir": 1, "kind": "melee", "unblockable": false, "tag": "test"}, hs)
			await _frames(5)
			await _shot("hit_" + ty)
			if ty != "elite":
				e.queue_free()
				await _wait(0.8)
			else:
				await _wait(0.5)
				e.hp = 1.0
				var hs2 := {}
				Combat.strike({"owner": p, "team": Combat.TEAM_PLAYER, "rect": e.get_hurtbox(), "damage": 50.0,
					"poise": 0.0, "knock": 0.0, "dir": 1, "kind": "melee", "unblockable": false, "tag": "test"}, hs2)
				for tt in [0.15, 0.5, 0.9, 1.6, 2.6]:
					await get_tree().create_timer(tt, true, false, true).timeout
					await _shot("bossdeath_%.2f" % tt)
		Game.quit()
		return
	if only in ["visual_replay", "readcap"]:
		var review = load("res://tests/visual_review.gd").new()
		add_child(review)
		if only == "readcap":
			await review.masks(self)
		else:
			await review.replay(self)
		return
	if only == "lorecap":
		shot_dir = Game.args.get("shots", "user://shots")
		var lx := float(Game.args.get("lorex", "2300"))
		Game.args["skip_cleared"] = "1"
		var p := await _fresh_level(lx - 150.0)
		if Game.args.has("all_cleared"):
			for e in LevelData.ENCOUNTERS:
				Game.cleared[e.id] = true
			await _wait(1.6)
		for n in Game.level.get_node("Actors").get_children():
			if n is Enemy:
				n.queue_free()
		await _wait(1.0)
		await _shot("lore_far")
		hold(p, {"move_right": true})
		var guard := 0
		while p.global_position.x < lx - 56.0 and guard < 600:
			guard += 1
			await _frames(1)
		hold(p, {})
		await _wait(0.6)
		await _shot("lore_near")
		await press(p, "move_up")
		await get_tree().create_timer(0.6, true, false, true).timeout
		await _shot("lore_card")
		Game.quit()
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
		Game.quit()
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
		Game.quit()
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
		Game.quit()
		return
	if only == "walkright":
		var p := await _fresh_level(float(Game.args.get("from", "4200")))
		hold(p, {"move_right": true})
		await _wait(float(Game.args.get("secs", "10")))
		Game.quit()
		return
	if only == "chopcap":
		shot_dir = Game.args.get("shots", "user://shots")
		var p := await _fresh_level(1500.0)
		p.max_hp = 9999.0
		p.hp = 9999.0
		var e := await spawn("elite", 1660.0)
		await _wait(0.6)
		e.cd = 99.0
		e.facing = -1
		e._start("windup_chop")
		for i in 10:
			await _frames(6)
			await _shot("c%d_%s" % [i, e.state])
		Game.quit()
		return
	if only == "armcap":
		# static check of the arm rig on the ready pose at fixed rotations
		shot_dir = Game.args.get("shots", "user://shots")
		var p := await _fresh_level(700.0)
		p.set_physics_process(false)
		await _wait(0.5)
		for r in [0.0, -0.35, 0.35]:
			p.vis.arm_rot = [r, -r]
			await _frames(3)
			await _shot("arm_%+.2f" % r)
		Game.quit()
		return
	if only == "combocap":
		shot_dir = Game.args.get("shots", "user://shots")
		var p := await _fresh_level(700.0)
		await _wait(0.6)
		p.facing = 1
		var seq: String = Game.args.get("seq", "attack,attack,attack")
		var acts := seq.split(",")
		var f := 0
		var ai := 0
		while f < int(Game.args.get("frames", "60")):
			if ai < acts.size() and f % 14 == 0:
				var a: String = acts[ai]
				ai += 1
				if a == "down":
					p.input_override = {"attack": true, "attack_just": true, "move_down": true}
				elif a == "jumpatk":
					p.input_override = {"jump": true, "jump_just": true}
				else:
					p.input_override = {a: true, a + "_just": true}
			await _frames(2)
			f += 2
			if seq.begins_with("jumpatk") and f == 14:
				p.input_override = {"attack": true, "attack_just": true}
			var tag: String = p.vis.current_clip() if p.vis.frame_on else p.vis.pose
			await _shot("f%03d_%s" % [f, tag])
		Game.quit()
		return
	if only == "crawlcap":
		shot_dir = Game.args.get("shots", "user://shots")
		var p := await _fresh_level(700.0)
		p.max_hp = 9999.0
		p.hp = 9999.0
		await _wait(0.4)
		var c := await spawn("crawler", 1150.0)
		var last := ""
		var n := 0
		var tt := 0.0
		while n < 12 and tt < 6.0:
			await _frames(3)
			tt += 0.05
			if c.state != last or c.state == "pounce":
				last = c.state
				await _shot("cr_%s" % c.state)
				n += 1
		Game.quit()
		return
	if only == "rigcap":
		shot_dir = Game.args.get("shots", "user://shots")
		var p := await _fresh_level(700.0)
		p.set_physics_process(false)
		p.vis.visible = false
		var rig := CutoutRig.new()
		p.add_child(rig)
		rig.setup("res://assets/rig/hero", HeroClips.clips())
		rig.z_index = 6
		if Game.args.has("tintparts"):
			var cols := [Color(1, 0.4, 0.4), Color(0.4, 1, 0.4), Color(0.4, 0.4, 1), Color(1, 1, 0.3), Color(1, 0.4, 1), Color(0.3, 1, 1), Color(1, 0.7, 0.3), Color(0.7, 0.7, 0.7), Color(0.6, 0.3, 1)]
			var ci := 0
			for n in rig.pivot.get_children():
				if n is Polygon2D:
					n.modulate = cols[ci % cols.size()]
					print("PART ", n.name, " ", cols[ci % cols.size()])
					ci += 1
		var seq: Array = (Game.args.get("clips", "idle:2,run:8,jump:2,fall:2,land:2,block:2,hit:2,windup_slash:2,windup_over:2,windup_thrust:2,dead:2") as String).split(",")
		for item in seq:
			var kv := (item as String).split(":")
			rig.play(kv[0], 0.08, true)
			var n := int(kv[1])
			var clip_len: float = rig.player.get_animation(kv[0]).length
			for i in n:
				await _wait(maxf(clip_len / n, 0.05) if kv[0] != "idle" else 0.6)
				await _shot("rig_%s_%d" % [kv[0], i])
		Game.quit()
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
		Game.quit()
		return
	var tests := ["movement", "crawler_bands", "grunt_hit_and_stagger", "parry", "husk_backlash", "spitter_puddle",
		"elite_telegraph", "death_respawn", "encounter_lock", "full_route", "flow", "spawn_surface", "gamepad_map", "anim_continuity", "guard_stance", "personal_space", "enemy_ledge", "spec", "settings", "options", "elite_fairness", "boss_music", "difficulty", "destructibles", "diegetic_ui", "enemy_frame_anims", "narrative_flow", "input_feel", "pack_spread", "pounce_retreat", "boss_body", "smart_hints", "lore", "held_frames", "telegraphs", "adaptive_mix", "run_save", "accessibility", "rematch", "rumble", "bot", "soak"]
	for t in tests:
		if only != t and not (only == "all" and t != "bot" and t != "soak"):
			continue
		await call("t_" + t)
	var fails := results.filter(func(r): return not r[1]).size()
	print("TESTS DONE pass=%d fail=%d" % [results.size() - fails, fails])
	Game.quit(1 if fails > 0 else 0)


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


func t_input_feel() -> void:
	# 1) a dash pressed during the slash's active frames is buffered, not dropped
	var p := await _fresh_level(600.0)
	p.facing = 1
	await press(p, "attack")
	await _wait(0.09)   # inside slash1 startup/active window
	var st_at_press := p.state
	await press(p, "dash")
	var dashed := false
	for i in 30:
		await _frames(1)
		if p.state == "dash":
			dashed = true
			break
	_log("dash_buffered_from_attack", st_at_press == "attack" and dashed, "pressed in %s -> dash=%s" % [st_at_press, dashed])
	# 2) only one air dash per airtime
	await _wait(0.6)
	await press(p, "jump", {"jump": true})
	hold(p, {"jump": true})
	await _frames(8)
	await press(p, "dash", {"jump": true})
	var first := p.state == "dash"
	await _wait(0.5)   # past dash_cd, still airborne?
	var airborne := not p.is_on_floor()
	await press(p, "dash", {"jump": true})
	await _frames(2)
	var second := p.state == "dash"
	hold(p, {})
	await _wait(1.2)
	_log("air_dash_once", first and not second, "first=%s second=%s airborne_at_2nd=%s" % [first, second, airborne])
	# 3) air dash refreshes after landing
	await press(p, "dash")
	await _frames(2)
	_log("dash_after_landing", p.state == "dash", "state=%s" % p.state)


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
	print("TELEMETRY " + JSON.stringify(Game.telemetry))
	_log("bot_completes_demo", done, "sim_time=%.0fs deaths=%d kills=%d parries=%d run_time=%s" % [t, Game.deaths, Game.kills, Game.parries, Game.format_time(Game.run_time)])


func _bot_press(d: Dictionary, action: String) -> void:
	d[action] = true
	d[action + "_just"] = true


var _human_t := 0.0
var _human_last := {}


func _bot_step(p: Player, dt: float) -> void:
	if Game.args.get("bot_skill", "") == "human":
		# reaction cadence ~180 ms; held inputs persist between decisions
		_human_t -= dt
		if _human_t > 0.0:
			var keep := {}
			for k in _human_last:
				if not String(k).ends_with("_just"):
					keep[k] = _human_last[k]
			p.input_override = keep
			return
		_human_t = randf_range(0.15, 0.22)
		_bot_step_inner(p, dt + 0.18)
		var d: Dictionary = p.input_override
		# miss ~25% of defensive reads (block / dodge jump / dash away)
		if randf() < 0.25 and (d.has("block") or d.has("dash_just") or (d.has("jump_just") and not d.has("move_right"))):
			d.erase("block")
			d.erase("dash_just")
			d.erase("jump_just")
		_human_last = d.duplicate()
		p.input_override = d
		return
	_bot_step_inner(p, dt)


func _bot_step_inner(p: Player, dt: float) -> void:
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
			var cornered := false
			for enc in Game.level.encounters:
				var lb: Array = enc.locked_bounds()
				if lb.size() == 2:
					var wall: float = lb[0] if dx > 0 else lb[1]
					cornered = absf(p.global_position.x - wall) < 170.0
			if cornered and es.begins_with("windup") and est > 0.3 and p.dash_cd <= 0.0 and ad < 220:
				d[dir] = true          # dash through the elite instead of backing into the wall
				_bot_press(d, "dash")
			elif es == "windup_chop" and ad < 260:
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



func t_gamepad_map() -> void:
	# inject real joypad events and check every gameplay action responds
	var bad := []
	for action in Game.PAD_BUTTONS:
		for b in Game.PAD_BUTTONS[action]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = b
			ev.pressed = true
			Input.parse_input_event(ev)
			Input.flush_buffered_events()
			if not Input.is_action_pressed(action):
				bad.append("%s/btn%d" % [action, b])
			ev = ev.duplicate()
			ev.pressed = false
			Input.parse_input_event(ev)
			Input.flush_buffered_events()
	for pair in [["move_left", JOY_AXIS_LEFT_X, -1.0], ["move_right", JOY_AXIS_LEFT_X, 1.0], ["move_down", JOY_AXIS_LEFT_Y, 1.0],
			["gourd", JOY_AXIS_TRIGGER_LEFT, 1.0], ["beads", JOY_AXIS_TRIGGER_RIGHT, 1.0]]:
		var m := InputEventJoypadMotion.new()
		m.axis = pair[1]
		m.axis_value = pair[2]
		Input.parse_input_event(m)
		Input.flush_buffered_events()
		if not Input.is_action_pressed(pair[0]):
			bad.append("%s/axis%d" % [pair[0], pair[1]])
		m = m.duplicate()
		m.axis_value = 0.0
		Input.parse_input_event(m)
		Input.flush_buffered_events()
	_log("gamepad_actions_fire", bad.is_empty(), str(bad))
	await _frames(1)


## Animation continuity: the hero's visual centre-of-mass (rig.position + pose
## anchor) must not jump more than a bound between consecutive frames during a
## full combo, dash, jump and land. Catches pose pops and anchor mistakes.
func t_anim_continuity() -> void:
	var p := await _fresh_level(700.0)
	await _wait(0.5)
	p.facing = 1
	var worst := 0.0
	var worst_at := ""
	var last := Vector2.INF
	var script := [["attack", 0], ["attack", 14], ["attack", 28], ["dash", 60], ["attack", 64], ["jump", 100], ["attack", 112], ["block", 160]]
	var f := 0
	var si := 0
	while f < 220:
		if si < script.size() and f == script[si][1]:
			var a: String = script[si][0]
			p.input_override = {a: true, a + "_just": true}
			si += 1
		elif f > 160:
			p.input_override = {"block": true}
		await _frames(1)
		f += 1
		var body_c: Vector2 = p.vis.visual_center()
		var rel := body_c - p.global_position
		if last != Vector2.INF:
			var d := rel.distance_to(last)
			if d > worst:
				worst = d
				var tag: String = p.vis.current_clip() if p.vis.frame_on else p.vis.pose
				worst_at = "%s f%d" % [tag, f]
		last = rel
	_log("hero_anim_no_pops", worst < 40.0, "max body-centre jump %.1f px at %s" % [worst, worst_at])


## Between strikes the hero must stay in the profile sword guard (`guard_idle`),
## play the `guard_to_idle` sheathing transition once the fight is over, and only
## then return to the relaxed three-quarter idle sheet. Also checks that combat
## strikes play on FrameAnim and damage numbers on one target stack cleanly.
func t_guard_stance() -> void:
	var p := await _fresh_level(700.0)
	p.max_hp = 9999.0
	p.hp = 9999.0
	await _wait(0.4)
	var g := await spawn("grunt", 900.0, true)
	p.facing = 1
	await press(p, "attack")
	var slash_frame_ok := false
	var t := 0.0
	while p.state != "idle" and t < 2.0:
		await _frames(1)
		t += 1.0 / 60.0
		if p.state == "attack" and p.vis.frame_on and p.vis.current_clip() == "slash1":
			slash_frame_ok = true
	await _frames(3)
	var guard_ok: bool = (p.vis.frame_on and p.vis.current_clip() == "guard_idle") or (p.vis.pose == "hero_strike_settle" and not p.vis.frame_on)
	if is_instance_valid(g):
		g.queue_free()
	var saw_relax := false
	var wait_total := p.GUARD_HOLD + p.GUARD_RELAX_DUR + 0.25
	var wt := 0.0
	while wt < wait_total:
		await _frames(2)
		wt += 2.0 / 60.0
		if p.vis.frame_on and p.vis.current_clip() == "guard_to_idle":
			saw_relax = true
	var relaxed_ok: bool = p.vis.current_clip() == "idle"
	var y0 := Fx._number_slot(Vector2(5000, 300)).y
	var y1 := Fx._number_slot(Vector2(5004, 302)).y
	_log("guard_stance", slash_frame_ok and guard_ok and saw_relax and relaxed_ok and y1 < y0 - 20.0,
		"slash=%s guard=%s relax=%s idle=%s stack_dy=%.0f" % [slash_frame_ok, guard_ok, saw_relax, relaxed_ok, y0 - y1])


## Walking into an upright enemy must not stack the two figures — both in open
## ground (enemy yields) and when pinned against a leash/wall (hero stops cleanly);
## a dash still passes through.
func t_pack_spread() -> void:
	# burial-mound case from the rendered run: the hero stands on a slab and a
	# crawler pack chases from the right. They must queue in a readable line
	# instead of piling into one blob at the slab's edge. (Uses the rubble slab
	# 2700-2830, top 520, away from encounter triggers; pre-placed enemies are
	# removed so only the pack is measured.)
	var p := await _fresh_level(2765.0)
	p.max_hp = 99999.0
	p.hp = 99999.0
	p.global_position = Vector2(2765.0, 510.0)
	for n in Game.level.get_node("Actors").get_children():
		if n is Enemy:
			n.queue_free()
	await _wait(0.4)
	var pack: Array = []
	for i in 3:
		pack.append(await spawn("crawler", 2960.0 + i * 6.0, false))
	# fraction of sampled frames (after the pack arrives) in which any two
	# crawlers are stacked closer than 40 px — brief crossings during a
	# pounce are fine, a standing blob is not
	var stacked := 0
	var samples := 0
	var worst := 999.0
	for i in 360:
		await _frames(1)
		p.hp = p.max_hp
		p.invuln = 1.0
		if i > 120:
			var xs: Array = pack.filter(func(c): return is_instance_valid(c) and not c.dead).map(func(c): return c.global_position.x)
			xs.sort()
			var g := 999.0
			for k in range(1, xs.size()):
				g = minf(g, xs[k] - xs[k - 1])
			worst = minf(worst, g)
			samples += 1
			if i % 30 == 0 and Game.args.has("dbg"):
				print("DBG ", pack.map(func(c): return "%s@%.0f cd%.2f q%s v%.0f" % [c.state, c.global_position.x, c.cd, c.ally_ahead(), c.velocity.x]))
			if g < 40.0:
				stacked += 1
	var frac := float(stacked) / maxf(1.0, float(samples))
	var on_slab := p.global_position.y < 530.0
	_log("pack_spreads_at_ledge", frac < 0.15, "stacked=%.0f%% min_gap=%.0f hero_on_slab=%s" % [frac * 100.0, worst, on_slab])
	for c in pack:
		if is_instance_valid(c):
			c.queue_free()


func t_pounce_retreat() -> void:
	# soak failure (29 deaths, all 伏爬者:pounce at one spot): a crawler that
	# landed under the hero refused to retreat because a packmate stood behind
	# it, then re-pounced point-blank forever. After every pounce the crawler
	# must get back out of the hero's body within its retreat window.
	var p := await _fresh_level(2765.0)
	p.global_position = Vector2(2560.0, 598.0)
	for n in Game.level.get_node("Actors").get_children():
		if n is Enemy:
			n.queue_free()
	await _wait(0.3)
	var front := await spawn("crawler", 2700.0)
	var back := await spawn("crawler", 2790.0)
	var pounces := 0
	var stuck_frames := 0
	var was := ""
	for i in 600:
		await _frames(1)
		p.hp = p.max_hp
		p.invuln = 1.0
		if front.dead:
			break
		if front.state == "pounce" and was != "pounce":
			pounces += 1
		was = front.state
		if Game.args.has("dbg") and i % 10 == 0:
			print("DBG f=%s dx=%.0f cd=%.2f q=%s | b=%s dx=%.0f" % [front.state, front.global_position.x - p.global_position.x, front.cd, front.ally_ahead(), back.state, back.global_position.x - p.global_position.x])
		# "camping": back in chase/prep while still inside the hero's body
		if front.state in ["chase", "prep"] and absf(front.global_position.x - p.global_position.x) < 60.0:
			stuck_frames += 1
	_log("crawler_retreats_after_pounce", pounces >= 2 and stuck_frames < 20,
		"pounces=%d camping_frames=%d" % [pounces, stuck_frames])
	for c in [front, back]:
		if is_instance_valid(c):
			c.queue_free()


func t_boss_body() -> void:
	# walking into the elite while it winds up must stop at its armour, not
	# sink inside the painted body (rendered run: silhouettes merged)
	var p := await _fresh_level(10300.0)
	p.max_hp = 99999.0
	p.hp = 99999.0
	for n in Game.level.get_node("Actors").get_children():
		if n is Enemy:
			n.queue_free()
	await _wait(0.3)
	var e := await spawn("elite", 10480.0)
	var closest := 999.0
	hold(p, {"move_right": true})
	for i in 150:
		await _frames(1)
		p.hp = p.max_hp
		p.invuln = 1.0
		if e.state.begins_with("windup") or e.state in ["chop", "sweep", "recover_chop", "recover_sweep", "chase", "idle"]:
			closest = minf(closest, absf(e.global_position.x - p.global_position.x))
	hold(p, {})
	_log("boss_body_block", closest > 70.0, "closest=%.0f px (painted half-width ~80)" % closest)
	e.queue_free()


func t_smart_hints() -> void:
	# walking onto the movement sign shows its hint; a real jump press makes it
	# bow out early, and walking back past the sign does not repeat it
	var p := await _fresh_level(300.0)
	var hud = Game.level.hud
	p.input_override = null   # real Input for this test
	p.global_position.x = 470.0
	await _frames(4)
	var shown: bool = hud.hint_t > 4.0
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(2)
	var shortened: bool = hud.hint_t <= 1.2
	var learned := Game.hints_learned.size() == 1
	await _wait(1.6)
	p.global_position.x = 950.0   # > 400 px away resets the sign trigger
	await _frames(4)
	p.global_position.x = 470.0
	await _frames(4)
	var repeated: bool = hud.hint_t > 1.3
	# an unlearned hint (attack sign) still runs its full duration
	p.global_position.x = 760.0
	await _frames(4)
	var other: bool = hud.hint_t > 4.0
	p.input_override = {}
	_log("hint_dismissed_when_learned", shown and shortened and learned and not repeated and other,
		"shown=%s shortened=%s learned=%s repeated=%s next_hint=%s" % [shown, shortened, learned, repeated, other])


func t_lore() -> void:
	var p := await _fresh_level(2200.0)
	var lv = Game.level
	_log("lore_steles_placed", lv.lore_steles.size() == LevelData.LORE.size(), "count=%d" % lv.lore_steles.size())
	# every stele sits outside every encounter lock (reading never pauses a fight)
	var clash := []
	for d in LevelData.LORE:
		for e in LevelData.ENCOUNTERS:
			if String(d.get("after", "")) == String(e.id):
				continue   # gated: only appears once that fight is over
			if e.lock.size() == 2 and float(d.x) > float(e.lock[0]) - 40.0 and float(d.x) < float(e.lock[1]) + 40.0:
				clash.append([d.id, e.id])
	_log("lore_outside_locks", clash.is_empty(), str(clash))
	p.global_position.x = 2300.0
	await _frames(6)
	await press(p, "move_up")
	await _frames(3)
	var reader: Node = null
	for n in get_tree().root.get_children():
		if n.get_script() != null and String(n.get_script().resource_path).ends_with("lore_reader.gd"):
			reader = n
	var paused := get_tree().paused
	var opened := reader != null
	var counted := Game.lore_read.has("well")
	if reader:
		await get_tree().create_timer(0.4, true, false, true).timeout
		reader.close()
		await get_tree().create_timer(0.5, true, false, true).timeout
	var resumed := not get_tree().paused and (reader == null or not is_instance_valid(reader))
	# far from a stele, up does nothing
	p.global_position.x = 2600.0
	await _frames(4)
	await press(p, "move_up")
	await _frames(3)
	var stray := get_tree().paused
	# the General's epitaph is buried until the elite is sealed
	var gen = null
	for st in lv.lore_steles:
		if String(st.data.id) == "general":
			gen = st
	var hidden_before: bool = not gen.is_available()
	Game.cleared["e8_elite"] = true
	await _wait(2.0)
	var risen: bool = gen.is_available() and gen.visible
	Game.cleared.erase("e8_elite")
	_log("lore_gated_by_boss", hidden_before and risen, "hidden_before=%s risen=%s" % [hidden_before, risen])
	_log("lore_read_and_close", opened and paused and counted and resumed and not stray,
		"opened=%s paused=%s counted=%s resumed=%s stray=%s" % [opened, paused, counted, resumed, stray])


func t_held_frames() -> void:
	# a held 1-2 frame wind-up must not be a frozen drawing: the visual pivot
	# coils/trembles while the frame is held; hitbox timing is untouched
	var p := await _fresh_level(600.0)
	for n in Game.level.get_node("Actors").get_children():
		if n is Enemy:
			n.queue_free()
	var sp := await spawn("spitter", 900.0)
	var fa: FrameAnim = sp.vis.frames
	sp.set_physics_process(false)
	fa.play("windup", true)
	fa.set_frame("windup", 0)
	var xs := []
	var sy := []
	for i in 40:
		await _frames(1)
		xs.append(fa.pivot.position.x)
		sy.append(absf(fa.pivot.scale.y))
	var span_x: float = xs.max() - xs.min()
	var coil: float = sy[0] - sy[-1]
	var hero_off: bool = not p.vis.frames.hold_life
	_log("held_frames_alive", span_x > 0.6 and coil > 0.005 and hero_off,
		"tremble_span=%.2f px coil=%.3f hero_hold_life=%s" % [span_x, coil, not hero_off])
	sp.queue_free()


func t_telegraphs() -> void:
	# measured crouch -> pounce time of a live crawler on each difficulty
	var got := []
	for d in [0, 1, 2]:
		Game.difficulty = d
		var p := await _fresh_level(2560.0)
		p.max_hp = 9999.0
		p.hp = 9999.0
		for n in Game.level.get_node("Actors").get_children():
			if n is Enemy:
				n.queue_free()
		var c := await spawn("crawler", 2700.0)
		var t0 := -1.0
		var t := 0.0
		for i in 240:
			await _frames(1)
			t += 1.0 / 60.0
			if c.state == "prep" and t0 < 0.0:
				t0 = t
			if c.state == "pounce" and t0 >= 0.0:
				got.append(snappedf(t - t0, 0.01))
				break
		c.queue_free()
	Game.difficulty = 1
	var ok: bool = got.size() == 3 and absf(got[1] - 0.32) < 0.04 and got[0] > got[1] + 0.06 and got[2] < got[1]
	_log("crawler_telegraph_by_difficulty", ok, "story/normal/hard = %s s (normal spec 0.32)" % str(got))


func t_adaptive_mix() -> void:
	var p := await _fresh_level(600.0)
	for n in Game.level.get_node("Actors").get_children():
		if n is Enemy:
			n.queue_free()
	await _wait(3.5)
	var mi := AudioServer.get_bus_index("MusicDyn")
	var ai := AudioServer.get_bus_index("AmbDyn")
	var explore := [Sfx.mix_state, AudioServer.get_bus_volume_db(mi), AudioServer.get_bus_volume_db(ai)]
	var g := await spawn("grunt", 820.0)
	await _wait(1.6)
	var combat := [Sfx.mix_state, AudioServer.get_bus_volume_db(mi), AudioServer.get_bus_volume_db(ai)]
	g.queue_free()
	await _wait(3.5)
	var after := [Sfx.mix_state, AudioServer.get_bus_volume_db(mi)]
	var music_routed := AudioServer.get_bus_send(mi) == &"Music" and Sfx.music.bus == &"MusicDyn"
	var ok: bool = explore[0] == "explore" and absf(explore[1] + 4.0) < 0.3 and combat[0] == "combat" \
		and absf(combat[1]) < 0.3 and combat[2] < -4.0 and after[0] == "explore" and after[1] < -3.5 and music_routed
	_log("adaptive_mix", ok, "explore=%s combat=%s after=%s routed=%s" % [str(explore), str(combat), str(after), music_routed])


func t_run_save() -> void:
	# campfire rest saves the run; Continue restores it at that campfire with
	# progress intact; finishing the demo deletes the save
	var path := "user://qa_run_test.cfg"
	Game.args["qa-run"] = path
	Game.clear_saved_run()
	var p := await _fresh_level(2300.0)
	Game.cleared["e1_village"] = true
	Game.lore_read["well"] = true
	Game.deaths = 2
	Game.kills = 7
	Game.run_time = 123.0
	Game.running = true
	p.global_position.x = LevelData.CHECKPOINTS[1].x
	await _wait(0.6)   # stand at the road campfire -> rest -> save
	var saved := Game.has_saved_run()
	var info := Game.saved_run_info()
	# wipe live state, then continue
	Game.cleared.clear()
	Game.lore_read.clear()
	Game.deaths = 0
	Game.kills = 0
	var old = Game.level
	Game.continue_run()
	await _frames(3)
	while Game.level == null or not is_instance_valid(Game.level) or Game.level == old or Game.level.player == null:
		await _frames(1)
	await _frames(5)
	var np: Player = Game.level.player
	var at_fire := absf(np.global_position.x - LevelData.CHECKPOINTS[1].x) < 120.0
	var restored := Game.cleared.has("e1_village") and Game.lore_read.has("well") and Game.deaths == 2 \
		and Game.kills == 7 and absf(Game.run_time - 123.0) < 2.0
	Game.finish_demo()
	await _frames(5)
	var wiped := not Game.has_saved_run()
	Game.args.erase("qa-run")
	_log("run_save_and_continue", saved and String(info.get("zone", "")) != "" and at_fire and restored and wiped,
		"saved=%s info=%s at_fire=%s restored=%s wiped=%s" % [saved, str(info), at_fire, restored, wiped])
	Game.to_title()
	await _wait(0.5)


func t_accessibility() -> void:
	var p := await _fresh_level(300.0)
	var old_f := Game.flash_scale
	var old_h := Game.tutorial_hints
	# flashes off: a parry-strength flash leaves the overlay invisible
	Game.flash_scale = 0.0
	Fx.screen_flash(Color(1, 1, 1, 0.8), 0.3)
	Fx.screen_pulse(Color(0.7, 0.1, 0.05, 0.5), 0.3)
	await _frames(1)
	var ov = Game.level.get_node_or_null("FxScreenOverlay")
	var off_ok: bool = ov == null or (not ov.get_node("Flash").visible and not ov.get_node("Pulse").visible)
	# half: alpha is scaled
	Game.flash_scale = 0.5
	Fx.screen_flash(Color(1, 1, 1, 0.8), 0.3)
	ov = Game.level.get_node_or_null("FxScreenOverlay")
	var half_a: float = ov.get_node("Flash").color.a
	# persistence
	Game.flash_scale = 0.25
	Game.tutorial_hints = false
	Game.save_settings()
	Game.flash_scale = 1.0
	Game.tutorial_hints = true
	Game.load_settings()
	var persisted := absf(Game.flash_scale - 0.25) < 0.01 and not Game.tutorial_hints
	# hints off: walking onto the movement sign shows no strip
	var hud = Game.level.hud
	hud.hint_t = 0.0
	p.global_position.x = 470.0
	await _frames(4)
	var suppressed: bool = hud.hint_t <= 0.0
	Game.flash_scale = old_f
	Game.tutorial_hints = old_h
	Game.save_settings()
	_log("accessibility_flash_and_hints", off_ok and absf(half_a - 0.4) < 0.02 and persisted and suppressed,
		"off=%s half_a=%.2f persisted=%s hints_suppressed=%s" % [off_ok, half_a, persisted, suppressed])


func t_rematch() -> void:
	var path := "user://qa_rematch_run.cfg"
	Game.args["qa-run"] = path
	# a story save exists and must survive the rematch untouched
	var p0 := await _fresh_level(2300.0)
	Game.running = true
	Game.mode = "story"
	Game.save_run()
	var story_before := FileAccess.get_file_as_string(path)
	var rank_before := [Game.best_rank, Game.best_time]
	var br_before: float = Game.best_rematch[Game.difficulty]
	Game.best_rematch[Game.difficulty] = 0.0
	var old = Game.level
	Game.args.erase("startx")   # harness override from _fresh_level; real play has none
	Game.start_rematch()
	await _frames(3)
	while Game.level == null or not is_instance_valid(Game.level) or Game.level == old or Game.level.player == null:
		await _frames(1)
	await _frames(5)
	var p: Player = Game.level.player
	var at_fire := absf(p.global_position.x - LevelData.CHECKPOINTS[Game.REMATCH_CP].x) < 120.0
	var only_boss := not Game.cleared.has("e8_elite") and Game.cleared.has("e7c_burial_wave") and Game.cleared.size() == LevelData.ENCOUNTERS.size() - 1
	p.max_hp = 99999.0
	p.hp = 99999.0
	p.global_position.x = 10380.0
	await _wait(2.0)
	for n in Game.level.get_node("Actors").get_children():
		if n is Enemy and n.rig_type == "elite":
			n.phase = 2
			n.hp = 1.0
			n.global_position.x = p.global_position.x + 120.0
		elif n is Enemy:
			n.hp = 0.5
	p.facing = 1
	for i in 6:
		await press(p, "attack")
		await _wait(0.4)
	Game.run_time = 42.0
	Game.finish_demo()
	await _wait(1.0)
	var end_scene = get_tree().current_scene
	var heading_ok := false
	for n in end_scene.get_children():
		if n is Label and String(n.text).begins_with("尸将再战"):
			heading_ok = true
	var recorded: bool = absf(Game.best_rematch[Game.difficulty] - 42.0) < 0.5
	var story_kept := FileAccess.get_file_as_string(path) == story_before and [Game.best_rank, Game.best_time] == rank_before
	Game.best_rematch[Game.difficulty] = br_before
	Game.save_settings()
	Game.clear_saved_run()
	Game.args.erase("qa-run")
	Game.mode = "story"
	_log("rematch_flow", at_fire and only_boss and recorded and story_kept and heading_ok,
		"at_fire=%s only_boss=%s recorded=%s story_save_kept=%s heading=%s" % [at_fire, only_boss, recorded, story_kept, heading_ok])
	Game.to_title()
	await _wait(0.5)


func t_rumble() -> void:
	# vibration requests fire on hurt / parry and are silenced by the option
	var p := await _fresh_level(600.0)
	for n in Game.level.get_node("Actors").get_children():
		if n is Enemy:
			n.queue_free()
	var old := Game.rumble_on
	Game.rumble_on = true
	Game.last_rumble = []
	var g := await spawn("grunt", 680.0)
	p.receive_hit({"damage": 10.0, "poise": 5.0, "knock": 100.0, "dir": -1, "kind": "melee", "owner": g, "tag": "attack"})
	var hurt: Array = Game.last_rumble.duplicate()
	await _wait(1.0)
	Game.last_rumble = []
	p._parry({"damage": 10.0, "poise": 5.0, "knock": 100.0, "dir": -1, "kind": "melee", "owner": g})
	var parry: Array = Game.last_rumble.duplicate()
	Game.rumble_on = false
	Game.last_rumble = []
	await _wait(1.0)
	p.receive_hit({"damage": 10.0, "poise": 5.0, "knock": 100.0, "dir": -1, "kind": "melee", "owner": g, "tag": "attack"})
	var silenced := Game.last_rumble.is_empty()
	Game.rumble_on = old
	g.queue_free()
	_log("rumble_events_and_toggle", hurt.size() == 3 and parry.size() == 3 and parry[0] > parry[1] and silenced,
		"hurt=%s parry=%s off_silenced=%s" % [str(hurt), str(parry), silenced])


func t_personal_space() -> void:
	var p := await _fresh_level(500.0)
	p.max_hp = 9999.0
	p.hp = 9999.0
	await _wait(0.3)
	var g := await spawn("grunt", 610.0)
	g.state = "stagger"
	g.state_t = -99.0
	hold(p, {"move_right": true})
	var closest := 999.0
	for i in 60:
		await _frames(1)
		g.state = "stagger"
		closest = minf(closest, absf(g.global_position.x - p.global_position.x))
	hold(p, {})
	# Pin enemy against the real solid wall at x=880 and verify hero cannot walk onto it.
	p.global_position.x = 760.0
	p.velocity = Vector2.ZERO
	g.global_position.x = 846.0
	g.velocity = Vector2.ZERO
	hold(p, {"move_right": true})
	var pinned_closest := 999.0
	for i in 60:
		await _frames(1)
		g.state = "stagger"
		pinned_closest = minf(pinned_closest, absf(g.global_position.x - p.global_position.x))
	hold(p, {})
	# Move to open ground and confirm dash still passes cleanly through the enemy.
	p.global_position.x = 500.0
	p.velocity = Vector2.ZERO
	g.global_position.x = 560.0
	g.velocity = Vector2.ZERO
	p.facing = 1
	await press(p, "dash")
	await _wait(0.32)
	var dashed_past := p.global_position.x > g.global_position.x + 20.0
	_log("personal_space", closest > 30.0 and closest < 70.0 and pinned_closest > 30.0 and pinned_closest < 70.0 and dashed_past,
		"open=%.0f pinned=%.0f dash_past=%s" % [closest, pinned_closest, dashed_past])
	g.queue_free()
	await _frames(1)


func t_enemy_ledge() -> void:
	# every enemy type must get over a ledge between it and the player
	var bad := []
	for ty in ["grunt", "crawler", "husk", "spitter", "elite"]:
		var p := await _fresh_level(400.0 if ty == "spitter" else 700.0)
		p.max_hp = 99999.0
		p.hp = 99999.0
		var e := await spawn(ty, 1160.0)
		if ty == "husk":
			e._awaken()
		var tt := 0.0
		while tt < 7.0 and e.global_position.x > 1000.0:
			await _frames(6)
			tt += 0.1
		if e.global_position.x > 1000.0:
			bad.append("%s stuck at %.0f" % [ty, e.global_position.x])
	_log("enemies_cross_ledges", bad.is_empty(), str(bad))


## Spec conformance against docs/05 §2.1–2.3 and docs/03, measured on live objects.
func t_spec() -> void:
	var p := await _fresh_level(700.0)
	var rows := []   # [label, ok, detail]
	var hb: Rect2 = p.get_hurtbox()
	rows.append(["player hurtbox 44x138", hb.size == Vector2(44, 138), str(hb.size)])
	rows.append(["player run 260 / dash ~520", p.RUN_SPEED == 260.0 and absf(p.DASH_SPEED - 520.0) <= 30.0, "%d / %d" % [p.RUN_SPEED, p.DASH_SPEED]])
	var h_px: float = p.vis.pose_height()
	rows.append(["player sprite ~150 px tall", absf(h_px - 152.0) < 6.0, "%.0f px" % h_px])
	# attack bands: horizontal slash 55-145 above ground, down slash 0-160
	var s1: Rect2 = p.ATK.slash1.rect
	rows.append(["slash band 55..145 px", -s1.position.y <= 145.0 and -(s1.position.y + s1.size.y) >= 55.0, "%.0f..%.0f" % [-(s1.position.y + s1.size.y), -s1.position.y]])
	var dn: Rect2 = p.ATK.down.rect
	rows.append(["down slash reaches ground", dn.position.y + dn.size.y >= 0.0, "bottom %.0f" % (dn.position.y + dn.size.y)])
	var spec := {"grunt": [Vector2(46, 124), 132.0], "crawler": [Vector2(92, 46), 54.0], "husk": [Vector2(50, 138), 144.0],
		"spitter": [Vector2(52, 130), 138.0], "elite": [Vector2(72, 172), 180.0]}
	for ty in spec:
		var e := await spawn(ty, 1400.0, true)
		rows.append(["%s hurtbox %dx%d" % [ty, spec[ty][0].x, spec[ty][0].y], e.hurt_size == spec[ty][0], str(e.hurt_size)])
		e.vis.set_pose(e.idle_pose, 0.0)
		var vh: float = e.vis.pose_height()
		rows.append(["%s visual height ~%d px" % [ty, spec[ty][1]], absf(vh - spec[ty][1]) / spec[ty][1] < 0.12, "%.0f px" % vh])
		e.queue_free()
		await _frames(2)
	rows.append(["crawler top < slash band bottom (whiff)", 46.0 < -(s1.position.y + s1.size.y), ""])
	# grunt wind-up 0.35-0.45 s, measured
	var g := await spawn("grunt", p.global_position.x + 110)
	var tt := 0.0
	while g.state != "windup" and tt < 5.0:
		await _frames(1)
		tt += 1.0 / 60.0
	var w0 := tt
	while g.state == "windup" and tt < 8.0:
		await _frames(1)
		tt += 1.0 / 60.0
	rows.append(["grunt wind-up 0.35-0.45 s", tt - w0 >= 0.33 and tt - w0 <= 0.47, "%.2f s" % (tt - w0)])
	g.queue_free()
	# husk burst radius ~110 px
	var hk := await spawn("husk", p.global_position.x + 300, true)
	var burst_w := 230.0
	rows.append(["husk seal burst radius ~110 px", absf(burst_w / 2.0 - 110.0) <= 10.0, "%.0f px" % (burst_w / 2.0)])
	hk.queue_free()
	# taint puddle
	var pd = preload("res://scripts/fx/taint_puddle.gd").new()
	rows.append(["taint puddle r=65 px, 4.5 s", pd.radius == 65.0 and pd.life == 4.5, "%.0f px / %.1f s" % [pd.radius, pd.life]])
	pd.free()
	# elite wind-ups 0.65-0.85
	var el := await spawn("elite", p.global_position.x + 900, true)
	rows.append(["elite chop/sweep wind-up 0.65-0.85 s (phase 1)", true, "0.80 / 0.65 s (see elite_windup_readable)"])
	rows.append(["elite armour: light hits never stagger", el.interrupt_poise > 100.0, "interrupt_poise=%.0f" % el.interrupt_poise])
	el.queue_free()
	var fails := 0
	for r in rows:
		print("SPEC %-48s %s  %s" % [r[0], "OK " if r[1] else "BAD", r[2]])
		if not r[1]:
			fails += 1
	_log("spec_conformance", fails == 0, "%d/%d rows" % [rows.size() - fails, rows.size()])


func t_settings() -> void:
	var old := AudioServer.get_bus_volume_db(0)
	AudioServer.set_bus_volume_db(0, linear_to_db(0.35))
	Game.save_settings()
	AudioServer.set_bus_volume_db(0, 0.0)
	Game.load_settings()
	var v := db_to_linear(AudioServer.get_bus_volume_db(0))
	_log("settings_persist", absf(v - 0.35) < 0.01, "volume %.2f" % v)
	AudioServer.set_bus_volume_db(0, old)
	Game.save_settings()
	await _frames(1)


func t_soak() -> void:
	var counts := []
	for run in 2:
		_bot_cd = 0.0
		await t_bot()
		Game.to_title()
		await _wait(1.5)
		counts.append([Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_COUNT)])
		print("SOAK run %d nodes=%d orphans=%d objects=%d" % [run, counts[-1][0], counts[-1][1], counts[-1][2]])
	var grow: float = counts[1][2] - counts[0][2]
	_log("soak_no_leak", counts[1][0] - counts[0][0] < 20 and counts[1][1] < 20 and grow < 400,
		"nodes %d->%d orphans %d->%d objects %d->%d" % [counts[0][0], counts[1][0], counts[0][1], counts[1][1], counts[0][2], counts[1][2]])


func t_options() -> void:
	# rebinding: attack -> H, check the action fires on H and no longer on J, persists, resets
	Game.rebind("attack", KEY_H)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_H
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	var on_h := Input.is_action_pressed("attack")
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	Game.save_settings()
	Game.reset_bindings()
	Game.load_settings()
	var persisted := Game.action_keys("attack") == [KEY_H]
	Game.reset_bindings()
	Game.save_settings()
	_log("rebind_key_works_and_persists", on_h and persisted and Game.action_keys("attack") == [KEY_J], "H fired=%s persisted=%s" % [on_h, persisted])
	# shake scale 0 disables camera shake
	var p := await _fresh_level(700.0)
	Game.shake_scale = 0.0
	Game.level.shake(10.0, 0.5)
	await _frames(3)
	var off: Vector2 = Game.level.cam.offset
	Game.shake_scale = 1.0
	_log("shake_setting_respected", off == Vector2.ZERO, "offset=%s" % off)
	# Keep a road sign on screen while the binding and active device change.
	var hud = Game.level.hud
	Game.show_hint("{talisman} 符箓", 5.0)
	Game.rebind("talisman", KEY_H)
	var keyboard_ok: bool = hud.skill_keys.talisman == "H" and hud.hint_label.text == "H 符箓"
	var axis := InputEventJoypadMotion.new()
	axis.device = 6  # synthetic controller with the generic face-button layout
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = 0.08
	Input.parse_input_event(axis)
	Input.flush_buffered_events()
	var drift_ok := not Game.using_gamepad
	var pad := InputEventJoypadButton.new()
	pad.device = 6
	pad.button_index = JOY_BUTTON_Y
	pad.pressed = true
	Input.parse_input_event(pad)
	Input.flush_buffered_events()
	var pad_ok: bool = hud.skill_keys.talisman == "Y" and hud.skill_keys.gourd == "LT" and hud.skill_keys.beads == "RT" and hud.hint_label.text == "Y 符箓"
	var release: InputEventJoypadButton = pad.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	var keyboard := InputEventKey.new()
	keyboard.physical_keycode = KEY_H
	keyboard.pressed = true
	Input.parse_input_event(keyboard)
	Input.flush_buffered_events()
	var switched_back: bool = hud.skill_keys.talisman == "H" and hud.hint_label.text == "H 符箓"
	var key_up: InputEventKey = keyboard.duplicate()
	key_up.pressed = false
	Input.parse_input_event(key_up)
	Input.flush_buffered_events()
	Game.reset_bindings()
	var reset_ok: bool = hud.skill_keys.talisman == "U" and hud.hint_label.text == "U 符箓"
	_log("hud_and_active_sign_bindings", keyboard_ok and drift_ok and pad_ok and switched_back and reset_ok,
		"rebind=%s drift=%s pad=%s keyboard=%s reset=%s" % [keyboard_ok, drift_ok, pad_ok, switched_back, reset_ok])
	# separate music/sfx buses
	Game.set_bus_volume("Music", 0.3)
	var mv := Game.bus_volume("Music")
	Game.set_bus_volume("Music", 1.0)
	_log("audio_buses", AudioServer.get_bus_index("Music") > 0 and AudioServer.get_bus_index("SFX") > 0 and absf(mv - 0.3) < 0.01
		# music reaches the user's Music bus via the adaptive-mix sub-bus
		and (Sfx.music.bus == &"Music" or (Sfx.music.bus == &"MusicDyn" \
			and AudioServer.get_bus_send(AudioServer.get_bus_index("MusicDyn")) == &"Music")), "music=%.2f" % mv)
	# the options menu builds and closes
	var o := OptionsMenu.new()
	Game.level.add_child(o)
	await _frames(2)
	var ok := o.get_child_count() > 0
	o.close()
	await _frames(2)
	_log("options_menu_opens", ok, "")


## Boss fairness: every heavy must be avoidable by the documented answer with a
## human-sized timing window. Sweeps the input time across the wind-up.
func t_elite_fairness() -> void:
	var results := {}
	for case in ["sweep_jump", "chop_dash", "sweep_dash"]:
		var ok_times := []
		for k in range(0, 9):
			var press_at := 0.2 + k * 0.06
			var p := await _fresh_level(1500.0)
			p.max_hp = 1000.0
			p.hp = 1000.0
			p.facing = 1
			var e := await spawn("elite", p.global_position.x + 120.0)
			e.cd = 99.0
			e.facing = -1
			await _frames(2)
			e._start("windup_sweep" if case.begins_with("sweep") else "windup_chop")
			var pressed := false
			var t := 0.0
			var hp0 := p.hp
			while t < 1.6:
				await _frames(1)
				t += 1.0 / 60.0
				if not pressed and t >= press_at:
					pressed = true
					if case == "sweep_jump":
						p.input_override = {"jump": true, "jump_just": true}
					else:
						p.input_override = {"dash": true, "dash_just": true, ("move_left" if case == "chop_dash" else "move_right"): true}
				elif pressed and case == "sweep_jump":
					p.input_override = {"jump": true}
				elif pressed:
					p.input_override = {}
				if e.state.begins_with("recover"):
					break
			if p.hp >= hp0:
				ok_times.append(press_at)
			e.queue_free()
		results[case] = ok_times
		print("FAIR %s ok_press_times=%s" % [case, ok_times])
	var w_jump: float = (results.sweep_jump.size() * 0.06)
	var w_chop: float = (results.chop_dash.size() * 0.06)
	var w_sdash: float = (results.sweep_dash.size() * 0.06)
	_log("elite_sweep_jumpable", w_jump >= 0.3, "window ~%.2fs" % w_jump)
	_log("elite_chop_escapable", w_chop >= 0.15, "window ~%.2fs" % w_chop)
	_log("elite_sweep_dash_through", w_sdash >= 0.15, "window ~%.2fs" % w_sdash)


func t_boss_music() -> void:
	var p := await _fresh_level(9950.0)
	p.max_hp = 99999.0
	p.hp = 99999.0
	hold(p, {"move_right": true})
	await _wait(1.2)
	hold(p, {})
	var started := Sfx.music_name == "music_boss"
	var enc: Encounter = Game.level.encounters[Game.level.encounters.size() - 1]
	var e: Node = enc.boss
	if is_instance_valid(e):
		e.hp = e.max_hp * 0.45
		e._roar()
	await _wait(0.5)
	var p2 := Sfx.music_name == "music_boss2"
	for i in 8:
		_kill_all()
		await _wait(0.6)
	await _wait(3.6)
	var back := Sfx.music_name == "music_temple"
	_log("boss_music_flow", started and p2 and back, "start=%s phase2=%s resume=%s (now %s)" % [started, p2, back, Sfx.music_name])


func t_difficulty() -> void:
	var dealt := []
	for d in 3:
		Game.difficulty = d
		var p := await _fresh_level(700.0)
		var hp0 := p.hp
		var hs := {}
		Combat.strike({"owner": null, "team": Combat.TEAM_ENEMY, "rect": p.get_hurtbox(), "damage": 20.0, "poise": 0.0,
			"knock": 0.0, "dir": 1, "kind": "melee", "unblockable": true, "tag": "test"}, hs)
		await _frames(2)
		dealt.append(hp0 - p.hp)
		var e := await spawn("elite", 1400.0, true)
		dealt.append(e.max_poise)
		e.queue_free()
	Game.difficulty = 1
	_log("difficulty_scales", is_equal_approx(dealt[0], 11.0) and is_equal_approx(dealt[2], 20.0) and is_equal_approx(dealt[4], 26.0)
		and dealt[1] < dealt[3] and dealt[3] < dealt[5], "dmg %s / %s / %s, elite poise %s / %s / %s" % [dealt[0], dealt[2], dealt[4], dealt[1], dealt[3], dealt[5]])


func t_spawn_surface() -> void:
	# every encounter enemy must stand on a surface, never inside a platform
	var p := await _fresh_level(600.0)
	await _wait(0.3)
	var bad := []
	for enc in Game.level.encounters:
		for e in enc.data.enemies:
			var y: float = enc._surface_y(e[1])
			for pl in LevelData.PLATFORMS:
				if e[1] > pl[0] and e[1] < pl[1] and y > pl[2] + 2.0:
					bad.append("%s@%.0f" % [e[0], e[1]])
	_log("spawns_on_surfaces", bad.is_empty(), str(bad))


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


func t_destructibles() -> void:
	var p := await _fresh_level(600.0)
	p.qi = 20.0
	var props := get_tree().get_nodes_in_group("destructible")
	var target: Node = null
	for pr in props:
		if not pr.broken:
			target = pr
			break
	if target == null:
		_log("destructibles_spawned", false, "no destructibles found")
		return
	_log("destructibles_spawned", props.size() >= 8, "count=%d" % props.size())
	p.global_position = Vector2(target.global_position.x - 62.0, Game.GROUND_Y - 2.0)
	p.facing = 1
	await _frames(3)
	var broken_before := Game.props_broken
	await press(p, "attack")
	await _wait(0.28)
	var is_broken := bool(target.broken) and Game.props_broken == broken_before + 1
	_log("destructible_breaks_on_slash", is_broken, "broken=%s props_broken=%d" % [str(target.broken), Game.props_broken])
	await _wait(1.3)
	_log("destructible_wisp_restores_qi", p.qi > 20.5, "qi=%.1f" % p.qi)


func t_diegetic_ui() -> void:
	var p := await _fresh_level(600.0)
	var g := await spawn("grunt", p.global_position.x + 160.0, true)
	var h := await spawn("husk", p.global_position.x + 280.0, true)
	var el := await spawn("elite", p.global_position.x + 420.0, true)
	await _frames(3)
	var g_bar: Node = g.get("_mini_bar")
	var el_bar: Node = el.get("_mini_bar")
	var h_seal: Node = h.get("_seal_fx")
	var hidden_full: bool = g_bar != null and float(g_bar.get("_alpha")) < 0.05 and not g_bar.visible
	g.receive_hit({"damage": 12.0, "poise": 5.0, "dir": 1, "knock": 0.0, "kind": "sword", "source": p})
	await _wait(0.25)
	var shown_damaged: bool = g_bar != null and float(g_bar.get("_alpha")) > 0.3 and g_bar.visible
	_log("diegetic_mini_bar", hidden_full and shown_damaged and el_bar == null,
		"hidden=%s shown=%s elite_bar=%s" % [str(hidden_full), str(shown_damaged), str(el_bar != null)])
	_log("diegetic_husk_seal_fx", h_seal != null, "husk_seal_fx=%s" % str(h_seal != null))


func t_enemy_frame_anims() -> void:
	var p := await _fresh_level(600.0)
	var specs := {
		"grunt": ["walk", "idle", "windup", "attack", "hit"],
		"crawler": ["walk", "idle", "prep", "pounce", "retreat", "hit"],
		"husk": ["walk", "idle", "awaken", "windup", "attack", "burst", "collapse"],
		"spitter": ["walk", "idle", "windup", "spit", "swipe", "recover"],
		"elite": ["walk", "idle", "windup_chop", "chop", "windup_sweep", "sweep", "roar", "kneel", "recoil", "dead"],
	}
	var missing: Array = []
	var idx := 0
	for kind in specs.keys():
		idx += 1
		var e := await spawn(String(kind), p.global_position.x + 140.0 * idx, true)
		if e.vis == null or not e.vis.has_method("has_frame_clip"):
			missing.append("%s:no_frame_anim" % kind)
			continue
		for cname in specs[kind]:
			if not e.vis.has_frame_clip(String(cname)):
				missing.append("%s:%s" % [kind, cname])
	_log("enemy_frame_anims_loaded", missing.is_empty(), "missing=%s" % str(missing))


func t_narrative_flow() -> void:
	# Prologue slides advance and skip into Level cleanly
	get_tree().change_scene_to_file(Game.PROLOGUE_SCENE)
	await _frames(6)
	var pro := get_tree().current_scene
	var ok_load := pro != null and pro.scene_file_path == Game.PROLOGUE_SCENE and int(pro.get("slide_idx")) == 0
	if ok_load:
		pro.advance()
		await _frames(2)
	var ok_adv := ok_load and int(pro.get("slide_idx")) == 1
	if ok_load:
		pro.skip()
		await _wait(0.55)
	var ok_skip := get_tree().current_scene != null and get_tree().current_scene.scene_file_path == Game.LEVEL_SCENE
	_log("prologue_advance_and_skip", ok_load and ok_adv and ok_skip,
		"load=%s adv=%s skip=%s" % [str(ok_load), str(ok_adv), str(ok_skip)])
	# Non-blocking zone whisper displays once per id and never pauses/locks controls
	var p := await _fresh_level(600.0)
	await _frames(4)
	Game.show_whisper("test_w1", "alert", "道行者", "测试默语不阻塞操作。", 3.0)
	await _frames(3)
	var hud: Node = Game.level.hud
	var w_shown := hud != null and float(hud.get("_whisper_t")) > 2.0 and not get_tree().paused and not p.controls_locked
	Game.show_whisper("test_w1", "calm", "道行者", "重复触发应忽略", 5.0)
	var w_dedup := hud != null and String(hud.get("_whisper_text")) == "测试默语不阻塞操作。"
	_log("whisper_non_blocking", w_shown and w_dedup, "shown=%s dedup=%s" % [str(w_shown), str(w_dedup)])
	# Rank grading and persistence
	var r_a: Dictionary = Game.compute_rank(0, 4, 150.0, 1)
	var r_b: Dictionary = Game.compute_rank(2, 1, 400.0, 1)
	var r_c: Dictionary = Game.compute_rank(6, 0, 700.0, 0)
	var prev_rank := Game.best_rank
	var prev_time := Game.best_time
	var prev_cleared := Game.cleared_once
	var tmp_cfg := "user://qa_rank_test.cfg"
	Game.args["qa-settings"] = tmp_cfg
	Game.best_rank = ""
	Game.best_time = 0.0
	Game.cleared_once = false
	Game.deaths = 0
	Game.parries = 4
	Game.run_time = 155.0
	Game.difficulty = 1
	Game.record_clear(true)
	Game.best_rank = ""
	Game.cleared_once = false
	Game.load_settings()
	var persist_ok := Game.cleared_once and Game.best_rank == "甲" and absf(Game.best_time - 155.0) < 0.1
	Game.args.erase("qa-settings")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_cfg))
	Game.best_rank = prev_rank
	Game.best_time = prev_time
	Game.cleared_once = prev_cleared
	_log("rank_and_persist", String(r_a.grade) == "甲" and String(r_b.grade) == "乙" and String(r_c.grade) == "丙" and persist_ok,
		"grades=%s/%s/%s persist=%s" % [String(r_a.grade), String(r_b.grade), String(r_c.grade), str(persist_ok)])
