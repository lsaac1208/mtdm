extends SceneTree
## Run from the repository root:
## godot --headless --fixed-fps 60 --path game --script ../tools/qa/hero_footwork.gd -- --mute
## Measure both feet in world coordinates during fully weighted stance. The
## first and last 8% of each cycle intentionally roll onto/off the supporting foot.

func _initialize() -> void:
	check_footwork.call_deferred()


func check_footwork() -> void:
	change_scene_to_file("res://scenes/level.tscn")
	for frame in 16:
		await physics_frame
	var game := root.get_node("Game")
	var player: Node2D = game.player
	var passed := true
	for action in ["move_right", "move_left"]:
		player.input_override = {action: true}
		var sampled := 0
		var max_floor_gap := 0.0
		var uses_frames := false
		for frame in 100:
			await process_frame
			var visual: Node2D = player.vis
			if frame < 12 or player.state != "run" or visual.current_clip() != "run":
				continue
			uses_frames = uses_frames or bool(visual.frame_on)
			var sole0: Vector2 = visual.to_global(visual.contacts[0])
			var sole1: Vector2 = visual.to_global(visual.contacts[1])
			var lowest_gap := minf(absf(sole0.y - player.global_position.y), absf(sole1.y - player.global_position.y))
			max_floor_gap = maxf(max_floor_gap, lowest_gap)
			sampled += 1
		var ok := sampled >= 30 and uses_frames and max_floor_gap < 2.0
		print("TEST hero_support_foot_", action, " ", "PASS" if ok else "FAIL",
			" samples=", sampled, " frame_anim=", uses_frames, " floor_gap_px=", max_floor_gap)
		passed = passed and ok
	game.quit(0 if passed else 1)
