extends Node

var probe: Object
var review: Node
var block_open := false
var ever_active := false
var finished := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Game.args.has("qa-gl-timer"):
		probe = ClassDB.instantiate("TaoistFrameGpuProbe")
	RenderingServer.frame_pre_draw.connect(_before)
	RenderingServer.frame_post_draw.connect(_after)

func _find_review() -> void:
	for runner in Game.get_children():
		for child in runner.get_children():
			if child.get_script() and child.get_script().resource_path == "res://tests/visual_review.gd":
				review = child
				return

func _before() -> void:
	if not is_instance_valid(review):
		_find_review()
	# The first frame already in the measured interval has a wall clock value.
	if not review or review.previous_time == 0 or finished:
		return
	if Game._quitting:
		finished = true
		if probe:
			RenderingServer.call_on_render_thread(probe.finish)
		return
	if probe:
		RenderingServer.call_on_render_thread(probe.before_frame.bind(Engine.get_frames_drawn()))
	ever_active = true
	block_open = true

func _after() -> void:
	if block_open:
		block_open = false
		if probe:
			RenderingServer.call_on_render_thread(probe.after_frame)
