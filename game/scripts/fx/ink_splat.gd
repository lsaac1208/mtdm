extends Node2D
## Ground ink/blood blot left by hits; fades out. Kept to a small pool.

static var pool: Array = []
var life := 5.0
var t := 0.0
var color := Color(0.12, 0.05, 0.04, 0.8)
var size := 18.0
var blobs := []


func _ready() -> void:
	z_index = 2
	pool.append(self)
	while pool.size() > 40:
		var old = pool.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	for i in randi_range(4, 8):
		blobs.append([Vector2(randf_range(-size, size) * 1.6, randf_range(-2.0, 3.0)), randf_range(size * 0.25, size * 0.6)])


func _exit_tree() -> void:
	pool.erase(self)


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	if t < 0.2 or t > life - 1.5:
		queue_redraw()


func _draw() -> void:
	# Soaked-in stain: a soft wide rim and a translucent core, so blots read
	# as ink seeping into the painted earth rather than black holes in it.
	var a := clampf(t / 0.12, 0.0, 1.0) * clampf((life - t) / 1.5, 0.0, 1.0)
	for b in blobs:
		draw_set_transform(b[0], 0.0, Vector2(1.0, 0.24))
		draw_circle(Vector2.ZERO, b[1] * 1.45, Color(color.r, color.g, color.b, color.a * a * 0.16))
		draw_circle(Vector2.ZERO, b[1] * 1.15, Color(color.r, color.g, color.b, color.a * a * 0.22))
		draw_circle(Vector2.ZERO, b[1] * 0.8, Color(color.r, color.g, color.b, color.a * a * 0.42))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
