extends Node
## Fixed-seed inputs for comparable 60 Hz captures from an unmodified encounter.
## Loaded only by the test runner. Movie mode uses Godot's actual viewport/audio.

const START := {"village": 600.0, "lowland": 4480.0, "elite": 10240.0, "wave": 9050.0}
const LENGTH := {"village": 630, "lowland": 360, "elite": 420, "wave": 540}
const SNAP := {"village": 35, "lowland": 78, "elite": 175, "wave": 420}


var frame_times := PackedFloat64Array()
var gpu_times := PackedFloat64Array()
var previous_time := 0
var elite_choices := 0


func _review_heavy() -> String:
	var move := "windup_chop" if elite_choices % 2 == 0 else "windup_sweep"
	elite_choices += 1
	print("REPLAY_ELITE_CHOICE ", move)
	return move


func _measure_frame() -> void:
	var now := Time.get_ticks_usec()
	if previous_time:
		frame_times.append((now - previous_time) / 1000.0)
		var gpu := RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
		if gpu > 0:
			gpu_times.append(gpu)
	previous_time = now


func _quantiles(times: PackedFloat64Array) -> String:
	if times.is_empty():
		return "unavailable"
	times.sort()
	return "p50=%.2f p95=%.2f p99=%.2f" % [times[times.size()/2], times[int(times.size()*0.95)], times[int(times.size()*0.99)]]


func replay(runner: Node) -> void:
	var scene_name := str(Game.args.get("scene", "village"))
	if not START.has(scene_name):
		push_error("Unknown replay " + scene_name)
		Game.quit(2)
		return
	seed(303003)
	Game.args["skip_cleared"] = "1"
	var player: Player = await runner._fresh_level(START[scene_name])
	var folder := str(Game.args.get("evidence", "user://review"))
	DirAccess.make_dir_recursive_absolute(folder)
	var snapped := false
	print("REPLAY_START frame=", Engine.get_frames_drawn())
	if Game.args.has("measure"):
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
		RenderingServer.frame_post_draw.connect(_measure_frame)
	for frame in int(LENGTH[scene_name]):
		if scene_name == "elite":
			for actor in Combat.enemies_alive():
				if actor.rig_type == "elite" and not actor.heavy_selector.is_valid():
					actor.heavy_selector = _review_heavy
		player.input_override = _input_at(scene_name, frame)
		await get_tree().physics_frame
		var is_sample := frame == int(SNAP[scene_name])
		if scene_name == "elite":
			is_sample = false
			for enemy in Combat.enemies_alive():
				if enemy.rig_type == "elite" and enemy.state == "windup_chop" and enemy.state_t >= 0.4:
					is_sample = true
		if not snapped and is_sample:
			await RenderingServer.frame_post_draw
			_save(folder.path_join(scene_name + ".png"))
			snapped = true
		if frame % 30 == 0:
			var enemies := []
			for enemy in Combat.enemies_alive():
				if absf(enemy.position.x - player.position.x) < 600:
					enemies.append(enemy.rig_type + "/" + enemy.state)
			print("REPLAY tick=%s x=%.0f hero=%s enemies=%s" % [frame, player.position.x, player.state, enemies])
	if not snapped or (scene_name == "elite" and elite_choices < 2):
		push_error("Missing key frame for " + scene_name)
		Game.quit(1)
		return
	if Game.args.has("measure"):
		RenderingServer.frame_post_draw.disconnect(_measure_frame)
		print("FRAME_MS device=%s display=%s samples=%d presented=[%s] gpu=[%s]" % [
			RenderingServer.get_video_adapter_name(), get_viewport().get_texture().get_size(), frame_times.size(),
			_quantiles(frame_times), _quantiles(gpu_times)])
	print("REPLAY_END frame=", Engine.get_frames_drawn())
	Game.quit()


func _input_at(scene_name: String, frame: int) -> Dictionary:
	var input := {}
	match scene_name:
		"village":
			if frame >= 42 and frame < 366:
				input["move_right"] = true
			if frame >= 99 and frame < 118:
				input["jump"] = true
				input["jump_just"] = frame == 99
			if frame >= 317 and frame % 22 == 0:
				input["attack_just"] = true
			if frame == 477:
				input["talisman_just"] = true
		"lowland":
			if frame >= 44 and frame < 192:
				input["move_right"] = true
			if frame >= 73 and frame < 94:
				input["jump"] = true
				input["jump_just"] = frame == 73
			if frame == 224:
				input["talisman_just"] = true
		"elite":
			if frame >= 32 and frame < 72:
				input["move_right"] = true
			if frame >= 125 and frame < 400 and frame % 120 < 72:
				input["block"] = true
				input["block_just"] = frame % 120 == 5
		"wave":
			input["move_right"] = frame < 114
			input["block"] = frame > 140
			input["attack_just"] = frame % 45 == 0
	return input


func masks(runner: Node) -> void:
	var folder := str(Game.args.get("shots", "user://shots"))
	DirAccess.make_dir_recursive_absolute(folder)
	var cases := [[900.0, "grunt"], [3000.0, "crawler"], [5300.0, "spitter"], [7300.0, "husk"], [10200.0, "elite"]]
	for pair in cases:
		Game.args["skip_cleared"] = "1"
		var player: Player = await runner._fresh_level(pair[0])
		player.set_physics_process(false)
		for other in Combat.enemies_alive():
			other.hide()
			other.set_physics_process(false)
		var enemy: Enemy = await runner.spawn(pair[1], pair[0]+170.0, true)
		Game.level.hud.hide()
		await runner._wait(1.2)
		await RenderingServer.frame_post_draw
		# Force successive draws without a physics/process tick between them.
		# This keeps fog, particle positions and camera identical in the four plates.
		for plate in ["with", "hero", "enemy", "bg"]:
			player.visible = plate in ["with", "hero"]
			enemy.visible = plate in ["with", "enemy"]
			RenderingServer.force_draw(false, 0.0)
			_save(folder.path_join("read_%s_%s.png" % [pair[1], plate]))
	Game.quit()


func _save(path: String) -> void:
	var pixels := get_viewport().get_texture().get_image()
	if pixels == null or pixels.save_png(path) != OK:
		push_error("Could not save " + path)
		Game.quit(2)
