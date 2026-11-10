extends Control
## A clipped vertical digit reel. Progress comes from the settlement timeline, never money mutation.
@export var font_size: int = 32
@export var number_color: Color = Color("#f4f1e8")
var from_value: int = 0
var to_value: int = 0
var progress: float = 1.0
var display_value: float = 0.0
var reel_speed: float = 0.0
var _streaming: bool = false
var _clock: float = 0.0
var _finish_at: float = 0.0
var _settling: bool = false
var _positions: Array[float] = []
var _settle_from: Array[float] = []
var _settle_to: Array[float] = []

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_roll(previous: int, target: int, fraction: float) -> void:
	_streaming = false
	from_value = previous
	to_value = target
	progress = clampf(fraction, 0.0, 1.0)
	queue_redraw()

## Absolute totals absorb any number of rapid discoveries without dropping or double-adding.
## Retargeting preserves each reel position and its velocity instead of restarting from zero.
func reset_value(value: int = 0) -> void:
	from_value = value
	to_value = value
	display_value = value
	progress = 1.0
	_streaming = true
	_clock = 0.0
	_finish_at = 0.0
	_settling = false
	reel_speed = 0.0
	_positions.clear()
	_settle_from.clear()
	_settle_to.clear()
	var digits: String = str(absi(value))
	for index: int in digits.length():
		_positions.append(float(digits[digits.length() - 1 - index].to_int()))
	queue_redraw()

func follow_value(target: int, elapsed: float) -> void:
	_streaming = true
	var delta: float = maxf(0.0, elapsed - _clock)
	_clock = maxf(_clock, elapsed)
	if target != to_value:
		from_value = roundi(display_value)
		var addition: int = absi(target - to_value)
		to_value = target
		_finish_at = elapsed + 0.85
		_settling = false
		# Larger additions spin farther in the same time, while small values remain legible.
		reel_speed = maxf(reel_speed, 10.0 + 10.0 * log(1.0 + addition / 100.0) / log(10.0))
	var digits: String = str(absi(target))
	while _positions.size() < digits.length():
		_positions.append(0.0)
	display_value = lerpf(display_value, float(target), 1.0 - exp(-delta * (5.0 + reel_speed * 0.12)))
	progress = 0.0 if elapsed < _finish_at else 1.0
	if progress >= 1.0:
		display_value = target
		reel_speed = 0.0
		for index: int in _positions.size():
			_positions[index] = float(digits[digits.length() - 1 - index].to_int()) if index < digits.length() else 0.0
	elif elapsed < _finish_at - 0.25:
		for index: int in _positions.size():
			_positions[index] += reel_speed * (1.0 + index * 0.06) * delta
	else:
		if not _settling:
			_settling = true
			_settle_from = _positions.duplicate()
			_settle_to.clear()
			for index: int in _positions.size():
				var digit: int = digits[digits.length() - 1 - index].to_int() if index < digits.length() else 0
				var next: int = ceili(_positions[index])
				_settle_to.append(float(next + posmod(digit - next, 10)))
		var fraction: float = clampf((elapsed - (_finish_at - 0.25)) / 0.25, 0.0, 1.0)
		for index: int in _positions.size():
			_positions[index] = lerpf(_settle_from[index], _settle_to[index], 1.0 - pow(1.0 - fraction, 3.0))
	queue_redraw()

func _draw() -> void:
	var font: Font = get_theme_default_font()
	var old_digits: String = str(absi(from_value))
	var new_digits: String = str(absi(to_value))
	var length: int = maxi(old_digits.length(), new_digits.length())
	if _streaming:
		length = maxi(length, _positions.size())
	# Settled numbers use their own digit count, including separators and centering.
	if progress >= 1.0:
		length = new_digits.length()
		old_digits = old_digits.right(length)
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
		var turns: int = 2 + mini(6, int(log(1.0 + absi(to_value - from_value) / 1000.0) / log(10.0)))
		var position: float = _positions[length - 1 - index] if _streaming else start + (turns * 10 + posmod(target - start, 10)) * eased
		var digit: int = int(floor(position)) % 10
		var offset: float = fposmod(position, 1.0) * size.y
		if progress >= 1.0:
			draw_string(font, Vector2(x, baseline), str(target), HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size, number_color)
		else:
			draw_string(font, Vector2(x, baseline - offset), str(digit), HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size, number_color)
			draw_string(font, Vector2(x, baseline - offset + size.y), str((digit + 1) % 10), HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size, number_color)
		x += width
