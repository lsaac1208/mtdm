extends Node2D
## Additive bile-green glow over the Taint Spitter's throat sac. The sac is
## its core identity (readable at 50 px), so the wind-up is sold by this glow.

var amount := 0.0


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	z_index = 1


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	if amount <= 0.01:
		return
	var a := clampf(amount, 0.0, 1.6)
	var pulse := 1.0 + 0.08 * sin(Time.get_ticks_msec() / 70.0) * a
	for i in 5:
		var k := float(i) / 5.0
		draw_circle(Vector2.ZERO, (14.0 + 26.0 * (1.0 - k)) * pulse * (0.7 + a * 0.35),
			Color(0.45, 0.75, 0.12, 0.10 * a * (0.5 + k)))
	draw_circle(Vector2.ZERO, 7.0 * pulse * (0.6 + a * 0.5), Color(0.8, 1.0, 0.45, 0.35 * a))
