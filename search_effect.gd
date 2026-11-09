extends Control
## Neutral search reticle: no rarity, value or fakeout hint before discovery.
var elapsed: float = 0.0

func show_search(clock: float) -> void:
	elapsed = clock
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.22
	var color: Color = Color("99b5c4")
	draw_circle(center, radius * 1.8, Color(0.1, 0.17, 0.21, 0.6))
	draw_arc(center, radius * 1.5, 0.0, TAU, 64, Color(color, 0.2), 1.0, true)
	var angle: float = elapsed * 4.0
	draw_arc(center, radius * 1.5, angle, angle + 1.5, 32, color, 3.0, true)
	draw_arc(center - Vector2(6, 6), radius * 0.55, 0.0, TAU, 40, color, 3.0, true)
	draw_line(center + Vector2(radius * 0.32, radius * 0.32), center + Vector2(radius * 0.85, radius * 0.85), color, 5.0, true)
