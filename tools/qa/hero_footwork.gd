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
		var planted := {}
		var sampled := 0
		var max_slide := 0.0
		var max_floor_gap := 0.0
		for frame in 100:
			await process_frame
			var visual: Node2D = player.vis
			if frame < 12 or player.state != "run" or visual.cut.current != "run":
				continue
			for side in 2:
				var phase := fposmod(visual.cut.clip_progress() + (0.5 if side == 0 else 0.0), 1.0)
				if phase < 0.08 or phase > 0.35:
					planted.erase(side)
					continue
				var sole: Vector2 = visual.to_global(visual.contacts[side])
				if not planted.has(side):
					planted[side] = sole.x
				max_slide = maxf(max_slide, absf(sole.x - planted[side]))
				max_floor_gap = maxf(max_floor_gap, absf(sole.y - player.global_position.y))
				sampled += 1
		var ok := sampled >= 30 and max_slide < 1.0 and max_floor_gap < 1.0
		print("TEST hero_support_foot_", action, " ", "PASS" if ok else "FAIL",
			" samples=", sampled, " slide_px=", max_slide, " floor_gap_px=", max_floor_gap)
		passed = passed and ok
	game.quit(0 if passed else 1)
