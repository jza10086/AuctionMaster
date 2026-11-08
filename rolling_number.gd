extends Control
## A clipped vertical digit reel. Progress comes from the settlement timeline, never money mutation.
@export var font_size: int = 32
@export var number_color: Color = Color("#f4f1e8")
var from_value: int = 0
var to_value: int = 0
var progress: float = 1.0

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_roll(previous: int, target: int, fraction: float) -> void:
	from_value = previous
	to_value = target
	progress = clampf(fraction, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var font: Font = get_theme_default_font()
	var old_digits: String = str(absi(from_value))
	var new_digits: String = str(absi(to_value))
	var length: int = maxi(old_digits.length(), new_digits.length())
	old_digits = old_digits.lpad(length, "0")
	new_digits = new_digits.lpad(length, "0")
	var slots: int = length + (length - 1) / 3 + (1 if to_value < 0 else 0)
	var draw_size: int = mini(font_size, int(size.x / maxf(slots * 0.66, 1.0)))
	var width: float = font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size).x
	var x: float = (size.x - width * slots) * 0.5
	var baseline: float = (size.y + font.get_height(draw_size)) * 0.5 - font.get_descent(draw_size)
	if to_value < 0:
		draw_string(font, Vector2(x, baseline), "−", HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size, number_color)
		x += width
	for index: int in length:
		if index > 0 and (length - index) % 3 == 0:
			draw_string(font, Vector2(x, baseline), ",", HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size, number_color)
			x += width
		var local_progress: float = clampf(progress * (1.0 + length * 0.035) - index * 0.035, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - local_progress, 3.0)
		var start: int = old_digits.substr(index, 1).to_int()
		var target: int = new_digits.substr(index, 1).to_int()
		var position: float = start + (20 + posmod(target - start, 10)) * eased
		var digit: int = int(floor(position)) % 10
		var offset: float = fposmod(position, 1.0) * size.y
		if progress >= 1.0:
			var padding: int = length - str(absi(to_value)).length()
			if index >= padding:
				draw_string(font, Vector2(x, baseline), str(target), HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size, number_color)
		else:
			draw_string(font, Vector2(x, baseline - offset), str(digit), HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size, number_color)
			draw_string(font, Vector2(x, baseline - offset + size.y), str((digit + 1) % 10), HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size, number_color)
		x += width
