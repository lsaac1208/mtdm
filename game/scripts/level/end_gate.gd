extends Node2D
## The sealed road beyond the burial mound. Glows once the elite falls; the
## player walks into the light to finish the demo.

var t := 0.0


func _ready() -> void:
	z_index = 1


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var open := Game.cleared.has("e8_elite")
	var a := 0.55 + 0.25 * sin(t * 2.0) if open else 0.12
	draw_rect(Rect2(-40, -420, 80, 420), Color(1.0, 0.85, 0.55, a * 0.25))
	draw_rect(Rect2(-14, -420, 28, 420), Color(1.0, 0.92, 0.7, a * 0.5))
	# stone pillars of a broken 牌坊 gate
	for x in [-90.0, 90.0]:
		draw_rect(Rect2(x - 14, -300, 28, 300), Color(0.16, 0.14, 0.12))
		draw_rect(Rect2(x - 18, -312, 36, 14), Color(0.1, 0.09, 0.08))
	draw_rect(Rect2(-130, -330, 260, 22), Color(0.12, 0.1, 0.09))
	draw_rect(Rect2(-40, -306, 80, 30), Color(0.55, 0.12, 0.08) if open else Color(0.3, 0.1, 0.07))
